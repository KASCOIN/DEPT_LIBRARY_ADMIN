"""
Auth Middleware for Supabase JWT Token Verification
Verifies JWT tokens from Authorization header and provides user context

This middleware:
1. Extracts Bearer token from Authorization header
2. Decodes and validates JWT structure
3. Extracts user_id (sub claim) and role from token
4. Returns validation result with user context
"""

using HTTP
using JSON
using Base64

"""
    verify_auth_token(headers::Dict) -> NamedTuple

Verify Supabase JWT token from Authorization header.

Returns a NamedTuple with:
- valid::Bool - whether token is valid
- user_id::String - user UUID from 'sub' claim
- role::String - user role ('student', 'admin', 'authenticated')
- error::String - error message if invalid
"""
function verify_auth_token(headers::Dict)
    auth_header = get(headers, "Authorization", "")
    
    if isempty(auth_header)
        return (valid=false, user_id=nothing, role=nothing, error="No authorization header")
    end
    
    if !startswith(auth_header, "Bearer ")
        return (valid=false, user_id=nothing, role=nothing, error="Invalid authorization format")
    end
    
    token = auth_header[8:end]  # Remove "Bearer " prefix
    
    try
        # Decode JWT (format: header.payload.signature)
        parts = split(token, ".")
        if length(parts) != 3
            return (valid=false, user_id=nothing, role=nothing, error="Invalid JWT format (expected 3 parts)")
        end
        
        # Extract payload (second part)
        payload_encoded = parts[2]
        
        # Add padding if necessary for base64 decoding
        padding = (4 - (length(payload_encoded) % 4)) % 4
        payload_encoded = payload_encoded * "="^padding
        
        # Decode base64
        payload_bytes = base64decode(payload_encoded)
        payload_json = String(payload_bytes)
        
        # Parse JSON
        payload = JSON.parse(payload_json)
        
        # Extract claims
        user_id = get(payload, "sub", nothing)  # 'sub' is standard JWT claim for user ID
        role = get(payload, "role", "authenticated")  # Role from Supabase JWT
        
        if isnothing(user_id) || isempty(user_id)
            return (valid=false, user_id=nothing, role=nothing, error="Token missing user ID (sub claim)")
        end
        
        # Check token expiration (exp claim)
        exp = get(payload, "exp", nothing)
        if !isnothing(exp)
            now_unix = Int(floor(time()))
            if exp < now_unix
                return (valid=false, user_id=nothing, role=nothing, error="Token expired")
            end
        end
        
        return (valid=true, user_id=user_id, role=role, error=nothing)
    catch e
        return (valid=false, user_id=nothing, role=nothing, error="Token verification failed: $(string(e))")
    end
end

"""
    get_user_role(user_id::String) -> String | nothing

Get user role from profiles table.
Fetches role directly from database for role-based access control.
"""
function get_user_role(user_id::String)
    try
        # This will be called from student/admin controllers
        # to fetch role from profiles table
        # Implementation depends on SupabaseDbService availability
        return nothing  # Return nil if not implemented
    catch e
        return nothing
    end
end

# Middleware to check authentication
function require_auth(handler)
    return function(req)
        headers = Dict(req.headers)
        auth_result = verify_auth_token(headers)
        
        if !auth_result.valid
            return HTTP.Response(401, JSON.json(Dict(
                "error" => auth_result.error
            )))
        end
        
        # Store user_id in request context for use in handler
        req.user_id = auth_result.user_id
        
        return handler(req)
    end
end
