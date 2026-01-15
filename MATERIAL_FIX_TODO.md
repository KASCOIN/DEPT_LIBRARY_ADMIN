# Material Upload Fix - TODO List

## Issue
Internal server error when uploading materials. Root cause analysis:

1. **Payload type handling**: `rawpayload()` returns `Vector{UInt8}`, not `String`
2. **Base64 decoding**: Frontend sends raw base64 without prefix, but backend expects prefixed format
3. **Error handling**: Insufficient error handling causes 500 errors instead of proper error messages
4. **Debugging**: No logging makes troubleshooting difficult

## Fixes Implemented

### 1. Fixed `post_materials()` function in admin_controller.jl
✅ Handle `Vector{UInt8}` from `rawpayload()` correctly  
✅ Fix base64 decoding for both prefixed and non-prefixed strings  
✅ Add comprehensive error logging with [POST_MATERIALS] prefix  
✅ Return descriptive error messages (400 for client errors, 500 for server errors)  
✅ Added try-catch for JSON parsing with detailed error messages  
✅ Added try-catch for base64 decoding with detailed error messages  

### 2. Added proper error handling in supabase_service.jl
✅ Added detailed logging for upload operations  
✅ Added HTTP 413 (Payload Too Large) handling  
✅ Log actual response body for failed requests  
✅ Log file size before upload  

### 3. What the fixes address
- **Empty request body**: Proper 400 response with message
- **Invalid JSON**: Detailed error message showing what failed
- **Invalid base64**: Clear error message for decoding failures  
- **Missing required fields**: Separate validation for course_code and programme
- **Supabase upload failures**: Logged with actual error from Supabase
- **Connection/timeout errors**: Caught and returned as 500 with message

## Testing
To test the fix:
1. Restart the Julia server
2. Try uploading a material file
3. Check server logs for `[POST_MATERIALS]` and `[SUPABASE_UPLOAD]` messages
4. If there's an error, the frontend should now show a descriptive error message

## Changes Made
- `backend/controllers/admin_controller.jl` - Enhanced `post_materials()` function
- `backend/services/supabase_service.jl` - Enhanced `upload_file()` with better logging

