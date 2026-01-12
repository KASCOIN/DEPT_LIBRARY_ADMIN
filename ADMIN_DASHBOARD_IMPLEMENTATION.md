# Admin Dashboard Active Students - Implementation Complete

## Summary of Changes

### Frontend Changes

#### 1. **admin-config.js** (NEW)
- Location: `frontend/js/admin-config.js`
- Purpose: Centralized Supabase client initialization for admin portal
- Functions:
  - `getAdminToken()` - Retrieves JWT token from sessionStorage or Supabase session
  - `setAdminToken(token)` - Stores token in sessionStorage
  - `clearAdminToken()` - Removes token on logout

#### 2. **admin-auth.js** (NEW)
- Location: `frontend/js/admin-auth.js`
- Purpose: Admin authentication handling
- Functions:
  - `checkAdminAuth()` - Checks if admin is authenticated on page load
  - `handleAdminLogin(email, password)` - Handles admin login via Supabase
  - `handleAdminLogout()` - Handles logout
  - `showLoginModal()` / `hideLoginModal()` - Toggle login UI
  - `showLoginError(message)` - Display error messages

#### 3. **admin.html** (MODIFIED)
- Added admin login modal (hidden by default)
- Added script tags for `admin-config.js` and `admin-auth.js` in correct order
- Login modal appears when not authenticated

#### 4. **active-students.js** (MODIFIED)
- Enhanced with detailed console logging for debugging
- `getAuthToken()` checks multiple token sources:
  1. Admin token from `getAdminToken()`
  2. localStorage access_token
  3. sessionStorage access_token
  4. Supabase session token
- Added console output for HTTP status and error responses
- Better error messages for 401/403 responses

#### 5. **dashboard.js** (MODIFIED)
- Replaced mock `updateOnlineStudents()` with real implementation
- Now calls `fetchActiveStudents()` from active-students.js
- Displays actual student data with:
  - Full name
  - Programme and level
  - Last seen timestamp (formatted as relative time)

### Backend Changes

#### 1. **admin_controller.jl** (MODIFIED)
- Added include for auth_middleware.jl
- Modified `get_active_students()` endpoint:
  - Requires valid JWT authentication (any authenticated user, not just admins)
  - Returns 401 if no valid token
  - Logs which user accessed the endpoint
  - Returns active students with metadata

## Authentication Flow

### First Time Setup
1. Admin visits `/admin`
2. Admin login modal appears
3. Admin enters email and password (must have Supabase account)
4. Supabase authenticates and returns JWT
5. JWT stored in sessionStorage as `admin_access_token`
6. Login modal hidden, dashboard displayed
7. Dashboard calls active-students endpoint with JWT

### Subsequent Visits
1. Admin visits `/admin`
2. `checkAdminAuth()` looks for stored token or Supabase session
3. If found, skips login and shows dashboard
4. If not found, shows login modal

### API Requests
All requests to `/api/admin/active-students` include:
```
Authorization: Bearer {JWT_TOKEN}
```

Backend validates JWT and returns:
- **200**: Success with active students list
- **401**: No valid authentication token
- **500**: Server error

## Testing Steps

### 1. Prerequisites
- Backend server running on port 8000
- Supabase project configured
- Ensure a student account exists (for active student tracking)
- At least one admin or regular user account for testing admin portal

### 2. Test Admin Login
1. Open browser dev tools (F12)
2. Go to `http://localhost:8000/admin`
3. Should see login modal
4. Enter a valid Supabase account email and password
5. Click "Login"
6. Check console for logs starting with `[Admin Auth]`
7. Login modal should disappear, dashboard should show

### 3. Test Active Students Display
1. After logging in, dashboard should show:
   - "Online Students" section
   - Student count (0 initially if no students active)
   - Empty message or list of students

2. To test with actual student data:
   - Log in as a student on student portal
   - Student's last_seen gets updated in database
   - Admin dashboard auto-refreshes every 30 seconds
   - Student should appear in "Online Students" list

### 4. Console Debugging
When debugging, check console output:
```
[Admin Auth] Checking authentication...
[Admin Auth] Found stored admin token
[Active Students] Fetching with token: YES (length: 456)
[Active Students] Authorization header added
[Active Students] Requesting: /api/admin/active-students?minutes=5
[Active Students] Response status: 200
[Active Students] Successfully fetched: 2 students
```

### 5. Error Messages
- **No token**: "No authentication token. Please log in."
- **Invalid credentials**: Login modal shows error message
- **Network error**: Check CORS headers and backend status

## Database Requirements

The system requires:
- Supabase `profiles` table with columns:
  - `id` (uuid, primary key)
  - `email` (text)
  - `full_name` (text)
  - `programme` (text)
  - `level` (text or integer)
  - `last_seen` (timestamp)
  - `role` (text: 'student', 'admin', etc.)

## Configuration

### Environment Variables
- `SUPABASE_URL`: Supabase project URL (configured in admin-config.js)
- `SUPABASE_ANON_KEY`: Public anon key (configured in admin-config.js)

### Time Windows
- Active window: 5 minutes (matches backend ACTIVE_WINDOW_MINUTES)
- Refresh interval: 30 seconds
- Last seen is updated on every authenticated API call

## Security Notes

1. **JWT Validation**: All endpoints validate JWT token
2. **CORS**: Requests include appropriate CORS headers
3. **Role-Based Access**: Can be enabled by uncommenting admin role check
4. **Session Storage**: Token stored in sessionStorage (cleared on browser close)
5. **No Password Storage**: Passwords never stored in frontend

## Troubleshooting

### "Unauthorized" Error (401)
- Admin not logged in
- Token expired (login again)
- Check browser console for token retrieval logs

### "Network Error"
- Backend server not running
- CORS issues with backend
- Check backend logs for errors

### Students Not Showing
- No students have accessed student portal yet
- Students didn't trigger API calls that update last_seen
- Check database `profiles.last_seen` column for recent timestamps

### Login Modal Won't Close
- Check browser console for JavaScript errors
- Verify Supabase credentials in admin-config.js
- Check network requests for failed login attempts

## Next Steps

1. **Add Admin Role Enforcement** (optional):
   - Uncomment role check in `get_active_students()`
   - Create admin user with `role='admin'` in profiles table

2. **Add Logout Button**:
   - Create logout button in admin header
   - Call `handleAdminLogout()`
   - Shows login modal again

3. **Persist Preferences**:
   - Remember user's time window preference
   - Store refresh interval preference

4. **Real-Time Updates** (advanced):
   - Use WebSockets instead of polling
   - Push updates directly to admin dashboard
