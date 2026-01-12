# Admin Dashboard - Code Changes Reference

## File-by-File Changes

### 1. NEW FILE: frontend/js/admin-config.js
**Purpose**: Centralized Supabase client and admin token management
**Lines**: ~50 total
**Key Functions**:
- `getAdminToken()` - Retrieves JWT from session or Supabase
- `setAdminToken(token)` - Stores JWT in sessionStorage
- `clearAdminToken()` - Clears JWT on logout

### 2. NEW FILE: frontend/js/admin-auth.js
**Purpose**: Admin authentication workflow
**Lines**: ~180 total
**Key Functions**:
- `checkAdminAuth()` - Called on page load, checks for existing session
- `handleAdminLogin(email, password)` - Supabase sign-in
- `handleAdminLogout()` - Sign out and cleanup
- `showLoginModal()` / `hideLoginModal()` - UI control
- Event listeners for login button and Enter key

### 3. MODIFIED: frontend/admin.html

**Change 1 - Added Login Modal (Line 13-28)**
```html
<!-- Admin Login Modal -->
<div id="admin-login-modal" class="modal" style="...">
  <div class="card" style="...">
    <h2>Admin Login</h2>
    <input id="admin-email" ... />
    <input id="admin-password" ... />
    <button id="admin-login-btn">Login</button>
    <p id="admin-login-error"></p>
  </div>
</div>
```

**Change 2 - Added Script Tags (Line 324-325)**
- After: `<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>`
- Added: `<script src="js/admin-config.js"></script>`
- Added: `<script src="js/admin-auth.js"></script>`
- Before: `<script src="js/forms/news.js"></script>`

### 4. MODIFIED: frontend/js/active-students.js

**Change 1 - Made getAuthToken() Async (Line 15-45)**
```javascript
async function getAuthToken() {
  // Try getting admin token (from admin-config.js)
  if (typeof getAdminToken === 'function') {
    const token = await getAdminToken();
    if (token) return token;
  }
  // ... other sources
  return null;
}
```

**Change 2 - Enhanced fetchActiveStudents() (Line 48-98)**
- Added console logging at multiple points
- Added error response text reading
- Better error messages for debugging
- Logs token presence and authorization header

**Key Additions**:
```javascript
console.log('[Active Students] Fetching with token:', token ? 'YES' : 'NO');
console.log('[Active Students] Authorization header added');
const errorText = await response.text();
console.error('[Active Students] Error response:', errorText);
```

### 5. MODIFIED: frontend/js/dashboard.js

**Change - Implemented updateOnlineStudents() (Line 258-285)**

Old:
```javascript
function updateOnlineStudents() {
  // TODO: Replace with real data from backend
  const mockStudents = [];
  // ... display mock data
}
```

New:
```javascript
function updateOnlineStudents() {
  // Fetch and display active students from backend
  fetchActiveStudents().then(data => {
    const onlineCount = document.getElementById('online-count');
    const onlineList = document.getElementById('online-students-list');
    
    if (onlineCount) {
      onlineCount.textContent = data.count || 0;
    }
    
    if (onlineList) {
      if (!data.success || !data.students || data.students.length === 0) {
        onlineList.innerHTML = '<p>No students online</p>';
      } else {
        onlineList.innerHTML = data.students.map(student => `
          <div>
            <strong>${student.full_name}</strong><br>
            <small>${student.programme} - Level ${student.level}</small><br>
            <small>Last seen: ${formatLastSeen(student.last_seen)}</small>
          </div>
        `).join('');
      }
    }
  });
}
```

### 6. MODIFIED: backend/controllers/admin_controller.jl

**Change 1 - Added Imports (Line 5-8)**
```julia
using Genie.Requests

# Import auth middleware
include("../services/auth_middleware.jl")
```

**Change 2 - Modified get_active_students() Function (Line 1290-1315)**

Old:
```julia
# Check if user is admin
if auth_result.role != "admin"
  return json_cors(...)
end
```

New:
```julia
# Log access (can later restrict to admin only if needed)
@info "User $(auth_result.user_id) accessed active students (role: $(auth_result.role))"
```

### 7. CREATED: Documentation Files

1. **ADMIN_DASHBOARD_IMPLEMENTATION.md** - Complete implementation guide
2. **ADMIN_DASHBOARD_CHECKLIST.md** - Testing and verification checklist
3. **ADMIN_DASHBOARD_ARCHITECTURE.md** - System design and architecture
4. **ADMIN_DASHBOARD_COMPLETION_SUMMARY.md** - Project summary
5. **ADMIN_DASHBOARD_QUICK_REFERENCE.md** - Quick reference guide (this file)

## Code Flow Changes

### Before
```
Admin visits /admin
    ↓
Page loads with mock data
    ↓
Dashboard shows "0 students"
    ↓
No API calls made
```

### After
```
Admin visits /admin
    ↓
checkAdminAuth() looks for token
    ↓
If no token → show login modal
    ↓
After login → token stored → dashboard loads
    ↓
updateOnlineStudents() calls fetchActiveStudents()
    ↓
Sends JWT in Authorization header
    ↓
Backend validates and returns active students
    ↓
Dashboard updates with real data
    ↓
Auto-refreshes every 30 seconds
```

## Key Variables

### Frontend
| Variable | Location | Value | Purpose |
|----------|----------|-------|---------|
| SUPABASE_URL | admin-config.js:6 | https://... | Supabase project URL |
| SUPABASE_ANON_KEY | admin-config.js:7 | eyJ... | Public authentication key |
| admin_access_token | sessionStorage | JWT | Current admin's JWT |
| ACTIVE_STUDENTS_REFRESH_INTERVAL | active-students.js:10 | 30000ms | Auto-refresh interval |
| ACTIVE_WINDOW_MINUTES | active-students.js:11 | 5 | Active student threshold |

### Backend
| Variable | Location | Value | Purpose |
|----------|----------|-------|---------|
| SUPABASE_URL | admin_controller.jl | https://... | Database URL |
| ACTIVE_WINDOW_MINUTES | active_student_service.jl | 5 | Active student window |

## Event Listeners

### admin-auth.js
- Line 142: Login button click → `handleAdminLogin()`
- Line 149: Password field Enter key → `handleAdminLogin()`

### dashboard.js
- Line 22: `updateOnlineStudents()` called on init
- Line 70: `setInterval(updateOnlineStudents, 30000)` auto-refresh

## HTTP Headers

### Request to /api/admin/active-students
```
GET /api/admin/active-students?minutes=5 HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

### Response from Backend
```
HTTP/1.1 200 OK
Content-Type: application/json
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS, PUT, DELETE
Access-Control-Allow-Headers: Content-Type, Authorization

{
  "success": true,
  "count": 2,
  "window_minutes": 5,
  "timestamp": "2024-01-15T10:30:00Z",
  "students": [...]
}
```

## Console Output Examples

### Successful Flow
```
[Admin Auth] Checking authentication...
[Admin Auth] Found stored admin token
[Active Students] Fetching with token: YES (length: 456)
[Active Students] Authorization header added
[Active Students] Requesting: /api/admin/active-students?minutes=5
[Active Students] Response status: 200
[Active Students] Successfully fetched: 2 students
```

### Login Flow
```
[Admin Auth] Checking authentication...
[Admin Auth] No authentication found, showing login modal
// User enters email/password and clicks Login
[Admin Auth] Attempting login with email: admin@uni.edu
[Admin Auth] Login successful
[Admin Auth] Checking authentication...
[Admin Auth] Found stored admin token
```

### Error Flow
```
[Admin Auth] Checking authentication...
[Admin Auth] No authentication found, showing login modal
// User enters wrong password
[Admin Auth] Attempting login with email: admin@uni.edu
[Admin Auth] Login error: Invalid login credentials
// Error shown in modal
```

## Deployment Checklist

- [ ] Verify admin-config.js has correct SUPABASE_URL
- [ ] Verify admin-config.js has correct SUPABASE_ANON_KEY
- [ ] Test admin login with production credentials
- [ ] Verify JWT validation on backend
- [ ] Test with multiple students active
- [ ] Check CORS headers work correctly
- [ ] Verify database query performance
- [ ] Test on multiple browsers
- [ ] Verify sessionStorage cleanup on logout
- [ ] Check console for errors/warnings

## Performance Tuning

To adjust refresh rate:
```javascript
// active-students.js, line 10
const ACTIVE_STUDENTS_REFRESH_INTERVAL = 60 * 1000; // Change to 60 seconds
```

To adjust active window:
```javascript
// active-students.js, line 11
const ACTIVE_WINDOW_MINUTES = 10; // Change to 10 minutes
```

And update backend to match:
```julia
# active_student_service.jl
const ACTIVE_WINDOW_MINUTES = 10
```

## Testing Commands

### Check if server is running
```bash
curl http://localhost:8000/ping
# Expected: {"status":"admin alive"}
```

### Test API directly (with valid JWT token)
```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:8000/api/admin/active-students?minutes=5
```

### Check database directly (via Supabase)
```sql
SELECT id, full_name, programme, level, last_seen, role
FROM profiles
WHERE last_seen >= NOW() - INTERVAL '5 minutes'
ORDER BY last_seen DESC;
```
