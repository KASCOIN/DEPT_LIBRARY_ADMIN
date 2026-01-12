# Supabase Admin Auth - Implementation Checklist

## Phase 1: Supabase Setup (One-time)

### 1. Create Profiles Table
```sql
-- Run in Supabase SQL Editor
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    role TEXT DEFAULT 'user',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_profiles_email ON public.profiles(email);

-- Insert admin user (replace with your email)
INSERT INTO public.profiles (id, email, role)
SELECT id, email, 'admin'
FROM auth.users
WHERE email = 'admin@yourdomain.com'
ON CONFLICT (id) DO UPDATE SET role = 'admin';
```

### 2. Set Environment Variables in `.env`
```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
SUPABASE_ANON_KEY=your-anon-key-here
```

## Phase 2: Backend Verification

### 1. Check SupabaseAdminAuth Module
```bash
# Verify file exists
ls -la backend/services/supabase_admin_auth.jl

# Should contain:
# - verify_admin_token()
# - is_admin_role()
# - get_admin_user_info()
```

### 2. Check Server Includes
```bash
# Verify in backend/server.jl:
grep "supabase_admin_auth" backend/server.jl

# Should output:
# include("services/supabase_admin_auth.jl")
```

### 3. Check Admin Controller
```bash
# Verify middleware function exists
grep "check_supabase_admin_auth" backend/controllers/admin_controller.jl

# Should output multiple matches
```

### 4. Check Routes
```bash
# Verify new endpoint exists
grep "admin_verify_role" backend/routes/admin.jl

# Should include:
# route("/api/admin/verify-role", AdminController.admin_verify_role, method=POST)
```

## Phase 3: Frontend Verification

### 1. Check Login Page
```bash
# Verify admin-login.html exists
ls -la frontend/admin-login.html

# Verify Supabase is included
grep "supabase-js" frontend/admin-login.html
```

### 2. Check Auth Script
```bash
# Verify admin-auth.js exists
ls -la frontend/js/admin-auth.js

# Verify AdminAuthManager is defined
grep "AdminAuthManager" frontend/js/admin-auth.js
```

### 3. Check Admin Page
```bash
# Verify admin.html includes admin-auth.js
grep "admin-auth.js" frontend/admin.html

# Verify old login modal is removed (should be gone)
grep "admin-login-modal" frontend/admin.html
```

### 4. Check API Layer
```bash
# Verify API includes admin_jwt token
grep "admin_jwt" frontend/js/api.js
```

## Phase 4: Testing

### 1. Unit Test: JWT Verification
```bash
cd backend

# Test JWT verification in Julia REPL
julia> include("services/supabase_admin_auth.jl")
julia> valid, info = SupabaseAdminAuth.verify_admin_token("test-token")
# Should return (false, error_dict) for invalid token
```

### 2. Integration Test: Login Flow
```
1. Start server: julia backend/server.jl
2. Navigate to: http://localhost:8000/admin-login
3. Enter valid admin email and password
4. System should redirect to /admin.html
5. Dashboard should load successfully
```

### 3. Integration Test: Non-Admin Access
```
1. Create non-admin user in Supabase (role = 'user')
2. Try login with non-admin credentials
3. Should see: "Access denied. You do not have admin privileges."
4. Non-admin cannot access dashboard
```

### 4. API Test: Protected Endpoint
```bash
# Get JWT from browser console after login
TOKEN=$(localStorage.getItem('admin_jwt'))

# Test with valid token
curl -X GET http://localhost:8000/api/admin/active-students?minutes=5 \
  -H "Authorization: Bearer $TOKEN"
# Should return student data

# Test with invalid token
curl -X GET http://localhost:8000/api/admin/active-students?minutes=5 \
  -H "Authorization: Bearer invalid-token"
# Should return 403 Forbidden
```

## Phase 5: Production Deployment

### 1. Update Admin Credentials
```bash
# Create production admin user in Supabase Auth
# Set role to 'admin' in profiles table
# Change all default passwords
```

### 2. HTTPS Configuration
```bash
# Redirect HTTP to HTTPS
# Update Supabase redirect URLs to use HTTPS
# Update backend CORS settings for production domain
```

### 3. Security Hardening
```bash
# Enable rate limiting on login endpoint
# Enable CORS for production domain only
# Implement audit logging for admin access
# Set up monitoring for failed login attempts
```

### 4. Backup Plan
```bash
# Export admin users list
# Document recovery procedures
# Test admin account recovery process
# Have emergency admin account backup
```

## Verification Checklist

- [ ] Profiles table created in Supabase
- [ ] Admin user has role = 'admin'
- [ ] Environment variables set in .env
- [ ] SupabaseAdminAuth service file exists
- [ ] Backend server includes new service
- [ ] Admin controller has middleware function
- [ ] Routes include new verify-role endpoint
- [ ] Admin login page exists at /admin-login
- [ ] Admin auth script exists and loads
- [ ] Admin page removes old login modal
- [ ] API layer uses admin_jwt token
- [ ] Test admin login works
- [ ] Test non-admin login is blocked
- [ ] Test protected API endpoint with token
- [ ] Test protected API endpoint without token
- [ ] Logout functionality works
- [ ] Token refresh on new session works
- [ ] Unauthorized redirects to login page
- [ ] Admin page visible only to admins
- [ ] Server logs show auth verification

## Common Issues & Solutions

### Issue: "Token verification failed"
**Solution:**
- Check Supabase URL and keys in .env
- Verify JWT format is valid
- Check token expiration
- Look at server error logs

### Issue: "User profile not found"
**Solution:**
- Verify profiles table exists
- Check user exists in profiles table
- Run: `SELECT * FROM profiles WHERE email = 'your@email.com'`
- Manually insert profile if missing

### Issue: "Access denied - not admin"
**Solution:**
- Check user role in profiles table
- Run: `UPDATE profiles SET role = 'admin' WHERE id = 'user-id'`
- Clear localStorage and login again
- Verify role change took effect

### Issue: Admin page redirects to login
**Solution:**
- Check browser console for errors
- Verify admin_jwt in localStorage
- Check that token isn't expired
- Test /api/admin/verify-role endpoint manually

### Issue: CORS errors in browser
**Solution:**
- Check server CORS configuration
- Verify origin matches allowed domains
- Test with curl to isolate browser issue
- Check network tab for 401/403 responses

## Support Resources

- **Supabase Auth Documentation:** https://supabase.com/docs/guides/auth
- **JWT Information:** https://jwt.io/
- **RBAC Best Practices:** https://supabase.com/docs/guides/auth/managing-user-data
- **Julia HTTP Module:** https://github.com/JuliaWeb/HTTP.jl
