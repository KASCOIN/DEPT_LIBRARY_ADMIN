# Admin service for handling data operations
# SUPABASE STORAGE ONLY - No local filesystem or B2 storage

module AdminService

using JSON3
using UUIDs
using Dates
using ..AppConfig
using ..Models
using ..SupabaseService
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
        
        # Delete from Supabase Storage
        success, error_msg = SupabaseService.delete_file(config, storage_path)
        
        if !success
            # If file doesn't exist, treat as success - it's gone anyway
            if contains(error_msg, "404") || contains(error_msg, "not found")
                @info "File not found in Supabase (already deleted): $storage_path"
            else
                @warn "Supabase delete failed: $error_msg"
                return (false, error_msg)
            end
        end
        
        # Remove metadata entry
        try
            filepath = joinpath(AppConfig.DATA_DIR, "materials_metadata.json")
            if isfile(filepath)
                raw = read(filepath, String)
                parsed = try
                    JSON3.read(raw, Vector{Dict{String,Any}})
                catch
                    Vector{Dict{String,Any}}()
                end
                
                # Filter out the deleted material
                updated = filter(item -> get(item, "storage_path", "") != storage_path, parsed)
                
                # Write back updated metadata
                open(filepath, "w") do f
                    JSON3.write(f, updated)
                end
            end
            
            @info "Material deleted successfully: $storage_path"
            return (true, "")
            
        catch e
            @warn "Failed to remove material metadata: $(string(e))"
            # File deleted from Supabase but metadata removal failed
            # This is acceptable - the file is gone from storage
            return (true, "")
        end
        
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

# ==================== SUPABASE STORAGE FOR COURSES ====================

"""
    upload_courses_to_supabase(courses_data::Vector{Dict{String,Any}})::Tuple{Bool, String, Union{String, Nothing}}

Uploads courses data to Supabase Storage as JSON.

Storage Path: courses/{programme}/level-{level}/courses.json

Process:
1. For each programme/level combo in courses_data, upload as a separate JSON file
2. Store in courses bucket
3. Return success/failure

Returns: (success::Bool, message::String, storage_path::Union{String, Nothing})
"""
function upload_courses_to_supabase(courses_data::Vector{Dict{String,Any}})::Tuple{Bool, String, Union{String, Nothing}}
    try
        supabase_url = get(ENV, "SUPABASE_URL", "")
        service_role_key = get(ENV, "SUPABASE_SERVICE_ROLE_KEY", "")
        courses_bucket = get(ENV, "SUPABASE_COURSES_BUCKET", "courses")
        
        println("[DEBUG] upload_courses_to_supabase called")
        println("[DEBUG] Supabase URL: $(isempty(supabase_url) ? "EMPTY" : "SET")")
        println("[DEBUG] Service role key: $(isempty(service_role_key) ? "EMPTY" : "SET")")
        println("[DEBUG] Courses bucket: $courses_bucket")
        
        if isempty(supabase_url) || isempty(service_role_key)
            return (false, "Supabase credentials not configured", nothing)
        end
        
        # Upload each programme/level combination
        for entry in courses_data
            if !haskey(entry, "programme") || !haskey(entry, "level")
                continue
            end
            
            programme = entry["programme"]
            level = entry["level"]
            
            println("[DEBUG] Uploading courses for: $programme Level $level")
            
            # Build storage path: courses/{programme}/level-{level}/courses.json
            storage_path = "courses/$(programme)/level-$(level)/courses.json"
            
            # Convert entry to JSON
            json_data = JSON3.write(entry)
            file_data = Vector{UInt8}(json_data)
            
            println("[DEBUG] Storage path: $storage_path, file size: $(length(file_data)) bytes")
            
            # Upload to Supabase
            config = SupabaseService.SupabaseConfig(supabase_url, service_role_key, courses_bucket)
            success, msg = SupabaseService.upload_file(config, storage_path, file_data, "application/json")
            
            println("[DEBUG] Upload result: success=$success, msg=$msg")
            
            if !success
                return (false, "Failed to upload courses for $(programme) Level $(level): $(msg)", nothing)
            end
        end
        
        return (true, "Courses uploaded successfully", "courses/")
    catch e
        println("[ERROR] Exception in upload_courses_to_supabase: $(string(e))")
        return (false, "Error uploading courses: $(string(e))", nothing)
    end
end

"""
    get_courses_from_supabase(programme::Union{String, SubString, Nothing}=nothing, level::Union{String, SubString, Nothing}=nothing)::Tuple{Bool, Vector{Dict{String,Any}}, String}

Retrieves courses from Supabase Storage, with fallback to local JSON.

Process:
1. If programme and level are provided, try to download from Supabase first
2. Fall back to local JSON if Supabase is not available or file doesn't exist
3. If no params, read from local JSON and sync to Supabase later

Returns: (success::Bool, courses_data::Vector{Dict{String,Any}}, message::String)
"""
function get_courses_from_supabase(programme::Union{String, SubString, Nothing}=nothing, level::Union{String, SubString, Nothing}=nothing)::Tuple{Bool, Vector{Dict{String,Any}}, String}
    try
        supabase_url = get(ENV, "SUPABASE_URL", "")
        service_role_key = get(ENV, "SUPABASE_SERVICE_ROLE_KEY", "")
        courses_bucket = get(ENV, "SUPABASE_COURSES_BUCKET", "courses")
        
        # Try Supabase first if we have programme and level
        if !isempty(supabase_url) && !isempty(service_role_key) && programme !== nothing && level !== nothing
            try
                # Normalize programme/level strings to handle SubString types
                prog_str = string(programme)
                level_str = string(level)
                storage_path = "courses/$(prog_str)/level-$(level_str)/courses.json"
                
                config = SupabaseService.SupabaseConfig(supabase_url, service_role_key, courses_bucket)
                success, file_data, msg = SupabaseService.download_file(config, storage_path)
                
                if success && !isempty(file_data)
                    try
                        json_str = String(file_data)
                        course_entry = JSON3.read(json_str, Dict{String,Any})
                        return (true, [course_entry], "")
                    catch e
                        @warn "Failed to parse Supabase courses JSON: $(string(e))"
                        # Fall through to local JSON
                    end
                end
            catch e
                @warn "Failed to fetch from Supabase: $(string(e))"
                # Fall through to local JSON
            end
        end
        
        # Fall back to local JSON
        all_courses = get_json_data("courses.json")
        return (true, all_courses, "")
        
    catch e
        return (false, Vector{Dict{String,Any}}(), "Error retrieving courses: $(string(e))")
    end
end

"""
    delete_courses_from_supabase(programme::String, level::String)::Tuple{Bool, String}

Deletes courses from Supabase Storage for a specific programme/level.

Storage Path: courses/{programme}/level-{level}/courses.json

Returns: (success::Bool, message::String)
"""
function delete_courses_from_supabase(programme::String, level::String)::Tuple{Bool, String}
    try
        supabase_url = get(ENV, "SUPABASE_URL", "")
        service_role_key = get(ENV, "SUPABASE_SERVICE_ROLE_KEY", "")
        courses_bucket = get(ENV, "SUPABASE_COURSES_BUCKET", "courses")
        
        if isempty(supabase_url) || isempty(service_role_key)
            return (false, "Supabase credentials not configured")
        end
        
        storage_path = "courses/$(programme)/level-$(level)/courses.json"
        config = SupabaseService.SupabaseConfig(supabase_url, service_role_key, courses_bucket)
        
        return SupabaseService.delete_file(config, storage_path)
    catch e
        return (false, "Error deleting courses: $(string(e))")
    end
end

end