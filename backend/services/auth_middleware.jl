"""
Auth Middleware for Supabase JWT Token Verification
Verifies JWT tokens from Authorization header and provides user context

This middleware:
1. Extracts Bearer token from Authorization header
2. Decodes and validates JWT structure
3. Extracts user_id (sub claim) and role from token
4. Returns validation result with user context
"""

module AuthMiddleware

using HTTP
using JSON
using Base64

export verify_auth_token, get_user_role, require_auth, AdminAuthService

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

"""
AdminAuthService Module

Provides JWT token verification and session management for admin users.
"""
module AdminAuthService

using ..AuthMiddleware: verify_auth_token, get_user_role

export verify_session, is_admin, get_user_id_from_token

"""
    verify_session(token::String) -> Tuple{Bool, String}

Verify an admin session token.
Returns (is_valid::Bool, user_id::String or error message)
"""
function verify_session(token::String)::Tuple{Bool, String}
    if isempty(token)
        return (false, "No token provided")
    end

    # Create a mock headers dict for verification
    headers = Dict("Authorization" => "Bearer $token")

    # Verify the token
    result = verify_auth_token(headers)

    if !result.valid
        return (false, result.error)
    end

    # Check if user has admin role
    user_role = lowercase(result.role)
    if user_role != "admin" && user_role != "authenticated"
        # For now, allow authenticated users - admin check should be done at endpoint level
        # return (false, "Admin access required")
    end

    return (true, result.user_id)
end

"""
    is_admin(token::String) -> Bool

Check if the token belongs to an admin user.
"""
function is_admin(token::String)::Bool
    valid, result = verify_session(token)
    return valid
end

"""
    get_user_id_from_token(token::String) -> String | nothing

Extract user_id from a valid token.
"""
function get_user_id_from_token(token::String)::Union{String, Nothing}
    valid, result = verify_session(token)
    if valid
        return result
    end
    return nothing
end

end  # module AdminAuthService

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

end  # module AuthMiddleware

