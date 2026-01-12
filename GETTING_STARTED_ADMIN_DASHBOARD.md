# Getting Started - Admin Dashboard

## Prerequisites

1. **Backend Server**: Julia/Genie server running on port 8000
2. **Supabase Project**: PostgreSQL database configured
3. **User Account**: At least one user account for testing admin login
4. **Student Accounts**: At least one student account for testing active student tracking
5. **Database Schema**: `profiles` table with `last_seen` column

## Verification Steps

### Step 1: Verify Backend is Running
```bash
curl http://localhost:8000/ping
```
Expected output:
```json
{"status":"admin alive"}
```

### Step 2: Verify Supabase is Configured
- Check if SUPABASE_URL and SUPABASE_KEY are set in:
  - `frontend/js/admin-config.js` (lines 6-7)
- Verify credentials work by visiting: `https://supabase.com/dashboard`

### Step 3: Verify Database Exists
```sql
-- Run in Supabase SQL editor
SELECT * FROM profiles LIMIT 1;
```
Should return profile data (even if empty initially).

## Getting Started (First Time)

### Step 1: Start the Backend
```bash
cd backend
julia --project=. server.jl
```
Wait for message: "Listening on: 127.0.0.1:8000"

### Step 2: Open Admin Portal
- Open browser: `http://localhost:8000/admin`
- You should see: **Admin Login Modal**

### Step 3: Test Admin Login
1. Enter a valid Supabase account email
2. Enter the correct password
3. Click "Login"
4. **Expected**: Modal disappears, dashboard loads
5. **Console check**: Look for `[Admin Auth] Login successful`

### Step 4: Test Student Activity
1. Open new tab: `http://localhost:8000` (or student portal URL)
2. Log in as a student
3. Return to admin tab
4. Wait up to 30 seconds
5. **Expected**: Student appears in "Online Students" section

## Testing the Flow

### Test Case 1: Admin Can Login
```
✓ Visit /admin
✓ See login modal
✓ Enter credentials
✓ Modal closes
✓ Dashboard displays
```

### Test Case 2: Active Students Display
```
✓ Admin is logged in
✓ Open student portal in another tab
✓ Student logs in
✓ Return to admin tab
✓ Student appears within 30 seconds
✓ Last seen time is recent
```

### Test Case 3: Refresh Updates
```
✓ Dashboard shows student
✓ Wait 30 seconds
✓ Dashboard refreshes automatically
✓ Data updates if student was active
✓ Student disappears after ~5 minutes of inactivity
```

## Debugging

### Check Admin Auth Status
Open browser DevTools → Console, run:
```javascript
sessionStorage.getItem('admin_access_token')
```
Should return: JWT token string (long alphanumeric)

### Check API Response
1. Open DevTools → Network tab
2. Filter: `active-students`
3. Watch for requests to: `/api/admin/active-students?minutes=5`
4. Check Response: Should show JSON with student data

### Check Console Logs
Filter console output by typing: `Active Students` or `Admin Auth`
Should see debug messages like:
```
[Admin Auth] Login successful
[Active Students] Response status: 200
```

### Check Database
Run in Supabase:
```sql
SELECT id, full_name, last_seen, role 
FROM profiles 
WHERE role = 'student'
ORDER BY last_seen DESC
LIMIT 10;
```

## Common Startup Issues

### Issue: "Cannot reach localhost:8000"
**Solution**: 
- Ensure backend server is running
- Check port 8000 is not in use: `lsof -i :8000`
- Start backend: `cd backend && julia --project=. server.jl`

### Issue: "Admin login fails with 'error'"
**Solution**:
- Verify credentials in admin-config.js (lines 6-7)
- Check Supabase account email/password is correct
- Ensure user exists in Supabase authentication

### Issue: "Login works but 401 error on API"
**Solution**:
- Check browser console for token: `sessionStorage.getItem('admin_access_token')`
- If empty, re-login
- Verify backend is running: `curl localhost:8000/ping`

### Issue: "No students showing in active list"
**Solution**:
- Ensure a student is logged in to student portal
- Check 5-minute window: Student must have accessed API within 5 minutes
- Verify student's `last_seen` in database is recent
- Wait 30 seconds for auto-refresh

## Configuration Changes

### Change Refresh Rate
Edit: `frontend/js/active-students.js`, line 10
```javascript
const ACTIVE_STUDENTS_REFRESH_INTERVAL = 60 * 1000; // 60 seconds instead of 30
```

### Change Active Window
Edit: `frontend/js/active-students.js`, line 11
```javascript
const ACTIVE_WINDOW_MINUTES = 10; // 10 minutes instead of 5
```
Also update backend: `backend/services/active_student_service.jl`
```julia
const ACTIVE_WINDOW_MINUTES = 10
```

### Add Logout Button
Add to: `frontend/admin.html` in header section
```html
<button onclick="handleAdminLogout()">Logout</button>
```

## Running Multiple Admins

Multiple admins can log in simultaneously:
1. Each logs in separately on their browser
2. Each gets their own JWT token
3. All receive same student data
4. No conflicts or issues

## Production Deployment

Before deploying to production:

1. **Verify Credentials**
   - [ ] SUPABASE_URL is correct
   - [ ] SUPABASE_ANON_KEY is correct
   - [ ] JWT validation is enabled

2. **Security**
   - [ ] Enable HTTPS only
   - [ ] Verify CORS headers
   - [ ] Check role-based access control

3. **Performance**
   - [ ] Test with 10+ concurrent admins
   - [ ] Monitor API response times
   - [ ] Check database query performance

4. **Monitoring**
   - [ ] Enable logging
   - [ ] Monitor error rates
   - [ ] Track active user metrics

## Logs to Monitor

### Frontend Console Logs
```
[Admin Auth] ...      - Authentication events
[Active Students] ... - API communication
```

### Backend Logs
```
User {id} accessed active students (role: admin)
@error "Error in get_active_students: ..."
@warn "Unauthenticated access attempt"
```

### Database Activity
Monitor queries on `profiles` table:
- Read frequency: Every 30 seconds (polling)
- Write frequency: Every API call (update last_seen)
- Query pattern: WHERE last_seen >= NOW() - 5 minutes

## Support Resources

1. **Quick Start**: `ADMIN_DASHBOARD_QUICK_REFERENCE.md`
2. **Full Implementation**: `ADMIN_DASHBOARD_IMPLEMENTATION.md`
3. **Architecture**: `ADMIN_DASHBOARD_ARCHITECTURE.md`
4. **Code Changes**: `CODE_CHANGES_REFERENCE.md`
5. **Checklist**: `ADMIN_DASHBOARD_CHECKLIST.md`

## Next Steps

1. ✅ Complete first-time verification (above)
2. ✅ Test admin login
3. ✅ Test active student display
4. ⬜ (Optional) Add logout button
5. ⬜ (Optional) Enable admin role enforcement
6. ⬜ (Optional) Add WebSocket for real-time updates

## Contact / Issues

If you encounter issues:
1. Check browser console for error messages
2. Review the relevant documentation file
3. Verify backend server is running
4. Check Supabase credentials
5. Ensure student is logged in (for testing active students)

---

**You are now ready to use the Admin Dashboard!**
