module StudentController

using Genie.Router
using Genie.Renderer.Json
using Genie.Requests
using HTTP
using ..AppConfig
using ..SupabaseDbService
using ..ActiveStudentService
using Dates
using JSON3

# Import auth middleware
include("../services/auth_middleware.jl")

# Helper function to return JSON with CORS headers
function json_cors(data::Any, status::Int=200)
    return HTTP.Response(
        status,
        [
            "Content-Type" => "application/json; charset=utf-8",
            "Access-Control-Allow-Origin" => "*",
            "Access-Control-Allow-Methods" => "GET, POST, OPTIONS, PUT, DELETE",
            "Access-Control-Allow-Headers" => "Content-Type, Authorization",
            "Access-Control-Max-Age" => "86400"
        ],
        JSON3.write(data)
    )
end

"""
    require_student_auth()

Middleware to require valid JWT token for protected student endpoints.
Returns HTTP 401 if token is invalid or missing.
Extracts user_id from JWT token.
"""
function require_student_auth()
    return function(handler)
        return function(req)
            headers = Dict(req.headers)
            auth_result = verify_auth_token(headers)
            
            if !auth_result.valid
                return json_cors(
                    Dict(
                        "success" => false,
                        "error" => auth_result.error
                    ),
                    401
                )
            end
            
            # Store auth info in request context
            req.user_id = auth_result.user_id
            req.user_role = auth_result.role
            
            return handler(req)
        end
    end
end

# Helper to convert JSON payloads to native Dict
function _to_native_dict(x::Dict)
    try
        return JSON3.read(JSON3.write(x), Dict{String,Any})
    catch
        return Dict{String,Any}()
    end
end

function _to_native_dict(x::Nothing)
    return Dict{String,Any}()
end

function _to_native_dict(x)
    try
        return JSON3.read(JSON3.write(x), Dict{String,Any})
    catch
        return Dict{String,Any}()
    end
end

function get_student_payload()
    raw = jsonpayload()
    pd = _to_native_dict(raw)
    isempty(pd) && error("No JSON payload provided")
    return pd
end

"""
    login_student() - DEPRECATED

Authentication is now handled by Supabase Auth directly.
Frontend calls supabaseClient.auth.signInWithPassword() which returns JWT token.
Backend validates JWT token in Authorization header for protected endpoints.

This endpoint is kept for backward compatibility but returns 401.
"""
function login_student()
    return json_cors(
        Dict(
            "success" => false,
            "error" => "Login is now handled by Supabase Auth. Use supabaseClient.auth.signInWithPassword() on the frontend and send JWT in Authorization header."
        ),
        401
    )
end

"""
    get_student_profile()

Retrieve student's profile from database.
Requires valid JWT token in Authorization header.
Returns the authenticated user's profile.
"""
function get_student_profile()
    try
        # Verify JWT token
        headers = Dict(Genie.Requests.request().headers)
        auth_result = verify_auth_token(headers)
        
        if !auth_result.valid
            @warn "Invalid token in get_student_profile: $(auth_result.error)"
            return json_cors(
                Dict(
                    "success" => false,
                    "error" => auth_result.error
                ),
                401
            )
        end
        
        user_id = auth_result.user_id
        @info "Fetching profile for user: $user_id"
        
        # Update last_seen timestamp for active student tracking
        success_update, error_update = ActiveStudentService.update_last_seen(user_id)
        if !success_update
            @debug "Failed to update last_seen: $error_update"
        end
        
        # Query the profiles table for this user using Supabase DB service
        success, error, profile = SupabaseDbService.get_student_profile(user_id)
        
        if !success
            @warn "Failed to fetch profile for user $user_id: $error"
            return json_cors(
                Dict(
                    "success" => false,
                    "error" => error
                ),
                404
            )
        end
        
        @info "Successfully fetched profile for user: $user_id"
        
        # Return profile (no sensitive data to remove since auth is separate)
        profile_safe = Dict(
            "id" => get(profile, "id", ""),
            "email" => get(profile, "email", ""),
            "full_name" => get(profile, "full_name", ""),
            "matric_no" => get(profile, "matric_no", ""),
            "programme" => get(profile, "programme", ""),
            "level" => get(profile, "level", ""),
            "phone" => get(profile, "phone", ""),
            "role" => get(profile, "role", "student")
        )
        
        return json_cors(Dict(
            "success" => true,
            "profile" => profile_safe
        ))
    catch e
        @error "Error fetching student profile: $e"
        @error "Stack trace: $(stacktrace(catch_backtrace()))"
        return json_cors(
            Dict(
                "success" => false,
                "error" => "Failed to fetch profile: $(string(e))"
            ),
            500
        )
    end
end

"""
    get_material_view_url()

Generate a signed URL for viewing a PDF material without exposing Supabase credentials.

Requires valid JWT token in Authorization header.
Accepts POST request with storage_path in JSON body.
Returns a short-lived signed URL (15 minutes) that students can use to view the PDF.

Security:
- Only authenticated students can request URLs
- Service role key never exposed to frontend
- URL expires after 15 minutes
- Only allows reading files from the materials bucket
"""
function get_material_view_url()
    try
        @info "get_material_view_url called"
        
        # Verify JWT token first - use fully qualified name due to namespace conflict
        req = Genie.Requests.request()
        headers = Dict(req.headers)
        auth_result = verify_auth_token(headers)
        
        if !auth_result.valid
            return json_cors(
                Dict(
                    "success" => false,
                    "error" => auth_result.error
                ),
                401
            )
        end
        
        # Update last_seen timestamp for active student tracking
        success_update, error_update = ActiveStudentService.update_last_seen(auth_result.user_id)
        if !success_update
            @debug "Failed to update last_seen: $error_update"
        end
        
        # Get payload
        payload = get_student_payload()
        @info "Payload received: $payload"
        
        # Extract storage_path
        storage_path = get(payload, "storage_path", "")
        
        if isempty(storage_path)
            return json_cors(
                Dict(
                    "success" => false,
                    "error" => "storage_path is required",
                    "message" => "No storage path provided"
                ),
                400
            )
        end
        
        @info "View URL requested for: $storage_path (user: $(auth_result.user_id))"
        
        # Validate that the path is trying to access a PDF or PPTX
        if !(endswith(lowercase(storage_path), ".pdf") || endswith(lowercase(storage_path), ".pptx"))
            return json_cors(
                Dict(
                    "success" => false,
                    "error" => "invalid_file_type",
                    "message" => "Only PDF and PPTX files can be viewed"
                ),
                400
            )
        end
        
        # Generate signed URL with proper encoding
        try
            # Get project ID from SUPABASE_URL (format: https://PROJECT_ID.supabase.co)
            supabase_url = get(ENV, "SUPABASE_URL", "")
            if isempty(supabase_url)
                @error "SUPABASE_URL not configured"
                return json_cors(Dict("success" => false, "error" => "Configuration error"), 500)
            end
            
            # Extract project ID from URL
            # URL format: https://PROJECT_ID.supabase.co
            project_id = ""
            try
                # Parse URL and extract subdomain
                if contains(supabase_url, ".supabase.co")
                    # Remove https:// and extract the subdomain
                    url_clean = replace(supabase_url, "https://" => "")
                    url_clean = replace(url_clean, "http://" => "")
                    project_id = split(url_clean, ".")[1]
                end
            catch ex
                @error "Failed to parse project ID from SUPABASE_URL: $supabase_url, Error: $ex"
                return json_cors(Dict("success" => false, "error" => "Configuration error"), 500)
            end
            
            if isempty(project_id)
                @error "Could not extract project ID from SUPABASE_URL: $supabase_url"
                return json_cors(Dict("success" => false, "error" => "Configuration error"), 500)
            end
            
            bucket = "materials"
            
            # 1. Clean the path - remove "materials/" prefix if present (legacy format)
            clean_path = storage_path
            if startswith(clean_path, "materials/")
                clean_path = clean_path[length("materials/")+1:end]
            end
            
            # 2. Build public URL directly (no signing needed for public bucket)
            # Format: https://PROJECT_ID.supabase.co/storage/v1/object/public/BUCKET/PATH
            public_url = "https://$(project_id).supabase.co/storage/v1/object/public/$(bucket)/$(clean_path)"
            
            @info "Generated public URL for: $clean_path"
            
            return json_cors(
                Dict(
                    "success" => true,
                    "signedURL" => public_url,
                    "storage_path" => storage_path
                )
            )
            
        catch e
            @error "Error generating signed URL: $e"
            return json_cors(
                Dict(
                    "success" => false,
                    "error" => "internal_error",
                    "message" => "Failed to generate signed URL"
                ),
                500
            )
        end
        
    catch e
        @error "Error in get_material_view_url: $e" exception=(e, catch_backtrace())
        return json_cors(
            Dict(
                "success" => false,
                "error" => "internal_error",
                "message" => "Internal server error: $(string(e))"
            ),
            500
        )
    end
end

end  # module StudentController
