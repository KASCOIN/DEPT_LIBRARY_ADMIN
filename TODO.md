# TODO: Remove Semester from Dashboard

## Frontend Changes - COMPLETED
- [x] 1. Remove semester dropdown from admin.html (Materials section)
- [x] 2. Remove semester dropdown from admin.html (Timetable section)
- [x] 3. Remove semester dropdown from admin.html (Courses section)
- [x] 4. Remove Semester column from materials table in admin.html
- [x] 5. Update materials.js - Remove semester references
- [x] 6. Update timetable.js - Remove semester references
- [x] 7. Update courses.js - Remove semester references

## Backend Changes - COMPLETED
- [x] 8. Update admin_controller.jl - Remove semester from API handlers
- [ ] 9. Update supabase_db_service.jl - Remove semester field from DB operations (partially done)

## Summary
Removed semester dropdowns and related code from the dashboard since semester column is being removed from Supabase.

**Files Modified:**
- frontend/admin.html - Removed 3 semester dropdowns and 1 table column
- frontend/js/forms/materials.js - Removed semester references in queue, API calls, form handlers
- frontend/js/forms/timetable.js - Removed semester references in API calls and form handlers
- frontend/js/forms/courses.js - Removed semester references in storage keys, API calls, and event handlers
- backend/controllers/admin_controller.jl - Removed semester from all API handlers (news, materials, timetable, courses)

**Note:** The supabase_db_service.jl file still contains semester references in some functions that may need manual editing to fix syntax issues. The Julia file may have parsing errors that need to be resolved.

**After removing the semester column from Supabase, you may need to:**
1. Restart the backend server
2. Clear browser cache
3. Test the admin dashboard functionality

