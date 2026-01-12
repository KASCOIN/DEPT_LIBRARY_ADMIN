# Admin service for handling data operations
# SUPABASE STORAGE FOR MATERIALS ONLY - No local filesystem or B2 storage

module AdminService

using JSON3
using UUIDs
using Dates
using ..AppConfig
using ..Models
using ..SupabaseService
using ..SupabaseDbService
using HTTP

function ensure_data_dirs()
    mkpath(AppConfig.DATA_DIR)
    # Metadata only - files are stored in Supabase Storage
end

function save_to_json(filename::String, data::Dict{String,Any})
    filepath = joinpath(AppConfig.DATA_DIR, filename)
    if isfile(filepath)
        raw = read(filepath, String)
        parsed = try
            JSON3.read(raw, Vector{Dict{String,Any}})
        catch
            Vector{Dict{String,Any}}()
        end
        existing = parsed
    else
        existing = Vector{Dict{String,Any}}()
    end
    # upsert by programme + level if present
    found = false
    for (i, item) in enumerate(existing)
        if haskey(item, "programme") && haskey(item, "level") && haskey(data, "programme") && haskey(data, "level")
            if item["programme"] == data["programme"] && item["level"] == data["level"]
                existing[i] = data
                found = true
                break
            end
        end
    end
    if !found
        push!(existing, data)
    end

    open(filepath, "w") do f
        JSON3.write(f, existing)
    end
end

function get_json_data(filename::String)
    filepath = joinpath(AppConfig.DATA_DIR, filename)
    if isfile(filepath)
        raw = read(filepath, String)
        # Prefer returning a Vector of Dicts; fall back to single Dict if file contains one
        try
            return JSON3.read(raw, Vector{Dict{String,Any}})
        catch
            try
                return JSON3.read(raw, Dict{String,Any})
            catch
                return Vector{Dict{String,Any}}()
            end
        end
    else
        return Vector{Dict{String,Any}}()
    end
end

# ==================== SUPABASE STORAGE INTEGRATION ====================

"""
    upload_material_to_supabase(
        file_data::Vector{UInt8},
        filename::String,
        course_code::String,
        programme::String,
        level::String,
        semester::Union{String, Nothing}=nothing,
        category::String="general"
    )::Tuple{Bool, String, Union{String, Nothing}}

Uploads a material file to Supabase Storage and saves metadata locally.

Storage Path: materials/undergraduate/{programme}/level-{level}/{semester}/{course_code}/{category}/{filename}

Process:
1. Validate file type and size
2. Generate storage path
3. Upload to Supabase Storage
4. Save material metadata to JSON
5. Return success/failure with object path

Returns: (success::Bool, message::String, storage_path::Union{String, Nothing})
- (true, "", "materials/undergraduate/...") on success
- (false, error_message, nothing) on failure
"""
function upload_material_to_supabase(
    file_data::Vector{UInt8},
    filename::String,
    course_code::String,
    programme::String,
    level::String,
    semester::Union{String, Nothing}=nothing,
    category::String="general"
)::Tuple{Bool, String, Union{String, Nothing}}
    
    try
        # Validate file type
        is_valid, err_msg = SupabaseService.validate_file_extension(filename)
        if !is_valid
            return (false, err_msg, nothing)
        end
        
        # Validate file size
        is_valid, err_msg = SupabaseService.validate_file_size(file_data, filename)
        if !is_valid
            return (false, err_msg, nothing)
        end
        
        # Normalize semester
        sem = semester !== nothing ? string(semester) : "general-semester"
        if lowercase(sem) ∉ ["first-semester", "second-semester", "general-semester"]
            if lowercase(sem) == "first"
                sem = "first-semester"
            elseif lowercase(sem) == "second"
                sem = "second-semester"
            else
                sem = "general-semester"
            end
        end
        
        # Build storage path: materials/undergraduate/{programme}/level-{level}/{semester}/{course_code}/{category}/{filename}
        storage_path = SupabaseService.build_storage_path(
            programme,
            level,
            sem,
            course_code,
            filename,
            category
        )
        
        # Build Supabase config
        supabase_url = get(ENV, "SUPABASE_URL", "")
        service_role_key = get(ENV, "SUPABASE_SERVICE_ROLE_KEY", "")
        bucket_name = get(ENV, "SUPABASE_BUCKET", "materials")
        
        if isempty(supabase_url) || isempty(service_role_key)
            error_msg = "Supabase credentials not configured. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY."
            @error error_msg
            return (false, error_msg, nothing)
        end
        
        config = SupabaseService.SupabaseConfig(supabase_url, service_role_key, bucket_name)
        
        # Try to delete existing file first (ignore errors if file doesn't exist)
        delete_success, delete_error = SupabaseService.delete_file(config, storage_path)
        if !delete_success
            @warn "Could not delete existing file (may not exist): $delete_error"
        end
        
        # Upload file to Supabase Storage
        success, error_msg, returned_path = SupabaseService.upload_file(config, file_data, storage_path)
        
        if !success
            @error "Supabase upload failed: $error_msg"
            return (false, "Upload failed: $error_msg", nothing)
        end
        
        # Save material metadata to JSON
        try
            material_metadata = Dict{String,Any}(
                "storage_path" => storage_path,
                "filename" => filename,
                "course_code" => course_code,
                "programme" => programme,
                "level" => level,
                "semester" => sem,
                "category" => category,
                "size_bytes" => length(file_data),
                "uploaded_at" => string(now()),
                "status" => "available"
            )
            
            # Append to materials metadata
            save_to_json("materials_metadata.json", material_metadata)
            
            @info "Material uploaded successfully: $storage_path"
            return (true, "", storage_path)
            
        catch e
            # File uploaded successfully but metadata save failed
            # File remains in Supabase, metadata is lost
            @error "Failed to save material metadata for $storage_path: $(string(e))"
            return (false, "File uploaded but metadata save failed: $(string(e))", nothing)
        end
        
    catch e
        error_msg = "Upload error: $(string(e))"
        @error error_msg
        return (false, error_msg, nothing)
    end
end

"""
    delete_material_from_supabase(storage_path::String)::Tuple{Bool, String}

Deletes a material file from Supabase Storage and removes metadata.

Process:
1. Delete from Supabase Storage
2. Remove metadata entry from materials_metadata.json
3. Return success/failure

Returns: (success::Bool, error_message::String)
- (true, "") on successful deletion
- (false, error_message) on failure
"""
function delete_material_from_supabase(storage_path::String)::Tuple{Bool, String}
    
    try
        # Clean up legacy paths - if path starts with "materials/", remove it
        clean_path = storage_path
        if startswith(clean_path, "materials/")
            clean_path = clean_path[length("materials/")+1:end]
            @info "Cleaned legacy path for deletion: $storage_path -> $clean_path"
        end
        
        # Build Supabase config
        supabase_url = get(ENV, "SUPABASE_URL", "")
        service_role_key = get(ENV, "SUPABASE_SERVICE_ROLE_KEY", "")
        bucket_name = get(ENV, "SUPABASE_BUCKET", "materials")
        
        if isempty(supabase_url) || isempty(service_role_key)
            error_msg = "Supabase credentials not configured"
            @error error_msg
            return (false, error_msg)
        end
        
        config = SupabaseService.SupabaseConfig(supabase_url, service_role_key, bucket_name)
        
        # Delete from Supabase Storage using clean path
        success, error_msg = SupabaseService.delete_file(config, clean_path)
        
        if !success
            # If file doesn't exist, treat as success - it's gone anyway
            if contains(error_msg, "404") || contains(error_msg, "not found")
                @info "File not found in Supabase (already deleted): $clean_path"
            else
                @warn "Supabase delete failed: $error_msg"
                return (false, error_msg)
            end
        end
        
        # Delete metadata entry from Supabase database
        try
            @info "Attempting to delete metadata for storage_path: $clean_path"
            
            # Use HTTP.jl and URL-encode the storage_path for PostgREST
            db_config = SupabaseDbService.DB_CONFIG
            if !isnothing(db_config)
                encoded_path = HTTP.URIs.escapeuri(clean_path)
                delete_url = "$(db_config.url)/rest/v1/materials?storage_path=eq.$encoded_path"
                headers = [
                    "apikey" => db_config.service_role_key,
                    "Authorization" => "Bearer $(db_config.service_role_key)",
                    "Content-Type" => "application/json"
                ]
                @info "Delete URL: $delete_url"
                response = HTTP.delete(
                    delete_url,
                    headers;
                    status_exception=false,
                    connect_timeout=10,
                    readtimeout=10
                )
                @info "Metadata delete response - HTTP: $(response.status)"
                if response.status >= 200 && response.status < 300
                    @info "✓ Metadata deleted from database for: $clean_path"
                elseif response.status == 404
                    @info "Metadata entry not found (already deleted): $clean_path"
                else
                    @warn "Database delete returned HTTP $(response.status): $(String(response.body))"
                end
            else
                @warn "Database config not available for metadata deletion"
            end
            
        catch e
            @warn "Failed to remove material metadata from database: $(string(e))"
            # File deleted from Supabase storage but metadata removal failed
            # This is acceptable - the file is gone from storage
        end
        
        @info "Material deleted successfully: $clean_path"
        return (true, "")
        
    catch e
        error_msg = "Delete error: $(string(e))"
        @error error_msg
        return (false, error_msg)
    end
end

"""
    get_download_url(storage_path::String, expires_in::Int=3600)::Tuple{Bool, String}

Generates a signed download URL for a material in Supabase Storage.

Returns: (success::Bool, url_or_error_message::String)
"""
function get_download_url(storage_path::String, expires_in::Int=3600)::Tuple{Bool, String}
    
    try
        supabase_url = get(ENV, "SUPABASE_URL", "")
        service_role_key = get(ENV, "SUPABASE_SERVICE_ROLE_KEY", "")
        bucket_name = get(ENV, "SUPABASE_BUCKET", "materials")
        
        if isempty(supabase_url) || isempty(service_role_key)
            return (false, "Supabase credentials not configured")
        end
        
        config = SupabaseService.SupabaseConfig(supabase_url, service_role_key, bucket_name)
        return SupabaseService.generate_signed_url(config, storage_path, expires_in)
        
    catch e
        return (false, "Error generating URL: $(string(e))")
    end
end

end
