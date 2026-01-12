# Secure Supabase Admin Authentication System

## Overview

The Department Library Admin System now implements a secure, role-based admin authentication system using Supabase Auth and JWT tokens. This replaces the previous simple username/password system with enterprise-grade security.

## Architecture

### Authentication Flow

1. **Admin Login Page** (`/admin-login`)
   - User navigates to the dedicated admin login page
   - Enters email and password
   - Credentials are verified against Supabase Auth

2. **JWT Token Generation**
   - Supabase issues a JWT token upon successful authentication
   - Token contains user ID and expiration time

3. **Role Verification**
   - Frontend sends JWT to backend `/api/admin/verify-role` endpoint
   - Backend verifies JWT signature and expiration
   - Backend checks user's role in `profiles` table
   - Only users with `role = 'admin'` are granted access

4. **Protected Routes**
   - All admin endpoints require valid JWT in Authorization header
   - Middleware validates token and role before processing request
   - Middleware rejects requests with invalid/missing tokens with 403 Forbidden

5. **Admin Dashboard Access**
   - Only authenticated admins can access `/admin.html`
   - Non-admins are redirected to login page even with valid JWT
   - All API calls include JWT in Authorization header

## Key Files

### Backend

#### `backend/services/supabase_admin_auth.jl`
Core authentication and role verification logic:
- `verify_admin_token(jwt_token)` - Validates JWT signature and expiration
- `is_admin_role(user_id)` - Checks if user has admin role
- `get_admin_user_info(user_id)` - Retrieves admin profile information

#### `backend/controllers/admin_controller.jl`
Admin endpoints with built-in JWT verification:
- `admin_verify_role()` - POST /api/admin/verify-role (public)
  - Verifies JWT and admin role
  - Returns admin status and user information
- `check_supabase_admin_auth()` - Middleware function
  - Validates JWT token
  - Checks admin role
  - Used by all protected endpoints
- Protected endpoints: `post_news()`, `post_materials()`, `post_courses()`, `post_timetable()`, delete operations

### Frontend

#### `frontend/admin-login.html`
Secure login page:
- Email/password form
- Supabase Auth integration
- Role verification before redirect
- Error handling and validation

#### `frontend/js/admin-auth.js`
Authentication manager:
- `AdminAuthManager.checkAdminAuth()` - Verifies session on page load
- `AdminAuthManager.getAdminToken()` - Returns current JWT token
- `AdminAuthManager.logout()` - Signs out user and clears tokens
- Redirects unauthorized users to login page

#### `frontend/js/api.js`
API communication layer:
- `API.getToken()` - Retrieves JWT from localStorage
- `API.getHeaders()` - Adds JWT to request headers
- Handles 401/403 responses by redirecting to login

## Security Features

### 1. **JWT Token-Based Authentication**
   - Industry-standard format
   - Cryptographically signed by Supabase
   - Contains expiration time (typically 1 hour)
   - Cannot be forged without private key

### 2. **Role-Based Access Control (RBAC)**
   - User roles stored in database `profiles` table
   - Role verified on every admin request
   - Role can be revoked immediately without token invalidation

### 3. **Backend Enforcement**
   - All admin endpoints validate JWT before processing
   - No query parameters or URL paths can bypass authentication
   - All API requests must include `Authorization: Bearer <token>` header

### 4. **Session Management**
   - Tokens stored securely in `localStorage` (HttpOnly recommended in production)
   - Tokens automatically cleared on logout
   - Expired tokens trigger automatic re-authentication

### 5. **CORS Protection**
   - Admin endpoints accessible only from same origin
   - Authorization header required for all admin requests

## Usage

### As an Admin User

1. **Login**
   ```
   Navigate to http://localhost:8000/admin-login
   Enter email and password
   System verifies your admin role
   Redirected to dashboard if authorized
   ```

2. **Dashboard Access**
   ```
   http://localhost:8000/admin.html
   Dashboard automatically loads if JWT is valid
   System redirects to login if not authenticated
   ```

3. **Logout**
   ```
   Click "Logout" button in dashboard
   Session is cleared
   Redirected to login page
   ```

### For API Integration

All admin API requests must include JWT token:

```javascript
// Example: POST materials
const token = localStorage.getItem('admin_jwt');
const response = await fetch('/api/admin/materials', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify(data)
});

if (response.status === 403) {
    // Admin verification failed - redirect to login
    window.location.href = '/admin-login';
}
```

## Database Requirements

### profiles Table Schema
```sql
CREATE TABLE profiles (
    id UUID PRIMARY KEY,
    email VARCHAR,
    role VARCHAR,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Required indexes
CREATE INDEX idx_profiles_role ON profiles(role);
```

### Required Role Values
- `'admin'` - Full admin access
- Other values - No admin access

## Environment Variables

```bash
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_ANON_KEY=your-anon-key
```

## API Endpoints

### Public Endpoints (No Auth Required)
- `POST /api/admin/verify-role` - Verify admin access

### Protected Endpoints (JWT + Admin Role Required)
- `POST /api/admin/news` - Create announcement
- `POST /api/admin/materials` - Upload material
- `DELETE /api/admin/materials` - Delete material
- `POST /api/admin/courses` - Create course
- `POST /api/admin/courses/update` - Update course
- `DELETE /api/admin/courses` - Delete course
- `POST /api/admin/timetable` - Create timetable
- `DELETE /api/admin/timetable` - Delete timetable
- `GET /api/admin/active-students` - Get active students

## Error Responses

### 401 Unauthorized
```json
{
    "is_admin": false,
    "error": "Invalid token"
}
```

### 403 Forbidden (Not Admin)
```json
{
    "is_admin": false,
    "error": "User role is 'student', not 'admin'",
    "user_id": "uuid",
    "email": "user@example.com"
}
```

### 500 Server Error
```json
{
    "success": false,
    "error": "Server error"
}
```

## Migration from Old System

The new system maintains backward compatibility:
- Old authentication endpoints still work
- API layer checks for both old and new tokens
- Gradually migrate users to Supabase Auth

### Steps to Migrate
1. Create user accounts in Supabase Auth
2. Set admin role in `profiles` table
3. Direct users to new `/admin-login` page
4. Old login endpoints can be deprecated after migration

## Security Best Practices

### For Administrators
1. ✅ Use strong, unique passwords
2. ✅ Change password regularly
3. ✅ Log out after use
4. ✅ Never share login credentials
5. ✅ Report suspicious activity immediately

### For Developers
1. ✅ Always validate JWT on backend
2. ✅ Never trust frontend-only authentication
3. ✅ Check role on every protected endpoint
4. ✅ Use HTTPS in production (redirect HTTP to HTTPS)
5. ✅ Keep Supabase keys secret
6. ✅ Implement rate limiting on login endpoint
7. ✅ Use HttpOnly cookies for tokens in production

## Troubleshooting

### "Access denied. You do not have admin privileges."
- Verify user role is set to 'admin' in profiles table
- Check that profiles table has correct data
- Verify service role key has permission to read profiles

### "Token expired"
- User's session expired (typically after 1 hour)
- Redirect user to login page to get new token
- Clear localStorage and session

### "Invalid token format"
- Token may be corrupted or incomplete
- Clear browser cache and cookies
- Try logging in again

### Admin can't access dashboard
- Check browser console for errors
- Verify admin-auth.js is loaded
- Check that JWT token is in localStorage
- Verify Supabase configuration is correct

## Testing

### Test Admin Login
```bash
# 1. Create test admin user in Supabase
# 2. Set role to 'admin' in profiles table
# 3. Navigate to http://localhost:8000/admin-login
# 4. Enter credentials and verify access
```

### Test JWT Verification
```bash
# Get JWT from browser localStorage after login
TOKEN=$(localStorage.getItem('admin_jwt'))

# Test protected endpoint
curl -X GET http://localhost:8000/api/admin/active-students?minutes=5 \
  -H "Authorization: Bearer $TOKEN"

# Should return student data if authorized
# Should return 403 if not admin
```

## Support

For issues or questions:
1. Check this documentation
2. Review browser console for errors
3. Check server logs for detailed error messages
4. Contact system administrator
