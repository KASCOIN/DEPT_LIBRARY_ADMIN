# Supabase Auth Migration - Quick Reference & Next Steps

## ✅ What's Been Completed

### 1. Database Schema
- `backend/migrations/001_auth_profiles.sql` - Complete SQL migration
- Profiles table linked to auth.users
- RLS policies for security
- Triggers for automation
- Ready to deploy to Supabase

### 2. Backend Updates
- **`backend/services/auth_middleware.jl`**
  - JWT token extraction from Authorization header
  - Payload decoding and claim extraction
  - Token expiration validation
  - Returns { valid, user_id, role, error }

- **`backend/controllers/student_controller.jl`**
  - Removed SHA256 password hashing
  - `login_student()` returns 401 (use Supabase Auth instead)
  - `get_material_view_url()` requires valid JWT token

### 3. Frontend Updates
- **`frontend/student/js/session.js`** - Supabase Auth integration
  - `getSession()` - Get current session
  - `getCurrentUser()` - Get current user
  - `getAccessToken()` - Get JWT token
  - `checkAuth()` - Verify authenticated
  - `fetchWithAuth()` - API calls with Bearer token
  - `logout()` - Sign out
  - `setupAuthListener()` - Auth state changes

- **`frontend/student/js/login.js`** - Use Supabase Auth
  - `supabaseClient.auth.signInWithPassword()`
  - JWT token obtained and stored
  - Profile data fetched from profiles table

- **`frontend/student/js/signup.js`** - Use Supabase Auth
  - `supabaseClient.auth.signUp()`
  - Profile created linked to auth user
  - Duplicate checking before signup

### 4. Documentation
- `SUPABASE_AUTH_MIGRATION.md` - Comprehensive migration guide
- `AUTH_MIGRATION_COMPLETE.md` - Implementation status and next steps

## 🚀 Immediate Next Steps (DO THIS FIRST)

### Step 1: Deploy Database Migration (5 minutes)
```
1. Go to Supabase Dashboard
2. Click: Project → SQL Editor → New Query
3. Copy entire contents of: backend/migrations/001_auth_profiles.sql
4. Paste into SQL editor
5. Click "Run"
6. Verify: Tables → profiles should appear
```

### Step 2: Test Authentication (10 minutes)
```
1. Start backend: cd backend && julia --project server.jl
2. Open: http://localhost:8000/frontend/student/signup.html
3. Fill form and submit
4. Check Supabase:
   - Auth → Users (should show new user)
   - profiles table (should show new profile)
5. Go to login.html
6. Enter credentials and login
7. Should redirect to student-main.html
8. Open DevTools → Application → Local Storage
9. Should see student_session with access_token
```

### Step 3: Update Remaining API Calls
Files that need updating to use `fetchWithAuth()`:
```
frontend/student/js/student-main.js
frontend/js/forms/materials.js
frontend/js/forms/courses.js
frontend/js/forms/timetable.js
```

Current pattern to replace:
```javascript
// OLD:
fetch('/api/endpoint', {
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(data)
})

// NEW:
fetchWithAuth('/api/endpoint', {
  body: JSON.stringify(data)
})
```

### Step 4: Update Protected Endpoints
Each endpoint that accesses student data must validate JWT:

```julia
# At start of endpoint function:
headers = Dict(request().headers)
auth_result = verify_auth_token(headers)

if !auth_result.valid
    return json_cors(
        Dict("success" => false, "error" => auth_result.error),
        401
    )
end

user_id = auth_result.user_id
# Now use user_id to fetch student's data
```

## 📋 Testing Checklist

Run through these before production:

- [ ] Database migration applied successfully
- [ ] Can signup with new account
- [ ] New user appears in Supabase Auth → Users
- [ ] New profile appears in profiles table
- [ ] Can login with credentials
- [ ] Redirected to dashboard after login
- [ ] JWT token stored in localStorage
- [ ] Materials load on dashboard
- [ ] Can download materials (requires JWT)
- [ ] DevTools shows Authorization header in requests
- [ ] Logout clears token
- [ ] Cannot access dashboard without token
- [ ] Old login endpoint returns 401

## 🔐 Security Checklist

Before production deployment:

- [ ] `password_hash` column removed from profiles (if it exists)
- [ ] All protected endpoints require Authorization header
- [ ] RLS policies enabled on profiles table
- [ ] Service role key not exposed in frontend code
- [ ] Anon key is used in frontend (safe)
- [ ] JWT tokens set to expire (default 3600s)
- [ ] Logout clears tokens on backend too (if needed)

## 🛠️ Debugging Commands

### Check if user exists:
```javascript
// In browser console:
const user = await supabaseClient.auth.getUser();
console.log(user);
```

### Get JWT token:
```javascript
const session = await supabaseClient.auth.getSession();
console.log(session.session.access_token);
```

### Verify token format:
```javascript
// Copy token from localStorage['student_session']
// Go to https://jwt.io and paste
// Should show: header, payload with sub and role, signature
```

### Check profile in database:
```sql
-- Supabase SQL Editor
SELECT * FROM profiles WHERE email = 'user@example.com';
```

## 📁 Key Files Reference

```
backend/
├── migrations/
│   └── 001_auth_profiles.sql          ← RUN THIS FIRST
├── services/
│   └── auth_middleware.jl             ← JWT validation
└── controllers/
    └── student_controller.jl          ← Updated for JWT

frontend/
└── student/
    ├── js/
    │   ├── session.js                 ← NEW: Supabase integration
    │   ├── login.js                   ← UPDATED: Use Supabase Auth
    │   └── signup.js                  ← UPDATED: Use Supabase Auth
    ├── login.html
    └── signup.html

Documentation/
├── SUPABASE_AUTH_MIGRATION.md         ← Full guide
└── AUTH_MIGRATION_COMPLETE.md         ← Status & details
```

## ⚠️ Important Notes

1. **Don't forget the database migration!** Nothing works without the profiles table.

2. **JWT tokens are in localStorage** - This is temporary for development. In production, use httpOnly cookies for better security.

3. **Token expiration is 3600 seconds** - If user doesn't interact for 1 hour, they'll need to re-login.

4. **All API calls need the JWT** - If an endpoint returns 401, it means the token is missing or invalid.

5. **Frontend still needs Supabase library** - Make sure `<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>` is in HTML.

## 🎯 Success Criteria

You'll know it's working when:

✅ User can signup → Auth user created → Profile created
✅ User can login → Gets JWT token
✅ Token sent automatically in Authorization header
✅ Backend validates token → Allows request
✅ Materials load without errors
✅ User can logout → Token cleared
✅ Cannot access dashboard without token
✅ 401 errors when token invalid/expired

## 🚨 If Something Breaks

1. **Signup fails:** Check profiles table exists, RLS policies, and triggers
2. **Login fails:** Verify email/password correct, user in auth.users
3. **API returns 401:** Check Authorization header in DevTools Network tab
4. **Token missing:** Verify session.js loaded, Supabase client initialized
5. **Profile not created:** Check RLS "Service role all access" policy

## Next Priority

1. ✅ Database migration
2. 🔄 Test authentication flow
3. ⏭️ Update remaining API calls to use fetchWithAuth()
4. ⏭️ Update admin authentication
5. ⏭️ Production deployment

---

**Questions?** Check:
- [SUPABASE_AUTH_MIGRATION.md](SUPABASE_AUTH_MIGRATION.md) for detailed explanations
- [AUTH_MIGRATION_COMPLETE.md](AUTH_MIGRATION_COMPLETE.md) for implementation details
- Supabase docs: https://supabase.com/docs/guides/auth
