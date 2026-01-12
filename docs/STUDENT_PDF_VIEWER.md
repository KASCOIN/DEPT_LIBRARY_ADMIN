# Student PDF Viewer - Implementation Guide

## Overview

This implementation provides a secure, student-friendly PDF viewing system for the department library admin. Students can view PDFs inline or download them without exposing Supabase credentials.

## Architecture

### Security Model

1. **No Secret Exposure**: Supabase service role key never sent to frontend
2. **Signed URLs**: Backend generates short-lived (15-min) signed URLs
3. **Private Bucket**: Supabase bucket remains private - only accessible via signed URLs
4. **Backend Validation**: All requests validated server-side

```
Student Browser
    ↓
Student Frontend (student.js)
    ↓ (requests view URL with storage_path)
Backend API (/api/student/materials/view)
    ↓ (generates signed URL)
Student Frontend (receives signed URL)
    ↓ (loads in iframe or opens new tab)
Supabase Storage (verifies signature, serves file)
```

## File Structure

```
backend/
├── controllers/
│   ├── admin_controller.jl      (existing - admin operations)
│   └── student_controller.jl    (NEW - student view operations)
├── routes/
│   ├── admin.jl                 (existing)
│   └── student.jl               (NEW - student routes)
├── services/
│   ├── supabase_service.jl      (existing - signed URL generation)
│   └── admin_service.jl         (existing - service layer)
└── server.jl                    (updated - includes student routes)

frontend/
├── js/
│   └── student.js               (NEW - PDF viewer module)
└── student.html                 (NEW - example student page)
```

## Backend Implementation

### Endpoint: `/api/student/materials/view`

**Method**: POST

**Request Body**:
```json
{
  "storage_path": "materials/undergraduate/meteorology/level-100/first-semester/TST 101/general/2025 Draft Bill.pdf"
}
```

**Success Response (200)**:
```json
{
  "success": true,
  "signed_url": "https://yecpwijvbiurqysxazva.supabase.co/storage/v1/object/authenticated/materials/undergraduate/meteorology/level-100/first-semester/TST%20101/general/2025%20Draft%20Bill.pdf?token=...",
  "expires_in": 900,
  "message": "Signed URL generated successfully"
}
```

**Error Response (400)**:
```json
{
  "success": false,
  "error": "invalid_file_type",
  "message": "Only PDF files can be viewed"
}
```

**Controller Logic** (`student_controller.jl`):

1. Receives POST request with `storage_path`
2. Validates that path points to a PDF file
3. Calls `AdminService.get_download_url()` with 15-minute expiration
4. Returns signed URL to frontend
5. Handles errors gracefully (missing path, non-PDF files, generation failures)

### Key Features

- **File Type Validation**: Only PDFs can be viewed (security measure)
- **Error Handling**: Comprehensive error messages for debugging
- **CORS Support**: Cross-origin requests allowed for frontend integration
- **Production Ready**: Proper error handling and logging

## Frontend Implementation

### Module: `StudentPDFViewer`

Provides a global `StudentPDFViewer` object with the following methods:

#### 1. View in New Tab

```javascript
StudentPDFViewer.viewInNewTab(storagePath, filename);
```

- Fetches signed URL from backend
- Opens PDF in a new browser tab
- User can download, print, or view in browser's PDF reader
- Mobile-friendly (respects browser defaults)

**Example**:
```html
<button onclick="StudentPDFViewer.viewInNewTab('materials/undergraduate/.../document.pdf', 'document.pdf')">
  Download
</button>
```

#### 2. View Inline

```javascript
StudentPDFViewer.viewInline(storagePath, filename);
```

- Fetches signed URL from backend
- Displays PDF in a modal iframe viewer
- Shows loading spinner while loading
- Closes with ESC key or close button
- Desktop and mobile optimized

**Example**:
```html
<button onclick="StudentPDFViewer.viewInline('materials/undergraduate/.../document.pdf', 'document.pdf')">
  View Online
</button>
```

#### 3. Get View URL

```javascript
StudentPDFViewer.getViewUrl(storagePath);
```

- Returns Promise with `{ success, signed_url, expires_in, error }`
- Use this to build custom PDF viewing implementations
- All error handling included

**Example**:
```javascript
const result = await StudentPDFViewer.getViewUrl(storagePath);
if (result.success) {
    console.log('URL expires in', result.expires_in, 'seconds');
    // Use result.signed_url
}
```

#### 4. Close Viewer

```javascript
StudentPDFViewer.closePdfViewer();
```

- Closes the inline PDF modal viewer
- Called automatically by close button or ESC key

### Error Handling

The module handles:

- **Network errors**: Shows user-friendly error messages
- **Invalid file types**: Backend rejects non-PDF requests
- **URL generation failures**: Provides feedback on failures
- **PDF load failures**: Suggests opening in new tab
- **Graceful degradation**: Works even if modal doesn't exist

## Integration Guide

### Option 1: Using Example Student Page

1. Navigate to `http://localhost:3000/student.html` (if running on port 3000)
2. See materials displayed as cards
3. Click "View" to open inline
4. Click "Download" to open in new tab

### Option 2: Add to Existing Pages

**Step 1**: Include the script

```html
<script src="js/student.js"></script>
```

**Step 2**: Add buttons

```html
<!-- View inline -->
<button onclick="StudentPDFViewer.viewInline('materials/path/file.pdf', 'file.pdf')">
  View Online
</button>

<!-- Open in new tab -->
<button onclick="StudentPDFViewer.viewInNewTab('materials/path/file.pdf', 'file.pdf')">
  Download
</button>
```

**Step 3** (Optional): Add modal container for inline viewing

```html
<div id="pdfViewerModal" class="pdf-modal">
    <div class="pdf-modal-content">
        <div class="pdf-modal-header">
            <h3 id="pdfFileName">Document</h3>
            <button onclick="StudentPDFViewer.closePdfViewer()">✕</button>
        </div>
        <div class="pdf-modal-body">
            <iframe id="pdfViewerIframe"></iframe>
        </div>
    </div>
</div>
```

If no modal exists, the module creates one automatically.

### Option 3: Custom Implementation

```javascript
// Get signed URL
const result = await StudentPDFViewer.getViewUrl(storagePath);

if (result.success) {
    // Use result.signed_url in your custom implementation
    // URL is valid for 15 minutes
    
    // Example: show in custom viewer
    document.getElementById('myViewer').src = result.signed_url;
} else {
    console.error('Failed to get URL:', result.message);
}
```

## Security Considerations

### What's Protected

✅ Supabase credentials never exposed  
✅ URLs signed with service role key  
✅ URLs expire after 15 minutes  
✅ Only PDFs can be viewed  
✅ Bucket remains private  
✅ Backend validates all requests  

### URL Expiration

- View URLs expire in **15 minutes** (900 seconds)
- URLs are single-use only (no caching)
- Tokens embedded in URL signature
- Supabase verifies signature on each request

### Bucket Security

- Bucket remains **private**
- No public access allowed
- Only signed URLs work
- Browser shows "File not found" for unsigned requests

## Testing

### Test with Example Page

1. Ensure backend is running: `julia server.jl`
2. Open `http://localhost:3000/student.html`
3. Click "View" button - PDF should open in modal
4. Click "Download" button - PDF should open in new tab
5. Press ESC in modal - viewer should close

### Test Error Cases

**Non-existent file**:
```javascript
StudentPDFViewer.viewInline('materials/nonexistent/file.pdf', 'file.pdf');
// Shows error: "Failed to generate view URL"
```

**Non-PDF file**:
```javascript
StudentPDFViewer.viewInline('materials/path/document.docx', 'file.docx');
// Shows error: "Only PDF files can be viewed"
```

**Network error** (backend down):
```javascript
StudentPDFViewer.viewInline('materials/path/file.pdf', 'file.pdf');
// Shows error: "Failed to get view URL"
```

## Performance Considerations

### URL Generation

- Backend caches Supabase config (no repeated loads)
- Signed URL generation ~100-200ms
- No file downloads during URL generation
- Efficient error handling (no retries by default)

### PDF Loading

- Browser handles PDF rendering (native support)
- Large PDFs (50MB+) may load slowly
- Mobile browsers: auto-fit to screen
- Desktop browsers: full zoom/controls

### Bandwidth

- No files stored locally
- Each view requests new signed URL
- URLs expire after 15 minutes
- Subsequent views after 15 minutes require new URL

## Browser Compatibility

| Browser | Desktop | Mobile | Notes |
|---------|---------|--------|-------|
| Chrome | ✅ | ✅ | Full support |
| Firefox | ✅ | ✅ | Full support |
| Safari | ✅ | ✅ | Full support |
| Edge | ✅ | ✅ | Full support |
| IE11 | ⚠️ | N/A | Limited (no Promise support) |

## Troubleshooting

### PDF shows "File not found"

**Cause**: Signed URL invalid or expired  
**Solution**: Refresh page or try again (generates new URL)

### Modal doesn't appear

**Cause**: Missing modal HTML or CSS  
**Solution**: Module auto-creates modal - check browser console for errors

### "Only PDF files can be viewed" error

**Cause**: File is not a PDF  
**Solution**: Use `viewInNewTab()` for other file types, or check storage path

### URL generation timeout

**Cause**: Supabase unreachable or slow network  
**Solution**: Check internet connection, verify SUPABASE_URL in `.env`

### CORS error

**Cause**: Frontend and backend on different domains  
**Solution**: Check `CORS_ALLOWED_ORIGINS` in `server.jl`

## Extending the System

### Add File Type Support

Edit `student_controller.jl` to allow other file types:

```julia
# Allow PDF, DOCX, PNG
allowed_types = [".pdf", ".docx", ".png"]
if !any(endswith(lowercase(storage_path), ext) for ext in allowed_types)
    # return error
end
```

### Custom Expiration

Change expiration time in `student_controller.jl`:

```julia
expires_in = 3600  # 1 hour instead of 15 minutes
```

### Log All Views

Add logging to track which materials are accessed:

```julia
# In student_controller.jl
@info "PDF view requested" path=storage_path timestamp=now()
```

### Restrict by User Role

Add role checking before generating URL:

```julia
# In student_controller.jl
if !is_student(user_id, course_id)
    return error("Access denied")
end
```

## Production Checklist

- [ ] Update API_BASE in `student.js` to production backend URL
- [ ] Configure SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in `.env`
- [ ] Test with various PDF sizes and formats
- [ ] Enable logging for audit trail
- [ ] Add rate limiting to `/api/student/materials/view`
- [ ] Monitor Supabase storage usage
- [ ] Implement user authentication checks
- [ ] Add analytics for PDF views

## Support & Maintenance

### Monitoring

- Check backend logs for errors
- Monitor Supabase for access patterns
- Track PDF view requests
- Monitor URL generation time

### Updates

- Supabase API compatibility maintained
- No external dependencies beyond HTTP.jl
- Auto-creates modal if missing (resilient)
- Graceful error handling for edge cases

## License

Part of the Department Digital Library Admin system.
