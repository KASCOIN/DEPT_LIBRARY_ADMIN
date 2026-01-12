# Admin Authentication System - Quick Reference

## Overview
Complete admin authentication system with login, session management, and protected routes.

## How It Works

### 1. User Visits Admin Panel
- URL: `http://127.0.0.1:8000/admin.html`
- Auth check runs automatically
- If not logged in → redirects to `/login.html`

### 2. Login Process
- User enters username and password
- Credentials validated against SHA256 hash
- Session token generated (UUID)
- Token stored in `localStorage`
- Redirects to `/admin.html`

### 3. Admin Operations
- All API requests include Authorization header
- Backend verifies token validity
- Session tracks: username, creation time, expiration (24h)
- Expired sessions are cleaned up automatically

### 4. Logout
- Click "Logout" button in top-right corner
- Session invalidated on server
- Token removed from localStorage
- Redirect to `/login.html`

## Default Credentials

```
Username: admin
Password: admin
```

⚠️ **Change these in production!**

## Changing Admin Password

### Method 1: Via Julia REPL
```julia
using SHA
using UUIDs

# Hash your desired password
password_hash = bytes2hex(sha256("your_new_password"))
println(password_hash)  # Copy this value
```

### Method 2: Set Environment Variable
Add to `.env` file:
```
ADMIN_PASSWORD_HASH=your_hash_here
```

### Method 3: Use Provided Function
In Julia REPL:
```julia
include("backend/services/admin_auth_service.jl")
AdminAuthService.set_default_admin_password()
```
This outputs the hash for the default "admin" password.

## API Endpoints

### POST /api/admin/auth/login
**Request:**
```json
{
  "username": "admin",
  "password": "admin"
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Login successful",
  "token": "uuid-string-here"
}
```

**Response (Failure):**
```json
{
  "success": false,
  "message": "Invalid credentials"
}
```

### GET /api/admin/auth/verify
**Headers:**
```
Authorization: Bearer your-token-here
```

**Response (Valid):**
```json
{
  "authenticated": true,
  "username": "admin",
  "created_at": "2026-01-12T14:25:00",
  "expires_at": "2026-01-13T14:25:00"
}
```

**Response (Invalid):**
```json
{
  "authenticated": false,
  "message": "Session expired"
}
```

### POST /api/admin/auth/logout
**Headers:**
```
Authorization: Bearer your-token-here
```

**Response:**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

## Session Management

- **Duration:** 24 hours
- **Storage:** In-memory on server (not persistent across restarts)
- **Cleanup:** Automatic removal of expired sessions
- **Token Format:** UUID4 (40 characters)

## Security Features

✓ SHA256 password hashing  
✓ UUID-based session tokens  
✓ Automatic token expiration  
✓ 401 error responses trigger re-login  
✓ CORS properly configured  
✓ HttpOnly cookie support (future)  

## Frontend Implementation

### Auto-Login Check (auth.js)
Runs on every admin page load:
1. Checks for token in localStorage
2. Calls `/api/admin/auth/verify`
3. If invalid → redirects to login
4. If valid → displays username

### API Headers (api.js)
Every request automatically includes:
```javascript
headers: {
  'Authorization': 'Bearer ' + localStorage.getItem('admin_token')
}
```

### Logout Handler
```javascript
// Button in header
id="logout-btn"
// Calls AdminAuth.logout()
// Clears localStorage and redirects
```

## Files Modified

### Backend
- `server.jl` - Added include for admin_auth_service
- `controllers/admin_controller.jl` - Added 3 auth functions
- `routes/admin.jl` - Added 3 auth routes
- `services/admin_auth_service.jl` - NEW (core auth logic)

### Frontend
- `admin.html` - Added logout button and user display
- `js/api.js` - Added token handling
- `js/auth.js` - NEW (frontend auth flow)
- `login.html` - NEW (login form)

## Troubleshooting

### "Invalid credentials"
- Check username and password spelling
- Default is: admin / admin
- Verify ADMIN_PASSWORD_HASH env var if custom password set

### "Session expired"
- Token is valid for 24 hours
- Login again to get new token
- Check browser console for 401 errors

### Can't access admin panel
- Check that `/login.html` is accessible
- Verify server is running
- Check browser console for errors
- Clear localStorage and try again

### Password hash not recognized
- Ensure ADMIN_PASSWORD_HASH is set correctly in .env
- Use SHA256 hash (64 hex characters)
- Restart server after changing .env
