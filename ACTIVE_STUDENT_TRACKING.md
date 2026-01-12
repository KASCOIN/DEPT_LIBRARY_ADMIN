## Active Student Tracking Implementation

### Overview
Complete server-side active student tracking system that:
- Tracks when students were last active via `last_seen` timestamp
- Updates on every authenticated student API request
- Queries active students from database (no in-memory state)
- Displays active students in admin dashboard with 30-second refresh
- Uses role-based access control with JWT validation

---

### Step 1: Database Migration

**Add `last_seen` column to Supabase:**

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Go to **SQL Editor** → **New Query**
4. Paste and run the SQL from `backend/migrations/002_add_last_seen.sql`:

```sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE DEFAULT NULL;
COMMENT ON COLUMN profiles.last_seen IS 'Timestamp of last API activity by the student, used for active student tracking';
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen ON profiles(last_seen DESC);
UPDATE profiles SET last_seen = created_at WHERE last_seen IS NULL;
```

**Verify:** Check Tables → profiles → Columns, should see `last_seen`

---

### Step 2: Backend Implementation

#### New Service: `ActiveStudentService`
File: `backend/services/active_student_service.jl`

**Functions:**
- `update_last_seen(user_id)` - Updates student's last_seen timestamp
- `get_active_students(minutes)` - Queries active students from database
- `get_active_count(minutes)` - Returns count of active students
- `format_active_student(student)` - Formats for API response

**Configuration:**
```julia
const ACTIVE_WINDOW_MINUTES = 5  # Change this to adjust active window
```

#### Modified Controllers

**AdminController**
- Added `get_active_students()` endpoint
- JWT validation with admin role check
- Supports query parameter: `?minutes=X` for custom time windows
- Exported in `admin.jl` routes

**StudentController**  
- Added `update_last_seen()` calls in:
  - `get_student_profile()` - Called on profile fetch
  - `get_material_view_url()` - Called on material access
- Updates database on every authenticated request

---

### Step 3: Admin API Endpoint

**Endpoint:** `GET /api/admin/active-students`

**Requirements:**
- Admin-only (role validation via JWT)
- Returns students active within last N minutes

**Query Parameters:**
- `minutes` - Custom time window (default: 5 minutes)

**Example Request:**
```bash
curl -H "Authorization: Bearer <admin_jwt>" \
  "http://localhost:8000/api/admin/active-students?minutes=10"
```

**Response:**
```json
{
  "success": true,
  "count": 5,
  "window_minutes": 10,
  "timestamp": "2026-01-12T14:30:00Z",
  "students": [
    {
      "id": "uuid-123",
      "email": "student@example.com",
      "full_name": "John Doe",
      "matric_no": "230908001",
      "programme": "Meteorology",
      "level": "300",
      "last_seen": "2026-01-12T14:25:30Z",
      "status": "active"
    }
  ]
}
```

---

### Step 4: Frontend Dashboard

**File:** `frontend/js/active-students.js`

**Features:**
- Fetches active students every 30 seconds
- Displays live count and list in admin dashboard
- Shows last activity time (e.g., "5m ago", "Just now")
- No local storage or in-memory state
- All data persisted in Supabase

**Update Interval:**
```javascript
const ACTIVE_STUDENTS_REFRESH_INTERVAL = 30 * 1000; // 30 seconds
```

**Active Window (must match backend):**
```javascript
const ACTIVE_WINDOW_MINUTES = 5;
```

---

### How It Works

#### Student Activity Flow
1. Student logs in → Creates session with JWT
2. Student performs any authenticated action:
   - Loads profile
   - Views/downloads materials
   - (Extensible for other API calls)
3. Backend updates `profiles.last_seen = NOW()` in Supabase
4. All updates are atomic, server-side, and persistent

#### Admin Monitoring Flow
1. Admin views dashboard
2. JavaScript fetches `/api/admin/active-students` every 30 seconds
3. JWT from admin session validates role
4. Backend queries `WHERE last_seen >= (NOW - 5 minutes)`
5. Results display in real-time with formatted timestamps

#### Data Persistence
- **No in-memory state**: All tracking in Supabase database
- **No local storage**: Frontend reads fresh data on each refresh
- **Database-backed**: Survives server restarts
- **Scalable**: Works with multiple backend instances

---

### Testing

#### 1. Verify Database Column
```sql
SELECT id, email, last_seen FROM profiles LIMIT 5;
```

#### 2. Test Student Activity
- Log in as student
- Go to materials section (triggers `get_material_view_url`)
- Check Supabase: `last_seen` should be recently updated

```sql
SELECT id, email, last_seen FROM profiles 
WHERE email = 'student@example.com';
```

#### 3. Test Admin Endpoint
```bash
# Get admin JWT token first
# Then:
curl -H "Authorization: Bearer <admin_jwt>" \
  "http://localhost:8000/api/admin/active-students"
```

#### 4. Test Dashboard Display
1. Log in as admin
2. Go to Dashboard
3. "Students Online" section shows active count
4. List updates every 30 seconds
5. Timestamps show "Just now", "5m ago", etc.

---

### Configuration

#### Change Active Window
**Backend:** `backend/services/active_student_service.jl`
```julia
const ACTIVE_WINDOW_MINUTES = 5  # Change to desired minutes
```

**Frontend:** `frontend/js/active-students.js`
```javascript
const ACTIVE_WINDOW_MINUTES = 5;  // Must match backend
```

#### Change Refresh Interval
**Frontend:** `frontend/js/active-students.js`
```javascript
const ACTIVE_STUDENTS_REFRESH_INTERVAL = 30 * 1000;  // 30 seconds
```

---

### API Response Codes

| Code | Meaning |
|------|---------|
| 200 | Success - active students returned |
| 401 | Unauthorized - missing/invalid JWT |
| 403 | Forbidden - user is not admin |
| 500 | Server error - database issue |

---

### Security Features

✓ JWT validation on every request
✓ Role-based access control (admin-only)
✓ Server-side timestamp updates (no client manipulation)
✓ Database-backed (persistent, scalable)
✓ No sensitive data exposure
✓ CORS headers included

---

### Troubleshooting

**Students not appearing in active list:**
1. Check `last_seen` column exists: `\d profiles`
2. Verify students performed authenticated actions
3. Check query window: `SELECT * FROM profiles WHERE last_seen >= NOW() - INTERVAL '5 minutes'`
4. Check JWT has admin role: Decode token at jwt.io

**No active students shown in dashboard:**
1. Ensure admin is logged in with valid token
2. Check browser console for errors
3. Verify `/api/admin/active-students` returns 200
4. Check active students interval is running: Look for "[Active Students] Tracking started" in console

**Empty response from API:**
1. All students may be inactive (older than 5 minute window)
2. Try `?minutes=60` to get students active in last hour
3. Verify students actually performed API calls

---

### Files Changed

**Backend:**
- `backend/migrations/002_add_last_seen.sql` - Database schema
- `backend/services/active_student_service.jl` - New tracking service
- `backend/controllers/admin_controller.jl` - New endpoint
- `backend/controllers/student_controller.jl` - Track activity
- `backend/routes/admin.jl` - New route
- `backend/server.jl` - Include service

**Frontend:**
- `frontend/js/active-students.js` - Dashboard component
- `frontend/admin.html` - Load script

---

### Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│         STUDENT PORTAL (Authenticated)              │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Student Action (view material, fetch profile)     │
│         ↓                                           │
│  StudentController receives request                │
│         ↓                                           │
│  ActiveStudentService.update_last_seen(user_id)   │
│         ↓                                           │
│  Database: UPDATE profiles SET last_seen = NOW()  │
│         ↓                                           │
│  Response sent to student                          │
│                                                     │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│       ADMIN DASHBOARD (Every 30 seconds)            │
├─────────────────────────────────────────────────────┤
│                                                     │
│  frontend/js/active-students.js                    │
│         ↓                                           │
│  GET /api/admin/active-students                    │
│         ↓                                           │
│  AdminController.get_active_students()             │
│         ↓                                           │
│  JWT validation + admin role check                 │
│         ↓                                           │
│  ActiveStudentService.get_active_students()        │
│         ↓                                           │
│  Database Query:                                   │
│  SELECT * FROM profiles                            │
│  WHERE role='student'                              │
│  AND last_seen >= (NOW - 5 minutes)               │
│  ORDER BY last_seen DESC                           │
│         ↓                                           │
│  Format response + return to frontend              │
│         ↓                                           │
│  Update Dashboard UI                               │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

### Next Steps

1. ✅ Apply database migration (SQL)
2. ✅ Restart backend server
3. ✅ Log in as student and perform actions
4. ✅ Check admin dashboard for active students
5. ✅ Monitor `/api/admin/active-students` endpoint
6. ✅ Adjust time windows as needed

