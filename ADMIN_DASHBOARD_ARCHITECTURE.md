# Admin Dashboard Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      ADMIN DASHBOARD                        │
│                   (browser / frontend)                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
    ┌───────────────────────────────────────────────┐
    │  AUTHENTICATION FLOW                          │
    ├───────────────────────────────────────────────┤
    │ 1. Admin Login Modal (admin-auth.js)          │
    │ 2. Supabase Auth SignIn                       │
    │ 3. JWT Token retrieved                        │
    │ 4. Token stored in sessionStorage             │
    │ 5. Token passed in Authorization header       │
    └───────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              API REQUEST WITH JWT TOKEN                    │
│   GET /api/admin/active-students?minutes=5                │
│   Headers: Authorization: Bearer {JWT}                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              BACKEND (admin_controller.jl)                 │
│                                                             │
│ 1. Extract JWT from Authorization header                  │
│ 2. Verify JWT signature and decode                        │
│ 3. Extract user_id and role from JWT claims              │
│ 4. Return 401 if invalid                                 │
│ 5. Call ActiveStudentService.get_active_students(5)      │
│ 6. Return JSON with student list                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│       SUPABASE DATABASE (activeStudentService.jl)         │
│                                                             │
│ Query: SELECT * FROM profiles                            │
│        WHERE last_seen >= NOW() - interval '5 minutes'   │
│        AND role = 'student'                              │
│                                                             │
│ Result: List of active students with metadata            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│         JSON RESPONSE TO FRONTEND                         │
│                                                             │
│ {                                                         │
│   "success": true,                                        │
│   "count": 2,                                             │
│   "window_minutes": 5,                                    │
│   "timestamp": "2024-01-15T10:30:00Z",                   │
│   "students": [...]                                       │
│ }                                                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│    FRONTEND DISPLAY (dashboard.js / active-students.js)   │
│                                                             │
│ 1. Parse JSON response                                   │
│ 2. Format timestamps to relative time ("5 min ago")      │
│ 3. Display student list in dashboard                     │
│ 4. Auto-refresh every 30 seconds                         │
└─────────────────────────────────────────────────────────────┘
```

## Component Relationships

### Frontend Components

```
admin.html
├── admin-config.js (Supabase initialization)
├── admin-auth.js (Authentication flow)
├── dashboard.js (UI and refresh logic)
│   └── calls updateOnlineStudents()
│       └── calls fetchActiveStudents() (from active-students.js)
├── active-students.js (API communication)
│   ├── getAuthToken() (token retrieval)
│   └── fetchActiveStudents() (API call)
└── admin.js, forms/*.js (Other admin features)
```

### Backend Components

```
server.jl (includes)
├── auth_middleware.jl (verify_auth_token)
├── active_student_service.jl (get_active_students)
├── admin_controller.jl
│   └── get_active_students() endpoint
│       ├── Calls verify_auth_token()
│       ├── Calls ActiveStudentService.get_active_students()
│       └── Returns JSON response
└── routes/admin.jl (GET /api/admin/active-students route)
```

### Database Schema

```
profiles table
├── id (uuid, primary key)
├── email (text)
├── full_name (text)
├── matric_no (text)
├── programme (text)
├── level (text/int)
├── phone (text)
├── role (text) - 'student', 'admin', etc.
├── created_at (timestamp)
├── updated_at (timestamp)
└── last_seen (timestamp) ← Updated on every API call
    └── Indexed for performance: idx_profiles_last_seen
```

## Data Flow

### 1. Initial Admin Login
```
User visits /admin
    ↓
checkAdminAuth() called
    ↓
No token found → show login modal
    ↓
Admin enters email/password
    ↓
handleAdminLogin() sends to Supabase
    ↓
Supabase returns JWT
    ↓
Token stored in sessionStorage
    ↓
Login modal hidden
    ↓
Dashboard initialized
    ↓
fetchActiveStudents() called every 30 seconds
```

### 2. API Request Sequence
```
dashboard.js: updateOnlineStudents()
    ↓
active-students.js: fetchActiveStudents()
    ↓
active-students.js: getAuthToken()
    ↓ (checks: getAdminToken → localStorage → sessionStorage → Supabase)
    ↓
fetch() with Authorization header
    ↓
admin_controller.jl: get_active_students()
    ↓
auth_middleware.jl: verify_auth_token()
    ↓ (validates JWT signature and claims)
    ↓
active_student_service.jl: get_active_students(minutes)
    ↓
Supabase query database
    ↓
Return JSON response
    ↓
frontend: updateActiveStudentsDisplay()
    ↓
DOM updated with student list
```

### 3. Student Activity Tracking
```
Student logs in
    ↓
student-main.js: checkAuth() gets student profile
    ↓
student_controller.jl: get_student_profile()
    ↓
active_student_service.jl: update_last_seen(user_id)
    ↓
UPDATE profiles SET last_seen = NOW()
    ↓

Student views materials
    ↓
api.js: fetchWithAuth() to view endpoint
    ↓
student_controller.jl: get_material_view_url()
    ↓
active_student_service.jl: update_last_seen(user_id)
    ↓
UPDATE profiles SET last_seen = NOW()
    ↓

Active window = 5 minutes
    ↓
If NOW() - last_seen <= 5 minutes → student is "active"
Else → student is "inactive"
```

## Configuration Points

### Frontend (admin-config.js)
- SUPABASE_URL
- SUPABASE_ANON_KEY

### Frontend (active-students.js)
- ACTIVE_STUDENTS_REFRESH_INTERVAL = 30 seconds
- ACTIVE_WINDOW_MINUTES = 5 minutes

### Backend (active_student_service.jl)
- ACTIVE_WINDOW_MINUTES = 5 minutes
- Supabase credentials for database access

### Database (profiles table)
- last_seen column type: TIMESTAMP
- last_seen index for performance

## Security Layers

### 1. Frontend Layer
- Token stored in sessionStorage (not localStorage) for security
- Cleared on browser close
- Only transmitted in Authorization header
- CORS prevents cross-origin requests

### 2. Backend Layer
- JWT signature verification
- User ID extraction from token claims
- Role-based access (can enable admin-only access)
- HTTPS (in production)

### 3. Database Layer
- Supabase JWT validation
- Row-level security (configurable)
- API key management by Supabase

## Performance Considerations

### Frontend
- Polling interval: 30 seconds (configurable)
- Debouncing: preventDefault rapid API calls
- Local state: minimal, refreshed from API

### Backend
- Active window: 5 minutes (configurable)
- Database query: indexed on last_seen
- Response size: only active students (not full database)
- No in-memory state: all data from persistent database

### Database
- Index on: profiles.last_seen
- Query performance: O(log n) with index
- Writes: Only on student activity (every API call)
- Reads: Dashboard poll every 30 seconds

## Scalability

### Current Design
- Suitable for: 100-1000 concurrent users
- Polling: 30-second intervals
- Database queries: Efficient with index

### Optimizations for Scale
1. **Increase refresh interval** (trade-off: less frequent updates)
2. **WebSocket connection** (real-time, bidirectional)
3. **Redis cache** (cache active students list)
4. **Separate analytics database** (track without blocking)

## Error Handling

### Frontend
- Login failures: Show error modal
- API failures (401): Redirect to login
- API failures (500): Show error message
- Network errors: Graceful degradation

### Backend
- Invalid JWT: Return 401
- Expired token: Return 401
- Database errors: Return 500
- Query errors: Return 500 with error message

### Database
- Connection failures: Backend returns 500
- Query timeouts: Backend returns 500
- Data inconsistencies: Handled by transaction logic
