# Material Upload and Display - Professional Fix Verification

## Changes Made

### Frontend Changes (materials.js)

1. **Fixed API Call with Proper Filters** (Line 311-337)
   - Now sends query parameters to `/api/materials` endpoint
   - Parameters: `programme`, `level`, `semester`, `course_code`
   - Backend filters at database level (more efficient)

2. **Enhanced Button State Management** (Line 485-515)
   - Added 800ms delay to allow Supabase metadata insert to complete
   - Added fallback button state update if reload fails
   - Proper error handling to prevent stuck "Updating..." state
   - All three buttons (View, Download, Delete) are enabled after upload

3. **Material Label Update** (Line 475-490)
   - Material name displays immediately with file icon (📄, 📊, 📝)
   - Shows file size in MB
   - Updates dynamically when loadMaterialsForCourse completes

4. **Form Submission Fix** (Line 276-280)
   - Properly triggers material reload after batch upload
   - Uses course change event listener to reload materials

### Backend Changes (admin_controller.jl)

1. **Improved Metadata Insert** (Line 360-405)
   - Only inserts essential fields (avoids schema issues)
   - Optional fields added only if they have values
   - Better HTTP status code detection (HTTP/1.1 and HTTP/2)
   - Detailed logging at each step

2. **Enhanced Debug Logging** (Line 454-505)
   - Raw Supabase response logged
   - Number of materials received logged
   - Filter parameters logged for troubleshooting
   - Parse errors caught and logged

3. **Response Enhancement** (Line 411-423)
   - Includes `material_name` in response
   - Includes `programme` in response
   - Better message indicating async metadata insert

## Testing Checklist

### Admin Portal - Upload a Material

1. **Setup**
   - [ ] Go to Admin Portal → Materials section
   - [ ] Select Programme (e.g., "Computer Science")
   - [ ] Select Level (e.g., "100")
   - [ ] Click "Fetch Courses" button
   - [ ] Select a Course

2. **Per-Slot Upload**
   - [ ] Select a file in Material Slot 1
   - [ ] Click "📤 Upload" button
   - [ ] Notification appears: "Material 1 uploaded successfully"

3. **Button State Change**
   - [ ] Upload button changes to "✓ Uploaded" (disabled, 50% opacity)
   - [ ] View button becomes enabled (full opacity)
   - [ ] Download button becomes enabled (full opacity)
   - [ ] Delete button becomes enabled (full opacity)

4. **Label Update**
   - [ ] "Material 1" label changes to actual filename
   - [ ] File icon appears (📄 for PDF, 📊 for PPTX, etc.)
   - [ ] File size appears below filename
   - [ ] Text color is green (#28a745)

5. **Expected Wait Time**
   - [ ] Total time: ~1-2 seconds (includes 800ms Supabase insert delay)
   - [ ] Button shows "⏳ Updating..." during this time

### Student Portal - View Materials

1. **Setup**
   - [ ] Go to Student Portal
   - [ ] Click Materials in sidebar
   - [ ] Select Semester (e.g., "First Semester")
   - [ ] Select Course (the one you uploaded material to)

2. **Material Appears**
   - [ ] Material name appears in list
   - [ ] File icon appears
   - [ ] Download button is available
   - [ ] View button appears (if PDF)

3. **Material Download**
   - [ ] Click download button
   - [ ] File downloads successfully
   - [ ] File name matches uploaded filename

## Debug Information to Check

### Browser Console (F12)

Look for these logs (in order):

```
🔍 Fetching materials from: /api/materials?...
📦 Materials loaded from API: [...]
📊 Received N materials with filters: ...
🔧 Slot materials assigned: {...}
✓ Button states updated for N slots
✓ Materials reloaded for slot 1
```

If you see errors, check:
- Network tab for 404 responses
- Search for "error" in console logs
- Check status messages in notifications

### Server Console (Julia)

Look for these logs:

```
[MaterialMeta] Inserting material: filename.pdf for COURSE101
[MaterialMeta] PAYLOAD: {...}
[MaterialMeta] ✓ Material metadata inserted successfully (HTTP 201)
```

Or if there are issues:

```
[DebugMaterials] Raw response from Supabase: [...]
[DebugMaterials] Received N materials from Supabase
[DebugMaterials] Filtering with: programme=CS, level=100, ...
[DebugMaterials] Filtered to N materials
```

## Troubleshooting

### Problem: Upload succeeds but label doesn't show material name

**Check:**
1. Is the file size showing? (If yes, label was updated)
2. Check browser console for logs
3. Check server console for MaterialMeta status
4. Try uploading again after 5 seconds (timing issue)

**Solution:**
- Clear browser cache: Ctrl+Shift+Delete
- Restart backend server: `julia server.jl` in backend directory
- Wait 2-3 seconds before uploading next material

### Problem: Button state not updating (stays as "Uploading...")

**Check:**
1. Browser console for errors
2. Server console for MaterialMeta errors
3. Network tab for failed API requests

**Solution:**
- The fallback code should set button state correctly
- If not, manually refresh the page
- Check if Supabase credentials are correct

### Problem: Students still can't see materials

**Check:**
1. Verify material was uploaded in admin portal (check button state)
2. Check server console for DebugMaterials logs
3. Check if API returns empty array: `curl "http://localhost:8000/api/materials?programme=...&level=...&course_code=..."`
4. Verify material_metadata table exists in Supabase

**Solution:**
- Ensure metadata insert succeeded (HTTP 201 in server logs)
- Check Supabase database for materials table
- Verify column names match: storage_path, material_name, programme, level, course_code, semester
- Try uploading a test material with verbose logging enabled

### Problem: API returns empty array even though metadata should be inserted

**Possible Causes:**
1. Supabase table doesn't exist
2. Supabase permissions issue
3. Column names don't match
4. Filters are too strict

**Solution:**
1. Check Supabase dashboard → Database → materials table
2. Verify all columns exist
3. Check row policies allow SELECT with filters
4. Try query without filters: `/api/materials` (no query params)

## Performance Notes

- Upload to Supabase Storage: ~1 second (depends on file size)
- Metadata insert to database: ~500-800ms (includes network delay)
- Material reload: ~200-500ms
- **Total time for one material: 1.5-2 seconds**

If it's taking longer, check network conditions or Supabase load.

## Rollback Instructions

If you need to revert these changes:

1. Frontend: Restore `frontend/js/forms/materials.js` from git
2. Backend: Restore `backend/controllers/admin_controller.jl` from git
3. Restart backend server: `julia server.jl`
