# ✅ Supabase Auth Migration - Final Checklist

## Phase 1: Database Setup (5 minutes)

### Prerequisites
- [ ] Have Supabase project open in browser
- [ ] Know your project URL
- [ ] Have access to SQL Editor

### Execute Migration
- [ ] Open: Supabase Dashboard → Your Project → SQL Editor
- [ ] Click: "New Query"
- [ ] Copy entire file: `backend/migrations/001_auth_profiles.sql`
- [ ] Paste into SQL editor
- [ ] Click: "Run" button
- [ ] Verify: No errors shown in Results panel

### Verify Tables Created
- [ ] Go to: Tables view
- [ ] See: `profiles` table exists
- [ ] Click profiles → RLS section
- [ ] Verify: RLS is "Enabled"
- [ ] See 3 policies listed:
  - [ ] `users_read_own_profile`
  - [ ] `users_update_own_profile`
  - [ ] `service_role_all_access`
- [ ] Go to: Triggers section
- [ ] Verify: 2 triggers present:
  - [ ] `on_auth_user_created` (on auth.users insert)
  - [ ] `on_auth_user_email_updated` (on auth.users email update)
- [ ] Go to: Indexes section
- [ ] Verify: 3 indexes created:
  - [ ] `idx_profiles_email`
  - [ ] `idx_profiles_matric_no`
  - [ ] `idx_profiles_role`

### Backup
- [ ] Screenshot successful execution (for documentation)
- [ ] Note timestamp of migration

---

## Phase 2: Frontend Testing (15 minutes)

### Prepare Environment
- [ ] Start backend: `cd backend && julia --project server.jl`
- [ ] Verify: Backend running on `http://localhost:8000`
- [ ] Open browser console: F12 or Cmd+Option+I
- [ ] Clear localStorage: `localStorage.clear()` in console

### Test Signup
- [ ] Navigate to: `http://localhost:8000/frontend/student/signup.html`
- [ ] Fill form:
  - [ ] Full Name: "Test Student"
  - [ ] Matric Number: "2024001"
  - [ ] Programme: "Computer Science"
  - [ ] Level: "200"
  - [ ] Email: "test@example.com"
  - [ ] Country Code: "+234"
  - [ ] Phone: "9012345678"
  - [ ] Password: "TestPass123"
- [ ] Click: "Sign Up"
- [ ] Verify: Success message appears
- [ ] Verify: Redirected to login.html after 2 seconds

### Verify Signup Created User
- [ ] Go to Supabase → Auth → Users
- [ ] Verify: New user with email "test@example.com" appears
- [ ] Note: User ID (UUID format)
- [ ] Go to Supabase → profiles table
- [ ] Verify: New profile entry with:
  - [ ] id = (same as user ID from above)
  - [ ] email = "test@example.com"
  - [ ] full_name = "Test Student"
  - [ ] matric_no = "2024001"
  - [ ] programme = "Computer Science"
  - [ ] level = "200"
  - [ ] phone = "+2349012345678"
  - [ ] role = "student"

### Test Login
- [ ] Navigate to: `http://localhost:8000/frontend/student/login.html`
- [ ] Enter credentials:
  - [ ] Email: "test@example.com"
  - [ ] Password: "TestPass123"
- [ ] Click: "Login"
- [ ] Verify: Success message "✓ Login successful! Redirecting..."
- [ ] Verify: Redirected to student-main.html after 1 second

### Verify JWT Token
- [ ] Open DevTools: F12
- [ ] Go to: Application → Local Storage → http://localhost:8000
- [ ] Click: `student_session` key
- [ ] Verify: Value contains:
  - [ ] `user_id` (UUID)
  - [ ] `email` ("test@example.com")
  - [ ] `access_token` (long string, JWT format)
  - [ ] `full_name`, `matric_no`, `programme`, etc.

### Verify JWT Token Format
- [ ] Copy `access_token` value from localStorage
- [ ] Go to: https://jwt.io/
- [ ] Paste token in "Encoded" section
- [ ] Verify in Decoded section:
  - [ ] **HEADER:** `{ "alg": "HS256", "typ": "JWT" }`
  - [ ] **PAYLOAD:** Contains:
    - [ ] `"sub"` = user UUID
    - [ ] `"email"` = "test@example.com"
    - [ ] `"role"` = "authenticated"
    - [ ] `"exp"` = future timestamp (3600 seconds from now)
    - [ ] `"iat"` = current timestamp

### Test API Call with JWT
- [ ] Stay on student-main.html
- [ ] Open DevTools Console
- [ ] Enter command:
  ```javascript
  const response = await fetchWithAuth('/api/student/profile');
  console.log(response.status, await response.json());
  ```
- [ ] Verify: Response status is 200
- [ ] Verify: JSON contains user profile data

### Check Authorization Header
- [ ] Open DevTools: Network tab
- [ ] Refresh page
- [ ] Look for `/api/student/profile` request
- [ ] Click on it → Headers section
- [ ] Verify: Authorization header exists:
  - [ ] `Authorization: Bearer eyJhbGc...` (token)

### Test Logout
- [ ] Click: Logout button (on student-main.html)
- [ ] Verify: Redirected to login.html
- [ ] Open DevTools Console
- [ ] Enter: `localStorage.getItem('student_session')`
- [ ] Verify: Returns `null` (token cleared)

### Test Login Redirect
- [ ] Try to access: `http://localhost:8000/frontend/student/student-main.html`
- [ ] Verify: Redirected to login.html (checkAuth() triggered)
- [ ] Verify: Cannot access dashboard without logging in first

### Test Invalid Token
- [ ] Login again (to get valid token)
- [ ] Open DevTools Console
- [ ] Corrupt the token:
  ```javascript
  const session = JSON.parse(localStorage.getItem('student_session'));
  session.access_token = 'invalid.token.here';
  localStorage.setItem('student_session', JSON.stringify(session));
  ```
- [ ] Try to call API:
  ```javascript
  const response = await fetchWithAuth('/api/student/profile');
  console.log(response.status);
  ```
- [ ] Verify: Response status is 401
- [ ] Verify: You're logged out and redirected to login

---

## Phase 3: Code Review (10 minutes)

### Backend Files
- [ ] Open: `backend/services/auth_middleware.jl`
  - [ ] Verify: `verify_auth_token()` function exists
  - [ ] Check: Extracts Authorization header
  - [ ] Check: Decodes JWT payload
  - [ ] Check: Returns { valid, user_id, role, error }

- [ ] Open: `backend/controllers/student_controller.jl`
  - [ ] Verify: `login_student()` returns 401 (deprecated)
  - [ ] Check: `get_material_view_url()` calls `verify_auth_token()`
  - [ ] Check: Returns 401 if token invalid

### Frontend Files
- [ ] Open: `frontend/student/js/session.js`
  - [ ] Verify: Supabase client initialized
  - [ ] Check: `getAccessToken()` function exists
  - [ ] Check: `fetchWithAuth()` adds Authorization header
  - [ ] Check: `checkAuth()` redirects if no session

- [ ] Open: `frontend/student/js/login.js`
  - [ ] Verify: Uses `supabaseClient.auth.signInWithPassword()`
  - [ ] Check: Not using old backend login endpoint
  - [ ] Check: Stores JWT token in localStorage

- [ ] Open: `frontend/student/js/signup.js`
  - [ ] Verify: Uses `supabaseClient.auth.signUp()`
  - [ ] Check: No SHA256 hashing code
  - [ ] Check: Creates profile after auth signup

---

## Phase 4: Security Review (5 minutes)

- [ ] Verify: `password_hash` not stored in profiles table
- [ ] Verify: Passwords managed by Supabase Auth (auth.users)
- [ ] Verify: RLS policies prevent unauthorized access
- [ ] Verify: JWT tokens expire (exp claim)
- [ ] Verify: Tokens stored temporarily (TODO: httpOnly in prod)
- [ ] Verify: All API calls require Authorization header
- [ ] Verify: Backend validates JWT signature
- [ ] Verify: 401 returned for invalid tokens

---

## Phase 5: Documentation Review (5 minutes)

### Documents Created
- [ ] File exists: `SUPABASE_AUTH_MIGRATION.md` (overview + detailed guide)
- [ ] File exists: `AUTH_MIGRATION_COMPLETE.md` (implementation status)
- [ ] File exists: `QUICK_START_AUTH_MIGRATION.md` (deployment steps)
- [ ] File exists: `MIGRATION_SUMMARY_REPORT.md` (complete report)
- [ ] File exists: `AUTH_VISUAL_GUIDE.md` (diagrams and visual explanations)
- [ ] File exists: `backend/migrations/001_auth_profiles.sql` (SQL schema)

### Document Quality
- [ ] Guides explain before/after
- [ ] SQL migration has comments
- [ ] Code examples are correct
- [ ] Testing checklist is complete
- [ ] Troubleshooting section helpful

---

## Phase 6: Production Readiness (5 minutes)

### Blockers Check
- [ ] All tests pass ✅
- [ ] No console errors ✅
- [ ] No database errors ✅
- [ ] JWT validation working ✅
- [ ] Authorization headers sent ✅
- [ ] 401 responses working ✅

### TODO Items (For Future)
- [ ] [ ] JWT signature verification with Supabase secret
- [ ] [ ] Move JWT tokens to httpOnly cookies
- [ ] [ ] Enable email verification
- [ ] [ ] Add password reset flow
- [ ] [ ] Implement token refresh
- [ ] [ ] Add rate limiting
- [ ] [ ] Update admin authentication

### Go/No-Go Decision
- [ ] Go for testing ✅ (if all Phase 1-5 complete)
- [ ] Ready for production ✅ (if all tests pass)

---

## Phase 7: Post-Deployment (After Production)

### Monitor (First 24 hours)
- [ ] Check error logs for JWT validation failures
- [ ] Verify no unexpected 401s
- [ ] Monitor token expiration behavior
- [ ] Ensure login/logout working smoothly

### Verify in Production
- [ ] Test signup/login flow
- [ ] Test API calls with JWT
- [ ] Test token expiration
- [ ] Test logout
- [ ] Check Supabase dashboard for new users

### Cleanup
- [ ] Remove old password-based code if unused
- [ ] Update documentation
- [ ] Add to deployment runbooks
- [ ] Train team on new auth system

---

## ⚠️ Critical Checkpoints

| Checkpoint | What to Check | Status |
|-----------|--------------|--------|
| Database Migration | SQL executed without errors | [ ] |
| profiles table | Exists with 9 columns | [ ] |
| RLS Policies | 3 policies enabled | [ ] |
| Triggers | 2 triggers created | [ ] |
| Signup works | User in auth.users AND profiles | [ ] |
| Login works | JWT token obtained | [ ] |
| Token format | Valid JWT with 3 parts | [ ] |
| Token claims | Has sub, exp, role | [ ] |
| API validation | Backend checks Authorization header | [ ] |
| 401 handling | Invalid token returns 401 | [ ] |
| Logout clears | Session removed from localStorage | [ ] |

---

## 🎯 Success Criteria

**You'll know it's working when:**

✅ User can signup via Supabase Auth
✅ New user appears in auth.users (Supabase managed)
✅ New profile appears in profiles table (custom data)
✅ User can login and get JWT token
✅ JWT token has correct format (header.payload.signature)
✅ Token stored in localStorage
✅ Token sent in Authorization header automatically
✅ Backend validates token for API calls
✅ Invalid token returns 401
✅ Valid token returns 200
✅ Logout clears session
✅ Cannot access dashboard without token

---

## 📞 Troubleshooting Quick Links

If you encounter issues:

1. **"Error creating profile"** → Check RLS policies
2. **"Invalid credentials"** → Verify user in auth.users
3. **"401 Unauthorized"** → Check Authorization header
4. **"Token missing"** → Verify session.js loaded
5. **"Can't login"** → Check password correct
6. **"Signup fails"** → Check duplicate email/matric_no
7. **"API returns 401"** → Check fetchWithAuth() used
8. **"Session persists"** → Check logout() clears localStorage

---

## 📝 Sign-Off

Once you complete all phases:

- [ ] Date Completed: __________
- [ ] Tested By: __________
- [ ] Approved By: __________
- [ ] Ready for Production: YES / NO

---

**This is your official checklist for Supabase Auth Migration.** ✅

Follow it step-by-step and check off each box as you complete it. If anything fails, refer to the troubleshooting guides in the associated documentation files.

**Good luck! 🚀**
