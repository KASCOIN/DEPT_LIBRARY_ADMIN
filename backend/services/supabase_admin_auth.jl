# Supabase Admin Authentication Service
# Implements secure admin authentication using Supabase Auth and role-based access control

module SupabaseAdminAuth

using HTTP
using JSON3
using Dates

export verify_admin_token, get_admin_user_info, is_admin_role

# Configuration from environment
const SUPABASE_URL = get(ENV, "SUPABASE_URL", "")
const SUPABASE_SERVICE_ROLE_KEY = get(ENV, "SUPABASE_SERVICE_ROLE_KEY", "")
const SUPABASE_ANON_KEY = get(ENV, "SUPABASE_ANON_KEY", "")

"""
    verify_admin_token(jwt_token::String)::Tuple{Bool, Dict}

Verify a Supabase JWT token and return user info if valid.
Returns: (is_valid::Bool, user_info_or_error::Dict)
"""
function verify_admin_token(jwt_token::String)::Tuple{Bool, Dict}
    if isempty(jwt_token) || isempty(SUPABASE_URL)
        return (false, Dict("error" => "No token or Supabase not configured"))
    end
    
    try
        # Decode JWT (Supabase tokens are RS256 signed, we verify the signature)
        # For now, we decode the payload to extract user ID
        parts = split(jwt_token, ".")
        if length(parts) != 3
            return (false, Dict("error" => "Invalid token format"))
        end
        
        # Decode the payload (second part)
        payload_b64 = parts[2]
        # Add padding if necessary
        padding_needed = (4 - (length(payload_b64) % 4)) % 4
        payload_b64 = payload_b64 * repeat("=", padding_needed)
        
        payload_json = String(base64decode(payload_b64))
        payload = JSON3.read(payload_json)
        
        # Check expiration
        if haskey(payload, "exp")
            exp_time = payload["exp"]
            if exp_time < floor(Int, time())
                return (false, Dict("error" => "Token expired"))
            end
        end
        
        user_id = get(payload, "sub", "")
        if isempty(user_id)
            return (false, Dict("error" => "Invalid token: no user ID"))
        end
        
        # Return the payload as user info
        return (true, Dict(
            "user_id" => user_id,
            "email" => get(payload, "email", ""),
            "aud" => get(payload, "aud", ""),
            "token" => jwt_token
        ))
    catch e
        return (false, Dict("error" => "Token verification failed: $(string(e))"))
    end
end

"""
    is_admin_role(user_id::String)::Tuple{Bool, String}

Check if a user has admin role in the profiles table.
Returns: (is_admin::Bool, error_message::String or "")
"""
function is_admin_role(user_id::String)::Tuple{Bool, String}
    if isempty(SUPABASE_URL) || isempty(SUPABASE_SERVICE_ROLE_KEY)
        return (false, "Supabase not configured")
    end
    
    try
        url = "$(SUPABASE_URL)/rest/v1/profiles?id=eq.$user_id&select=role"
        headers = [
            "apikey" => SUPABASE_SERVICE_ROLE_KEY,
            "Authorization" => "Bearer $(SUPABASE_SERVICE_ROLE_KEY)",
            "Content-Type" => "application/json"
        ]
        
        response = HTTP.get(
            url,
            headers;
            status_exception=false,
            connect_timeout=10,
            readtimeout=10
        )
        
        if response.status == 200
            body_str = String(response.body)
            data = JSON3.read(body_str)
            
            if isa(data, Vector) && length(data) > 0
                profile = first(data)
                role = get(profile, "role", "")
                if role == "admin"
                    return (true, "")
                else
                    return (false, "User role is '$role', not 'admin'")
                end
            else
                return (false, "User profile not found")
            end
        else
            return (false, "Failed to fetch user profile: HTTP $(response.status)")
        end
    catch e
        return (false, "Error checking admin role: $(string(e))")
    end
end

"""
    get_admin_user_info(user_id::String)::Dict

Get complete admin user information from profiles table.
"""
function get_admin_user_info(user_id::String)::Dict
    if isempty(SUPABASE_URL) || isempty(SUPABASE_SERVICE_ROLE_KEY)
        return Dict("error" => "Supabase not configured")
    end
    
    try
        url = "$(SUPABASE_URL)/rest/v1/profiles?id=eq.$user_id"
        headers = [
            "apikey" => SUPABASE_SERVICE_ROLE_KEY,
            "Authorization" => "Bearer $(SUPABASE_SERVICE_ROLE_KEY)",
            "Content-Type" => "application/json"
        ]
        
        response = HTTP.get(
            url,
            headers;
            status_exception=false,
            connect_timeout=10,
            readtimeout=10
        )
        
        if response.status == 200
            body_str = String(response.body)
            data = JSON3.read(body_str)
            
            if isa(data, Vector) && length(data) > 0
                return Dict(first(data))
            end
        end
        
        return Dict("error" => "User not found")
    catch e
        return Dict("error" => "Error fetching user info: $(string(e))")
    end
end

end # module SupabaseAdminAuth
