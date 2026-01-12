"""
Auth Middleware for Supabase JWT Token Verification
Verifies JWT tokens from Authorization header and provides user context
"""

using HTTP
using JSON

# Verify Supabase JWT token from Authorization header
function verify_auth_token(headers::Dict)
    auth_header = get(headers, "Authorization", "")
    
    if isempty(auth_header)
        return (valid=false, user_id=nothing, error="No authorization header")
    end
    
    if !startswith(auth_header, "Bearer ")
        return (valid=false, user_id=nothing, error="Invalid authorization format")
    end
    
    token = auth_header[8:end]  # Remove "Bearer " prefix
    
    # TODO: Verify JWT token with Supabase secret
    # For now, we'll extract the user_id from token
    # In production, verify the token signature
    
    try
        # Decode JWT (simple base64 decode of payload)
        parts = split(token, ".")
        if length(parts) != 3
            return (valid=false, user_id=nothing, error="Invalid token format")
        end
        
        # The payload is the second part
        payload_encoded = parts[2]
        # Add padding if necessary
        padding = (4 - (length(payload_encoded) % 4)) % 4
        payload_encoded = payload_encoded * "="^padding
        
        payload_json = String(base64decode(payload_encoded))
        payload = JSON.parse(payload_json)
        
        user_id = get(payload, "sub", nothing)
        
        if isnothing(user_id)
            return (valid=false, user_id=nothing, error="Token missing user ID")
        end
        
        return (valid=true, user_id=user_id, error=nothing)
    catch e
        return (valid=false, user_id=nothing, error="Token verification failed: $(e.msg)")
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
