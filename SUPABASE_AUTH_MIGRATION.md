# Supabase Auth Migration Guide

## Overview

This document outlines the migration from custom password-based authentication to Supabase Auth.

## What's Changing

### Current System (Before)
- ❌ Manual password hashing (SHA256) on frontend and backend
- ❌ Custom user table with password_hash field
- ❌ Session stored in localStorage as plain JSON
- ❌ Role-based access via profile.role field (not cryptographic)
- ❌ No JWT tokens
- ❌ Scalability issues with password management

### New System (After)
- ✅ Supabase Auth handles all authentication securely
- ✅ No passwords stored in profiles table (only in auth.users)
- ✅ JWT tokens issued by Supabase (with cryptographic signature)
- ✅ Sessions managed via JWT tokens in localStorage
- ✅ Role-based access via JWT claims OR profile.role field
- ✅ All API calls require valid Bearer token
- ✅ Enterprise-grade security

## Migration Steps

### 1. Database Changes (Supabase SQL)

Create profiles table linked to auth.users:

```sql
-- Create profiles table (linked to auth.users)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  matric_no TEXT UNIQUE,
  programme TEXT,
  level TEXT,
  phone TEXT,
  role TEXT DEFAULT 'student' CHECK (role IN ('student', 'admin')),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Enable RLS (Row Level Security)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own profile
CREATE POLICY "Users can read own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- Policy: Users can update their own profile
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Policy: Service role can do everything (for backend)
CREATE POLICY "Service role full access" ON profiles
  FOR ALL USING (auth.jwt()->>'role' = 'service_role');

-- Create trigger to sync email from auth.users
CREATE OR REPLACE FUNCTION sync_user_email()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE profiles SET email = NEW.email WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION sync_user_email();

-- Indexes for performance
CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_profiles_matric_no ON profiles(matric_no);
CREATE INDEX idx_profiles_role ON profiles(role);
```

### 2. Backend Changes (Julia)

#### Remove Password Hashing
- Delete SHA256 password verification from `student_controller.jl`
- Remove `password_hash` field handling

#### Add JWT Validation
- Update `auth_middleware.jl` to properly verify Supabase JWT tokens
- Extract `user_id` (sub claim) from token
- Extract `role` from JWT claims or profile table
- Implement `@require_auth` macro for protected routes

#### Update Protected Routes
- Require `Authorization: Bearer <token>` header
- Validate JWT signature with Supabase secret
- Return 401 if missing or invalid

#### API Endpoints Changes
```julia
# Before (password in body)
POST /api/student/login
  {"email": "...", "password": "..."}
  
# After (no endpoint, handled by frontend)
# Frontend calls supabaseClient.auth.signInWithPassword()
# Gets JWT token
# Stores token and sends in Authorization header
```

### 3. Frontend Changes (JavaScript)

#### Login Form (`login.js`)
```javascript
// Before: Send email + password to backend
// After: Use Supabase Auth client
const { data, error } = await supabaseClient.auth.signInWithPassword({
  email,
  password
});

// Extract JWT from response
const token = data.session.access_token;

// Save in localStorage (still encrypted/httponly in production)
saveToken(token);

// Redirect to student-main.html
```

#### Signup Form (`signup.js`)
```javascript
// Before: Hash password on frontend, insert into profiles table
// After: Use Supabase Auth client for signup
const { data, error } = await supabaseClient.auth.signUp({
  email,
  password,
  options: {
    data: {
      full_name: fullName,
      matric_no: matricNo,
      // other metadata
    }
  }
});

// Then insert additional profile data into profiles table
await supabaseClient
  .from('profiles')
  .insert({
    id: data.user.id,
    full_name: fullName,
    matric_no: matricNo,
    programme,
    level,
    phone,
    role: 'student'
  });
```

#### Session Management (`session.js`)
```javascript
// Before: Plain JSON object in localStorage
// After: Supabase Auth session with JWT tokens

function checkAuth() {
  // Get session from Supabase Auth
  const session = supabaseClient.auth.getSession();
  if (!session?.user) {
    window.location.href = 'login.html';
    return null;
  }
  return session.user;
}

function getToken() {
  const session = supabaseClient.auth.getSession();
  return session?.session?.access_token;
}

// All API calls must include token
async function fetchAPI(endpoint, options = {}) {
  const token = getToken();
  if (!token) {
    window.location.href = 'login.html';
    return;
  }
  
  const headers = {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
    ...options.headers
  };
  
  return fetch(endpoint, { ...options, headers });
}
```

#### API Calls Update
All protected endpoints must send token:
```javascript
// Before: Just send data
fetch('/api/materials', { method: 'POST', body: JSON.stringify(data) })

// After: Include Bearer token
fetch('/api/materials', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify(data)
})
```

### 4. Testing Checklist

- [ ] User can sign up with email/password
- [ ] Supabase Auth creates user in auth.users
- [ ] Trigger creates corresponding profile entry
- [ ] User can log in and receives JWT token
- [ ] Token stored in localStorage (temporarily during migration)
- [ ] Token sent in Authorization header for API calls
- [ ] Backend validates JWT and allows request
- [ ] Invalid token returns 401 Unauthorized
- [ ] User can log out (token cleared)
- [ ] JWT contains correct claims (user_id, role)
- [ ] Role-based access works (student/admin)
- [ ] Token expires and forces re-login

## Files to Modify

1. **Backend**
   - `backend/controllers/student_controller.jl` - Remove password hashing, require JWT
   - `backend/services/auth_middleware.jl` - Improve JWT validation
   - `backend/controllers/admin_controller.jl` - Update protected routes

2. **Frontend**
   - `frontend/student/js/login.js` - Use Supabase Auth
   - `frontend/student/js/signup.js` - Use Supabase Auth
   - `frontend/student/js/session.js` - Manage JWT tokens
   - `frontend/student/js/student-main.js` - Use fetchAPI with token
   - `frontend/student/js/dashboard.js` - Use fetchAPI with token
   - All other API-calling scripts

3. **HTML**
   - `frontend/student/login.html` - Remove password field? (No, keep for better UX)
   - `frontend/student/signup.html` - Same as login

## Security Improvements

| Aspect | Before | After |
|--------|--------|-------|
| Password Storage | SHA256 (frontend) | bcrypt (Supabase) |
| Password Verification | Plain comparison | Cryptographic verification |
| Session Token | localStorage JSON | Signed JWT |
| Token Expiration | None | 3600 seconds default |
| Token Refresh | None | Refresh token mechanism |
| CORS | * (open) | Should be restricted |
| Password Hashing | Frontend | Backend (Supabase) |

## Timeline

- [ ] **Phase 1** - Database: Create profiles table, triggers (15 min)
- [ ] **Phase 2** - Backend: Update JWT validation, remove password hashing (30 min)
- [ ] **Phase 3** - Frontend: Update login/signup, session management (45 min)
- [ ] **Phase 4** - Testing: Full auth flow verification (30 min)
- [ ] **Phase 5** - Cleanup: Remove old auth code, documentation (15 min)

**Total Estimated Time: 2-3 hours**

## Rollback Plan

If issues occur:
1. Keep old password-based code in `old_auth/` branch
2. Maintain JSON file fallback for backward compatibility
3. Gradual migration: new signups use Auth, old users still work
4. Full migration can wait until bugs are fixed

## Notes

- Supabase Auth handles all token management
- Frontend still stores token in localStorage (in production, use httpOnly cookies)
- Backend validates token using Supabase secret
- All endpoints must require valid token
- Email verification can be enabled after initial setup
