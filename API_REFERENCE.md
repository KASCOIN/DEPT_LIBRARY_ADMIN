# Admin Authentication API Reference

## Overview
Complete API documentation for the Supabase-based admin authentication system.

## Authentication Endpoints

### 1. Verify Admin Role
**Endpoint:** `POST /api/admin/verify-role`

**Purpose:** Verify that a user has admin privileges

**Request Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Success Response (200):**
```json
{
    "is_admin": true,
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "admin@example.com",
    "message": "Admin access granted"
}
```

**Unauthorized Response (401):**
```json
{
    "is_admin": false,
    "error": "No authorization token provided"
}
```

**Forbidden Response (403):**
```json
{
    "is_admin": false,
    "error": "User role is 'student', not 'admin'",
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com"
}
```

**Error Response (500):**
```json
{
    "is_admin": false,
    "error": "Verification error"
}
```

## Protected Admin Endpoints

All protected endpoints require:
1. Valid JWT token in Authorization header
2. User role = 'admin' in profiles table

### 2. Upload Materials
**Endpoint:** `POST /api/admin/materials`

**Authentication:** Required (JWT + Admin Role)

**Request Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
    "file_base64": "base64_encoded_file_data",
    "filename": "document.pdf",
    "course": "CSC101",
    "programme": "Computer Science",
    "level": "100",
    "semester": "first",
    "category": "lecture"
}
```

**Success Response (200):**
```json
{
    "success": true,
    "message": "Material uploaded successfully"
}
```

**Unauthorized Response (401 or 403):**
```json
{
    "success": false,
    "error": "Unauthorized"
}
```

### 3. Delete Materials
**Endpoint:** `DELETE /api/admin/materials`

**Authentication:** Required (JWT + Admin Role)

**Request Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
    "object_name": "materials/2024/computer-science/csc101/first/abc123.pdf"
}
```

**Success Response (200):**
```json
{
    "success": true,
    "message": "Material deleted successfully"
}
```

### 4. Create Announcement
**Endpoint:** `POST /api/admin/news`

**Authentication:** Required (JWT + Admin Role)

**Request Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
    "programme": "Computer Science",
    "level": "100",
    "semester": "first-semester",
    "title": "Announcement Title",
    "body": "Full announcement content"
}
```

**Success Response (200):**
```json
{
    "success": true,
    "message": "News posted to database"
}
```

### 5. Create Course
**Endpoint:** `POST /api/admin/courses`

**Authentication:** Required (JWT + Admin Role)

**Request Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
    "programme": "Computer Science",
    "level": "100",
    "semester": "first",
    "code": "CSC101",
    "title": "Introduction to Programming"
}
```

**Success Response (200):**
```json
{
    "success": true,
    "message": "Course created successfully"
}
```

### 6. Update Course
**Endpoint:** `POST /api/admin/courses/update`

**Authentication:** Required (JWT + Admin Role)

**Request Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
    "programme": "Computer Science",
    "level": "100",
    "semester": "first",
    "old_code": "CSC101",
    "new_code": "CSC101",
    "new_title": "Intro to Programming (Updated)"
}
```

**Success Response (200):**
```json
{
    "success": true,
    "message": "Course updated successfully"
}
```

### 7. Delete Course
**Endpoint:** `DELETE /api/admin/courses`

**Authentication:** Required (JWT + Admin Role)

**Request Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
    "programme": "Computer Science",
    "level": "100",
    "semester": "first",
    "course_code": "CSC101"
}
```

**Success Response (200):**
```json
{
    "success": true,
    "message": "Course deleted successfully"
}
```

### 8. Create Timetable
**Endpoint:** `POST /api/admin/timetable`

**Authentication:** Required (JWT + Admin Role)

**Request Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
    "programme": "Computer Science",
    "level": "100",
    "semester": "first",
    "day_of_week": "Monday",
    "timetable": [
        {
            "code": "CSC101",
            "title": "Programming",
            "venue": "Lab 101",
            "lecturer": "Dr. Smith",
            "time": "09:00-11:00"
        }
    ]
}
```

**Success Response (200):**
```json
{
    "success": true,
    "message": "Timetable saved to database"
}
```

### 9. Delete Timetable Slot
**Endpoint:** `DELETE /api/admin/timetable`

**Authentication:** Required (JWT + Admin Role)

**Request Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
    "programme": "Computer Science",
    "level": "100",
    "semester": "first",
    "day_of_week": "Monday"
}
```

**Success Response (200):**
```json
{
    "success": true,
    "message": "Timetable slot deleted successfully"
}
```

### 10. Get Active Students
**Endpoint:** `GET /api/admin/active-students?minutes=5`

**Authentication:** Required (JWT + Admin Role)

**Request Headers:**
```
Authorization: Bearer <jwt_token>
```

**Query Parameters:**
- `minutes` (optional): Time window in minutes (default: 5)

**Success Response (200):**
```json
{
    "success": true,
    "count": 15,
    "students": [
        {
            "matric_number": "23CS001",
            "name": "John Doe",
            "programme": "Computer Science",
            "level": "100",
            "last_active": "2024-01-12T14:30:00Z"
        }
    ]
}
```

## Error Handling

### HTTP Status Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 200 | OK | Request successful |
| 400 | Bad Request | Invalid request format or missing required fields |
| 401 | Unauthorized | Missing or invalid JWT token |
| 403 | Forbidden | Valid token but user lacks admin role |
| 404 | Not Found | Resource not found |
| 500 | Server Error | Internal server error |

### Error Response Format

```json
{
    "success": false,
    "error": "Error description"
}
```

## JWT Token Structure

JWT tokens from Supabase contain:

```json
{
    "iss": "https://your-project.supabase.co",
    "sub": "user-uuid",
    "aud": "authenticated",
    "exp": 1705088400,
    "iat": 1705001000,
    "email": "admin@example.com",
    "email_confirmed_at": "2024-01-12T10:00:00Z",
    "phone_verified_at": null,
    "aud": "authenticated",
    "user_metadata": {},
    "role": "authenticated"
}
```

**Important Fields:**
- `sub` - User ID (used to check admin role)
- `exp` - Expiration timestamp (Unix epoch)
- `email` - User email address
- `iat` - Issued at timestamp

## Client Library Methods

### JavaScript/Frontend

#### Get Token
```javascript
const token = localStorage.getItem('admin_jwt');
```

#### Make Authenticated Request
```javascript
const response = await fetch('/api/admin/materials', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify(data)
});

if (response.status === 403) {
    // Redirect to login
    window.location.href = '/admin-login';
}
```

#### Check Admin Status
```javascript
const response = await fetch('/api/admin/verify-role', {
    method: 'POST',
    headers: {
        'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify({ token: token })
});

const result = await response.json();
if (result.is_admin) {
    console.log('Admin access granted');
} else {
    console.log('Not authorized as admin');
}
```

### Julia/Backend

#### Verify Token
```julia
valid, user_info = SupabaseAdminAuth.verify_admin_token(jwt_token)
```

#### Check Admin Role
```julia
is_admin, error_msg = SupabaseAdminAuth.is_admin_role(user_id)
```

#### Get Admin Info
```julia
admin_info = SupabaseAdminAuth.get_admin_user_info(user_id)
```

## Rate Limiting

**Recommended Rate Limits:**
- Login endpoint: 5 requests per minute per IP
- General admin endpoints: 60 requests per minute per user
- File upload endpoint: 10 requests per minute per user

## Security Headers

**Recommended Response Headers:**
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'self'
```

## Timeout Values

- Connection timeout: 10 seconds
- Read timeout: 10 seconds
- Token expiration: 3600 seconds (1 hour)
- Session cleanup: Daily

## Webhook Events

Admin actions can trigger webhook events:

```json
{
    "event": "admin.action",
    "timestamp": "2024-01-12T14:30:00Z",
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "action": "material_upload",
    "resource": "materials/2024/computer-science/csc101/first/abc123.pdf",
    "status": "success"
}
```

## Deprecated Endpoints

The following endpoints are maintained for backward compatibility but should not be used in new implementations:

- `POST /api/admin/auth/login` (Old simple auth)
- `POST /api/admin/auth/logout` (Old simple auth)
- `GET /api/admin/auth/verify` (Old simple auth)

These will be removed in a future version.
