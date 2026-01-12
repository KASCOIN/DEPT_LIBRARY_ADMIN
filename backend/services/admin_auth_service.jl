# Admin Authentication Service
# Manages admin login, sessions, and authentication

module AdminAuthService

using SHA
using UUIDs
using Dates
using JSON3

# Export public API
export login, logout, verify_session, get_session_info, cleanup_expired_sessions, hash_password

# In-memory session store (in production, use a database)
const ADMIN_SESSIONS = Dict{String, Dict{String, Any}}()

# Default admin credentials (should be changed in production)
const ADMIN_USERNAME = get(ENV, "ADMIN_USERNAME", "admin")
const ADMIN_PASSWORD_HASH = get(ENV, "ADMIN_PASSWORD_HASH", "")

"""
    hash_password(password::String)::String

Generate SHA256 hash of password.
"""
function hash_password(password::String)::String
    return bytes2hex(sha256(password))
end

"""
    verify_password(password::String, hash::String)::Bool

Verify password against hash.
"""
function verify_password(password::String, hash::String)::Bool
    return hash_password(password) == hash
end

"""
    set_default_admin_password()

Generate hash for default password "admin" and output it.
Call this once to set up the initial admin password.
"""
function set_default_admin_password()
    default_pass = "admin"
    hash = hash_password(default_pass)
    println("Default admin password hash: $hash")
    println("Set this in your .env file as: ADMIN_PASSWORD_HASH=$hash")
    return hash
end

"""
    login(username::String, password::String)::Tuple{Bool, String}

Authenticate admin user.

Returns: (success::Bool, session_token::String or error_message::String)
"""
function login(username::String, password::String)::Tuple{Bool, String}
    
    # Validate inputs
    if isempty(username) || isempty(password)
        return (false, "Username and password are required")
    end
    
    # Check credentials
    if username != ADMIN_USERNAME
        return (false, "Invalid credentials")
    end
    
    # If no password hash set, use default
    password_hash = if isempty(ADMIN_PASSWORD_HASH)
        hash_password("admin")
    else
        ADMIN_PASSWORD_HASH
    end
    
    if !verify_password(password, password_hash)
        return (false, "Invalid credentials")
    end
    
    # Generate session token
    session_token = string(uuid4())
    
    # Store session
    ADMIN_SESSIONS[session_token] = Dict{String, Any}(
        "username" => username,
        "created_at" => now(),
        "last_activity" => now(),
        "expires_at" => now() + Hour(24)  # 24 hour session
    )
    
    return (true, session_token)
end

"""
    verify_session(session_token::String)::Tuple{Bool, String}

Verify if session token is valid.

Returns: (valid::Bool, error_message::String or "")
"""
function verify_session(session_token::String)::Tuple{Bool, String}
    
    if isempty(session_token)
        return (false, "No session token provided")
    end
    
    if !haskey(ADMIN_SESSIONS, session_token)
        return (false, "Invalid session token")
    end
    
    session = ADMIN_SESSIONS[session_token]
    
    # Check expiration
    if now() > session["expires_at"]
        delete!(ADMIN_SESSIONS, session_token)
        return (false, "Session expired")
    end
    
    # Update last activity
    session["last_activity"] = now()
    
    return (true, "")
end

"""
    logout(session_token::String)::Bool

Invalidate a session token.
"""
function logout(session_token::String)::Bool
    if haskey(ADMIN_SESSIONS, session_token)
        delete!(ADMIN_SESSIONS, session_token)
        return true
    end
    return false
end

"""
    get_session_info(session_token::String)::Union{Dict, Nothing}

Get session information for a valid token.
Returns the session dict if found and valid, otherwise nothing.
"""
function get_session_info(session_token::String)::Union{Dict, Nothing}
    if !haskey(ADMIN_SESSIONS, session_token)
        return nothing
    end
    
    session = ADMIN_SESSIONS[session_token]
    
    # Check expiration
    if now() > session["expires_at"]
        delete!(ADMIN_SESSIONS, session_token)
        return nothing
    end
    
    return session
end

"""
    cleanup_expired_sessions()

Remove expired sessions from memory.
"""
function cleanup_expired_sessions()
    expired_tokens = []
    for (token, session) in ADMIN_SESSIONS
        if now() > session["expires_at"]
            push!(expired_tokens, token)
        end
    end
    
    for token in expired_tokens
        delete!(ADMIN_SESSIONS, token)
    end
    
    return length(expired_tokens)
end

end  # module AdminAuthService
