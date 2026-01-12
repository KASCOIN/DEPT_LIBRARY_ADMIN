# Supabase Storage Service
# Production-quality backend service for interacting with Supabase Storage REST API

module SupabaseService

using HTTP
using JSON3
using Base64
using Dates
using ..AppConfig

"""
    SupabaseConfig

Configuration for Supabase Storage API access.
"""
struct SupabaseConfig
    url::String
    service_role_key::String
    bucket_name::String
end

"""
    validate_file_extension(filename::String)::Tuple{Bool, String}

Validates that the file has an allowed extension.
Returns (is_valid, error_message)

Allowed types: PDF, PPT, PPTX, DOC, DOCX, MP4
"""
function validate_file_extension(filename::String)::Tuple{Bool, String}
    allowed_extensions = ["pdf", "ppt", "pptx", "doc", "docx", "mp4"]
    
    if !contains(filename, ".")
        return (false, "File must have an extension")
    end
    
    ext = lowercase(split(filename, ".")[end])
    
    if ext ∉ allowed_extensions
        return (false, "File type .$ext not allowed. Allowed: $(join(allowed_extensions, ", "))")
    end
    
    return (true, "")
end

"""
    validate_file_size(file_data::Vector{UInt8}, filename::String)::Tuple{Bool, String}

Validates file size based on type.
- Documents (PDF, DOC*, PPT*): ≤ 50 MB
- Videos (MP4): ≤ 500 MB

Returns (is_valid, error_message)
"""
function validate_file_size(file_data::Vector{UInt8}, filename::String)::Tuple{Bool, String}
    size_bytes = length(file_data)
    ext = lowercase(split(filename, ".")[end])
    
    doc_limit = 50 * 1024 * 1024  # 50 MB
    video_limit = 500 * 1024 * 1024  # 500 MB
    
    limit = ext == "mp4" ? video_limit : doc_limit
    limit_name = ext == "mp4" ? "500 MB" : "50 MB"
    
    if size_bytes > limit
        size_mb = round(size_bytes / 1024 / 1024; digits=2)
        return (false, "File size ($size_mb MB) exceeds $limit_name limit for .$ext files")
    end
    
    return (true, "")
end

"""
    build_storage_path(
        programme::String,
        level::String,
        semester::String,
        course_code::String,
        filename::String,
        category::String="general"
    )::String

Builds the standardized Supabase Storage path.

Format: materials/undergraduate/{programme}/level-{level}/{semester}/{course_code}/{category}/{filename}

Example: materials/undergraduate/meteorology/level-300/first-semester/MTC301/lectures/lecture-01.pdf
"""
function build_storage_path(
    programme::String,
    level::String,
    semester::String,
    course_code::String,
    filename::String,
    category::String="general"
)::String
    
    # Normalize inputs
    prog_clean = lowercase(strip(programme))
    level_clean = strip(level)
    sem_clean = lowercase(strip(semester))
    course_clean = uppercase(strip(course_code))
    cat_clean = lowercase(strip(category))
    
    # Ensure semester is normalized
    if !in(sem_clean, ["first-semester", "second-semester", "first", "second"])
        sem_clean = "general-semester"
    else
        sem_clean = in(sem_clean, ["first", "second"]) ? sem_clean * "-semester" : sem_clean
    end
    
    # Build path WITHOUT bucket name prefix - path goes INSIDE the bucket
    # The bucket name is "materials", so this path is inside that bucket
    # Format: undergraduate/{programme}/level-{level}/{semester}/{course_code}/{category}/{filename}
    path = "undergraduate/$prog_clean/level-$level_clean/$sem_clean/$course_clean/$cat_clean/$filename"
    return path
end

"""
    upload_file(
        config::SupabaseConfig,
        file_data::Vector{UInt8},
        object_path::String
    )::Tuple{Bool, String, Union{String, Nothing}}

Uploads a file to Supabase Storage using REST API.

Returns: (success::Bool, error_message::String, object_path::String)
"""
function upload_file(
    config::SupabaseConfig,
    file_data::Vector{UInt8},
    object_path::String
)::Tuple{Bool, String, Union{String, Nothing}}
    
    try
        # Build upload URL
        upload_url = "$(config.url)/storage/v1/object/$(config.bucket_name)/$object_path"
        
        # Prepare headers with Service Role Key
        # The service_role_key is not a JWT, it should be sent as apikey header
        headers = [
            "apikey" => config.service_role_key,
            "Authorization" => "Bearer $(config.service_role_key)",
            "Content-Type" => "application/octet-stream"
        ]
        
        # Upload file
        response = HTTP.post(
            upload_url,
            headers,
            file_data;
            retry=false,
            status_exception=false,
            connect_timeout=30,
            readtimeout=120
        )
        
        # Check response status
        if response.status == 200
            @info "File uploaded successfully to Supabase: $object_path"
            return (true, "", object_path)
        elseif response.status == 401
            error_msg = "Supabase authentication failed. Check SUPABASE_SERVICE_ROLE_KEY."
            @error error_msg
            return (false, error_msg, nothing)
        elseif response.status == 400
            body_str = String(response.body)
            error_msg = try
                resp_json = JSON3.read(body_str, Dict)
                get(resp_json, "message", "Bad request from Supabase")
            catch
                "Invalid request to Supabase Storage"
            end
            @error "Upload failed: $error_msg"
            return (false, error_msg, nothing)
        else
            error_msg = "Supabase returned status $(response.status)"
            @error error_msg
            return (false, error_msg, nothing)
        end
        
    catch e
        error_msg = "Upload failed: $(string(e))"
        @error error_msg
        return (false, error_msg, nothing)
    end
end

"""
    delete_file(
        config::SupabaseConfig,
        object_path::String
    )::Tuple{Bool, String}

Deletes a file from Supabase Storage.

Returns: (success::Bool, error_message::String)
"""
function delete_file(
    config::SupabaseConfig,
    object_path::String
)::Tuple{Bool, String}
    
    try
        # The object_path comes from storage as: materials/undergraduate/program/level-300/semester/COURSE/category/filename
        # We need to use it as-is without the bucket name in the URL
        
        path_to_delete = object_path
        
        # If path starts with bucket name, remove it (e.g., "materials/..." -> keep as is)
        # The path is already relative, so we use it directly in the URL
        
        @info "Deleting file from Supabase: path=$path_to_delete, bucket=$(config.bucket_name)"
        
        # Build delete URL - need to URL encode the path for spaces and special chars
        # Format: https://project.supabase.co/storage/v1/object/bucket_name/path/to/file
        delete_url = "$(config.url)/storage/v1/object/$(config.bucket_name)/$path_to_delete"
        
        # URL encode the entire URL to handle spaces and special characters
        encoded_url = replace(delete_url, " " => "%20")
        
        @info "Delete URL: $encoded_url"
        
        # Use curl for deletion with proper URL encoding
        cmd = `curl -s -w "\n%{http_code}" -X DELETE -H "Authorization: Bearer $(config.service_role_key)" "$encoded_url"`
        
        result = read(cmd, String)
        lines = strip(result) |> x -> split(x, '\n')
        
        # Last line is the HTTP code
        http_code = parse(Int, lines[end])
        response_body = join(lines[1:end-1], '\n')
        
        @info "Supabase delete response - HTTP: $http_code"
        if !isempty(response_body)
            @info "Response: $response_body"
        end
        
        # Check response status
        if http_code == 200 || http_code == 204
            @info "✓ File deleted successfully: $object_path"
            return (true, "")
        elseif http_code == 401
            error_msg = "Supabase authentication failed (401)"
            @error error_msg
            return (false, error_msg)
        elseif http_code == 404
            @warn "File not found in Supabase (404): $object_path"
            return (true, "")  # Treat as success - file is gone
        else
            error_msg = "Supabase delete returned HTTP $http_code: $response_body"
            @error error_msg
            return (false, error_msg)
        end
        
    catch e
        error_msg = "Delete failed: $(string(e))"
        @error error_msg
        return (false, error_msg)
    end
end

"""
    generate_signed_url(
        config::SupabaseConfig,
        object_path::String,
        expires_in::Int=3600
    )::Tuple{Bool, String}

Generates a signed download URL for a file in Supabase Storage.

Returns: (success::Bool, signed_url_or_error_message::String)
"""
function generate_signed_url(
    config::SupabaseConfig,
    object_path::String,
    expires_in::Int=3600
)::Tuple{Bool, String}
    
    try
        # Get project ID from environment
        project_id = get(ENV, "SUPABASE_PROJECT_ID", "")
        if isempty(project_id)
            @error "SUPABASE_PROJECT_ID not configured"
            return (false, "Configuration error")
        end
        bucket = config.bucket_name
        
        # 1. Clean the path - remove "materials/" prefix if present (legacy format)
        clean_path = object_path
        if startswith(clean_path, "materials/")
            clean_path = clean_path[length("materials/")+1:end]
        end
        
        # 2. Build public URL directly (no signing needed for public bucket)
        # Format: https://PROJECT_ID.supabase.co/storage/v1/object/public/BUCKET/PATH
        public_url = "https://$(project_id).supabase.co/storage/v1/object/public/$(bucket)/$(clean_path)"
        
        @info "Generated public URL: $public_url"
        
        return (true, public_url)
        
    catch e
        @error "Error generating signed URL: $e"
        return (false, "Error: $(string(e))")
    end
end

end  # module SupabaseService
