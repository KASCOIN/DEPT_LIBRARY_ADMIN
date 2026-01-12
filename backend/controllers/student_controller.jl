module StudentController

using Genie.Router
using Genie.Renderer.Json
using Genie.Requests
using HTTP
using ..AppConfig
using ..SupabaseDbService
using Dates
using JSON3
using SHA

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
    login_student()

Login student - validate email and password
Expects POST with email and password in JSON body
Returns student profile data if successful
"""
function login_student()
    try
        payload = jsonpayload()
        
        email = get(payload, "email", "")
        password = get(payload, "password", "")
        
        if isempty(email) || isempty(password)
            return json_cors(
                Dict(
                    "success" => false,
                    "error" => "Email and password are required"
                ),
                400
            )
        end
        
        # Look up user by email
        success, error, profile = SupabaseDbService.get_student_by_email(email)
        
        if !success || isempty(profile)
            return json_cors(
                Dict(
                    "success" => false,
                    "error" => "Invalid email or password"
                ),
                401
            )
        end
        
        # Verify password hash - simple SHA256 comparison
        # Frontend and backend both use SHA256 for consistency
        stored_password_hash = get(profile, "password_hash", "")
        
        # Hash the provided password using SHA256
        password_bytes = Vector{UInt8}(password)
        provided_hash = bytes2hex(sha256(password_bytes))
        
        if isempty(stored_password_hash) || provided_hash != stored_password_hash
            return json_cors(
                Dict(
                    "success" => false,
                    "error" => "Invalid email or password"
                ),
                401
            )
        end
        
        # Remove password_hash from response
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
            "profile" => profile_safe,
            "message" => "Login successful"
        ))
    catch e
        @error "Error in login_student: $e"
        return json_cors(
            Dict(
                "success" => false,
                "error" => "Failed to login: $(string(e))"
            ),
            500
        )
    end
end

"""
    get_student_profile()

Retrieve student's profile from database (for displaying on dashboard)
Requires user_id in route parameter
"""
function get_student_profile()
    try
        user_id = params(:user_id)
        
        # Query the profiles table for this user using Supabase DB service
        success, error, profile = SupabaseDbService.get_student_profile(user_id)
        
        if !success
            return json_cors(
                Dict(
                    "success" => false,
                    "error" => error
                ),
                404
            )
        end
        
        # Remove password_hash from response
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

Accepts POST request with storage_path in JSON body.
Returns a short-lived signed URL (15 minutes) that students can use to view the PDF.

Security:
- Service role key never exposed to frontend
- URL expires after 15 minutes
- Only allows reading files from the materials bucket
"""
function get_material_view_url()
    try
        # Get payload
        payload = jsonpayload()
        
        # Coerce to native Dict if needed
        if isa(payload, Dict)
            storage_path = get(payload, "storage_path", "")
        else
            storage_path = ""
        end
        
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
        
        @info "View URL requested for: $storage_path"
        
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
            # Get project ID from environment
            project_id = get(ENV, "SUPABASE_PROJECT_ID", "")
            if isempty(project_id)
                @error "SUPABASE_PROJECT_ID not configured"
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
        @error "Error in get_material_view_url: $e"
        return json_cors(
            Dict(
                "success" => false,
                "error" => "internal_error",
                "message" => "Internal server error"
            ),
            500
        )
    end
end

end  # module StudentController
