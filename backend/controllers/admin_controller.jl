
module AdminController
using Genie.Router
using Genie.Renderer.Json
using Genie.Requests
using HTTP
using ..AdminService
using ..AppConfig
using ..SupabaseDbService
using ..AuthMiddleware
using ..ActiveStudentService
using Dates
using JSON3
import Base64: base64decode

# Middleware to check admin auth for protected routes
function check_admin_auth()
    req = Genie.Requests.request()
    headers = Dict(req.headers)
    
    auth_header = get(headers, "Authorization", "")
    
    token = if startswith(auth_header, "Bearer ")
        auth_header[8:end]
    else
        ""
    end
    
    valid, _ = AuthMiddleware.AdminAuthService.verify_session(token)
    
    if !valid
        throw(HTTP.ExceptionRequest.HTTPException(401, "Admin authentication required"))
    end
end

export delete_course

"""
    delete_course()

Deletes a course from Supabase by programme, level, semester, and course_code.
Expects JSON body:
{
  "programme": "...",
  "level": "...",
  "semester": "...",
  "course_code": "..."
}
"""
function delete_course()
    payload = Dict{String, Any}()
    try
        req = Genie.Requests.request()
        body = String(req.body)
        if !isempty(body)
            payload = JSON3.read(body, Dict{String, Any})
        end
    catch e
        @warn "Error reading DELETE request body: $(string(e))"
        payload = Dict{String, Any}()
    end

    id = get(payload, "id", "")
    if isempty(id)
        return json_cors(Dict("success" => false, "message" => "id is required for deletion"), 400)
    end
    # Call SupabaseDbService to delete the course by id
    success, msg = SupabaseDbService.delete_course_by_id(id)
    if success
        return json_cors(Dict("success" => true, "message" => "Course deleted successfully"))
    else
        return json_cors(Dict("success" => false, "message" => msg), 400)
    end
end

export delete_course, delete_news, post_news, download_material, post_materials, post_timetable, post_courses, update_courses, delete_materials, get_news, get_materials, get_timetable, admin_get_courses, delete_timetable_slot, delete_timetable_day, admin_get_news, admin_get_materials, admin_get_timetable, get_active_students

using Genie.Router
using Genie.Renderer.Json
using Genie.Requests
using HTTP
using ..AdminService
using ..AppConfig
using ..SupabaseDbService
using ..ActiveStudentService
using Dates
using JSON3
import Base64: base64decode

# Helper: Return JSON response with CORS headers
function json_cors(data::Any, status::Int=200)
    return HTTP.Response(
        status,
        [
            "Content-Type" => "application/json; charset=utf-8",
            "Access-Control-Allow-Origin" => "*",
            "Access-Control-Allow-Methods" => "GET, POST, OPTIONS, PUT, DELETE",
            "Access-Control-Allow-Headers" => "Content-Type, Authorization"
        ],
        JSON3.write(data)
    )
end

json_cors(data::Any) = json_cors(data, 200)

# Helper: Strip data URI prefix (e.g., "data:*;base64,") from Base64 strings
function strip_base64_prefix(data::String)
    # Pattern matches "data:mediatype;base64," where mediatype can be anything
    prefix_pattern = r"^data:[a-zA-Z0-9+/]+;base64,"
    return replace(data, prefix_pattern => "")
end

# Utility: coerce incoming payload (possibly JSON3 types) into native Dict{String,Any}
function _to_native_dict(x)
    if x === nothing
        return Dict{String,Any}()
    elseif isa(x, Dict)
        # Convert Symbol keys to String keys
        result = Dict{String,Any}()
        for (k, v) in x
            key_str = isa(k, Symbol) ? string(k) : k
            result[key_str] = v
        end
        return result
    else
        # round-trip via JSON3 to ensure native types
        try
            return JSON3.read(JSON3.write(x), Dict{String,Any})
        catch
            return Dict{String,Any}()
        end
    end
end

# Utility: Clean base64 string by removing data URI prefix, whitespace, and newlines
function clean_base64_string(base64_str::String)::String
    # Remove data URI prefix (e.g., "data:*;base64,")
    clean = replace(base64_str, r"^data:[a-zA-Z0-9+/]+;base64," => "")
    
    # Remove all whitespace and newlines
    clean = replace(clean, r"\s+" => "")
    
    return clean
end

function get_payload()
    raw = jsonpayload()
    pd = _to_native_dict(raw)
    isempty(pd) && error("No JSON payload provided")
    return pd
end

# ---------------- News ----------------
function post_news()
    try
    println("POST news called")
    payload = get_payload()
    println("Payload: ", payload)

    programme = get(payload, "programme", "All")
    level = get(payload, "level", "All")
    title = get(payload, "title", "")
    body = get(payload, "body", "")
    
    # Try database first
    if !isnothing(SupabaseDbService.DB_CONFIG)
        success, msg = SupabaseDbService.insert_news(programme, level, title, body)
        if success
            println("Saved news to database")
            return json_cors(Dict("success" => true, "message" => "News posted to database"))
        else
            @warn "Failed to save to database: $msg"
        end
    end
    
    # Fallback to JSON
    data = Dict{String,Any}(
        "programme" => programme,
        "level" => level,
        "title" => title,
        "body" => body,
        "timestamp" => string(Dates.now())
    )
    AdminService.save_to_json("news.json", data)
    println("Saved to news.json")
    return json_cors(Dict("success" => true, "message" => "News posted to JSON (DB not available)"))
    catch e
        @error "Error in post_news: $e"
        return json_cors(
            Dict("success" => false, "error" => "Server error"),
            500
        )
    end
end


# Renamed to avoid method extension conflict
function admin_get_news()
    # Extract query parameters from URI
    req = Genie.Requests.request()
    uri = req.target
    
    programme = "All"
    level = "All"
    
    # Parse query string
    if contains(uri, '?')
        query_string = split(uri, '?')[2]
        params_array = split(query_string, '&')
        for param in params_array
            if contains(param, '=')
                key, value = split(param, '='; limit=2)
                key = strip(key)
                value = HTTP.URIs.unescapeuri(strip(value))
                if key == "programme"
                    programme = value
                elseif key == "level"
                    level = value
                end
            end
        end
    end
    
    @info "admin_get_news called with: programme=$programme, level=$level"
    
    # Try database first
    if !isnothing(SupabaseDbService.DB_CONFIG)
        success, msg, news = SupabaseDbService.get_news(programme, level)
        if success
            @info "Got $(length(news)) news items from database"
            return json_cors(news)
        else
            @warn "Failed to fetch from database: $msg"
        end
    end
    
    # Fallback to JSON
    raw_data = AdminService.get_json_data("news.json")
    valid_entries = []
    for entry in raw_data
        if haskey(entry, "title") && haskey(entry, "body") &&
           entry["title"] != "" && entry["body"] != ""
            # Check if entry matches filters
            entry_programme = get(entry, "programme", "All")
            entry_level = get(entry, "level", "All")
            
            # Include if matches or "All" is used
            if (programme == "All" || entry_programme == programme || entry_programme == "All") &&
               (level == "All" || entry_level == level || entry_level == "All")
                
                clean_entry = Dict{String,Any}()
                clean_entry["id"] = get(entry, "id", nothing)
                clean_entry["programme"] = entry_programme
                clean_entry["level"] = entry_level
                clean_entry["title"] = entry["title"]
                clean_entry["body"] = entry["body"]
                clean_entry["content"] = get(entry, "content", entry["body"])
                clean_entry["created_at"] = get(entry, "created_at", get(entry, "timestamp", ""))
                push!(valid_entries, clean_entry)
            end
        end
    end
    @info "Filtered to $(length(valid_entries)) news items"
    return json_cors(valid_entries)
end

"""
    delete_news()

Deletes a news item from Supabase by id.
Expects JSON body:
{
  "id": <integer>
}
"""
function delete_news()
    payload = Dict{String, Any}()
    try
        req = Genie.Requests.request()
        body = String(req.body)
        if !isempty(body)
            payload = JSON3.read(body, Dict{String, Any})
        end
    catch e
        @warn "Error reading DELETE request body: $(string(e))"
        payload = Dict{String, Any}()
    end

    id = get(payload, "id", "")
    if isempty(id)
        return json_cors(Dict("success" => false, "message" => "id is required for deletion"), 400)
    end
    
    # Call SupabaseDbService to delete the news by id
    success, msg = SupabaseDbService.delete_news_by_id(id)
    if success
        return json_cors(Dict("success" => true, "message" => "News deleted successfully"))
    else
        return json_cors(Dict("success" => false, "message" => msg), 400)
    end
end

# ---------------- Materials ----------------
function post_materials()
    try
        println("[POST_MATERIALS] Processing material upload request...")
        
        # Get JSON payload - handle both Vector{UInt8} and String
        raw_payload = Genie.Requests.rawpayload()
        
        if raw_payload === nothing || isempty(raw_payload)
            println("[POST_MATERIALS] ERROR: Empty request body")
            return json_cors(
                Dict("success" => false, "message" => "Empty request body"),
                400
            )
        end
        
        println("[POST_MATERIALS] Payload type: $(typeof(raw_payload)), size: $(length(raw_payload))")
        
        # Convert to string if needed (rawpayload returns Vector{UInt8})
        payload_str = isa(raw_payload, String) ? raw_payload : String(raw_payload)
        
        println("[POST_MATERIALS] Payload string preview: $(first(payload_str, 200))...")
        
        # Parse JSON payload
        payload = try
            JSON3.read(payload_str, Dict{String,Any})
        catch e
            println("[POST_MATERIALS] ERROR: Failed to parse JSON - $(string(e))")
            return json_cors(
                Dict("success" => false, "message" => "Invalid JSON payload: $(string(e))"),
                400
            )
        end
        
        # Extract base64 file data
        file_base64 = get(payload, "file_base64", "")
        filename = get(payload, "filename", "")
        
        if isempty(file_base64)
            println("[POST_MATERIALS] ERROR: file_base64 is empty")
            return json_cors(
                Dict("success" => false, "message" => "File data (file_base64) is required"),
                400
            )
        end
        
        if isempty(filename)
            println("[POST_MATERIALS] ERROR: filename is empty")
            return json_cors(
                Dict("success" => false, "message" => "Filename is required"),
                400
            )
        end
        
        println("[POST_MATERIALS] Processing file: $filename, base64 length: $(length(file_base64))")

        # Clean base64 string - remove data URI prefix, whitespace, and newlines
        clean_base64 = clean_base64_string(file_base64)
        println("[POST_MATERIALS] Base64 (cleaned) length: $(length(clean_base64))")

        # Validate base64 format (basic check for valid characters)
        if !occursin(r"^[A-Za-z0-9+/]*={0,2}$", clean_base64)
            println("[POST_MATERIALS] ERROR: Base64 contains invalid characters")
            return json_cors(
                Dict("success" => false, "message" => "Base64 data contains invalid characters"),
                400
            )
        end

        file_data = try
            base64decode(clean_base64)
        catch e
            println("[POST_MATERIALS] ERROR: Base64 decode failed - $(string(e))")
            return json_cors(
                Dict("success" => false, "message" => "Invalid base64 data: $(string(e))"),
                400
            )
        end
        
        println("[POST_MATERIALS] Decoded file size: $(length(file_data)) bytes")
        
        # Extract required metadata
        course_code = get(payload, "course", "")
        programme = get(payload, "programme", "")
        level = get(payload, "level", "100")
        category = get(payload, "category", "general")
        
        println("[POST_MATERIALS] Metadata - programme: $programme, level: $level, course: $course_code, category: $category")
        
        # Validate required fields
        if isempty(course_code)
            println("[POST_MATERIALS] ERROR: Course code is empty")
            return json_cors(
                Dict("success" => false, "message" => "Course code (course) is required"),
                400
            )
        end
        
        if isempty(programme)
            println("[POST_MATERIALS] ERROR: Programme is empty")
            return json_cors(
                Dict("success" => false, "message" => "Programme is required"),
                400
            )
        end
        
        # SUPABASE STORAGE: Upload file to Supabase Storage
        println("[POST_MATERIALS] Uploading to Supabase Storage...")
        success, error_msg, storage_path = AdminService.upload_material_to_supabase(
            file_data,
            filename,
            course_code,
            programme,
            level,
            category
        )
        
        # Handle upload failure
        if !success
            println("[POST_MATERIALS] ERROR: Supabase upload failed - $error_msg")
            return json_cors(
                Dict("success" => false, "message" => "Upload failed: $error_msg"),
                400
            )
        end
        
        println("[POST_MATERIALS] SUCCESS: File uploaded to $storage_path")
        
        # Build response with Supabase storage path
        return json_cors(
            Dict(
                "success" => true,
                "message" => "File uploaded successfully to Supabase Storage",
                "storage_path" => storage_path,
                "filename" => filename,
                "material_name" => filename,
                "course_code" => course_code,
                "level" => level,
                "programme" => programme
            )
        )
    catch e
        error_msg = string(e)
        println("[POST_MATERIALS] EXCEPTION: $error_msg")
        @error "Error uploading material: $e"
        return json_cors(
            Dict("success" => false, "message" => "Error uploading material: $error_msg"),
            500
        )
    end
end

function admin_get_materials()
    try
        url = "https://yecpwijvbiurqysxazva.supabase.co/rest/v1/materials"
        service_key = get(ENV, "SUPABASE_SERVICE_ROLE_KEY", "")
        
        if isempty(service_key)
            @warn "SUPABASE_SERVICE_ROLE_KEY not configured"
            return json_cors([], 200)
        end
        
        # Use curl to fetch from Supabase
        cmd = Cmd([
            "curl", "-s",
            "-H", "apikey: $service_key",
            "-H", "Authorization: Bearer $service_key",
            url
        ])
        result = read(cmd, String)

        if isempty(result)
            return json_cors([], 200)
        end

        # Parse JSON
        parsed = JSON3.read(result)

        if isa(parsed, AbstractArray)
            parsed = Vector(parsed)
            # Extract query parameters for filtering
            req = Genie.Requests.request()
            uri = req.target

            programme = nothing
            level = nothing
            course_code = nothing

            if contains(uri, '?')
                query_string = split(uri, '?')[2]
                params_array = split(query_string, '&')
                for param in params_array
                    if contains(param, '=')
                        key, value = split(param, '=')
                        key = strip(key)
                        value = HTTP.URIs.unescapeuri(strip(value))
                        if key == "programme"
                            programme = value
                        elseif key == "level"
                            level = value
                        elseif key == "course_code"
                            course_code = value
                        end
                    end
                end
            end

            # If no filters, return all
            if isnothing(programme) && isnothing(level) && isnothing(course_code)
                return json_cors(parsed)
            end

            # Apply filters
            filtered = []
            for material in parsed
                prog_match = isnothing(programme) || get(material, "programme", "") == programme
                level_match = isnothing(level) || string(get(material, "level", "")) == string(level)
                course_match = isnothing(course_code) || get(material, "course_code", "") == course_code

                if prog_match && level_match && course_match
                    push!(filtered, material)
                end
            end

            return json_cors(filtered)
        else
            return json_cors([], 200)
        end

    catch e
        @warn "Error in admin_get_materials: $(string(e))"
        return json_cors([], 200)
    end
end

function delete_materials()
    # Get object_name from JSON body
    payload = Dict{String, Any}()
    
    try
        # Get the request object
        req = Genie.Requests.request()
        body = String(req.body)
        
        if !isempty(body)
            payload = JSON3.read(body, Dict{String, Any})
            payload = _to_native_dict(payload)
        end
    catch e
        @warn "Error reading DELETE request body: $(string(e))"
        payload = Dict{String, Any}()
    end
    
    # Extract the storage_path to delete (support both storage_path and object_name for compatibility)
    storage_path = get(payload, "storage_path", get(payload, "object_name", ""))
    
    if isempty(storage_path)
        return json_cors(
            Dict("success" => false, "message" => "storage_path is required"),
            400
        )
    end
    
    # Delete material from Supabase Storage and metadata
    success, error_msg = AdminService.delete_material_from_supabase(storage_path)
    
    if !success
        return json_cors(
            Dict("success" => false, "message" => error_msg),
            400
        )
    end
    
    return json_cors(
        Dict(
            "success" => true,
            "message" => "Material deleted successfully",
            "storage_path" => storage_path
        )
    )
end

function download_material()
    # Get storage_path from JSON body
    payload = get_payload()
    storage_path = get(payload, "storage_path", "")
    
    if isempty(storage_path)
        return json_cors(
            Dict("success" => false, "message" => "storage_path is required"),
            400
        )
    end
    
    # Generate signed download URL from Supabase
    success, url_or_error = AdminService.get_download_url(storage_path, 3600)
    
    if !success
        return json_cors(
            Dict("success" => false, "message" => url_or_error),
            400
        )
    end
    
    return json_cors(
        Dict(
            "success" => true,
            "message" => "Download URL generated successfully",
            "url" => url_or_error
        )
    )
end

# --------  Timetable ----------------
function post_timetable()
    raw = jsonpayload()
    pd = _to_native_dict(raw)
    programme = get(pd, "programme", "All")
    level = get(pd, "level", "All")
    day_of_week = get(pd, "day", nothing)  # Get the specific day from frontend
    timetable = haskey(pd, "timetable") ? pd["timetable"] : Dict{String,Any}()
    
    # Try database first
    if !isnothing(SupabaseDbService.DB_CONFIG)
        # If a specific day is provided, process only that day
        if !isnothing(day_of_week) && day_of_week != ""
            days_to_process = [day_of_week]
            
            # Delete old data for this day before inserting new data
            success, msg = SupabaseDbService.delete_timetable_day(programme, level, "first-semester", day_of_week)
            if !success
                @warn "Warning: Could not delete old timetable data: $msg"
            end
        else
            # Fallback: process all days if no specific day provided
            days_to_process = ["Monday","Tuesday","Wednesday","Thursday","Friday"]
        end
        
        # Save timetable slots to database
        total_inserted = 0
        total_failed = 0
        for day in days_to_process
            slots = get(timetable, day, [])
            @info "Saving $(length(slots)) slots for $day"
            inserted = 0
            failed = 0
            for (slot_index, slot) in enumerate(slots)
                # Convert slot to native dict if needed
                slot_dict = isa(slot, Dict) ? slot : _to_native_dict(slot)

                # Skip empty slots - only save slots with actual content
                course_code = get(slot_dict, "code", "")
                course_title = get(slot_dict, "title", "")
                venue = get(slot_dict, "venue", "")
                lecturer = get(slot_dict, "lecturer", "")

                if isempty(strip(course_code)) && isempty(strip(course_title)) &&
                   isempty(strip(venue)) && isempty(strip(lecturer))
                    @info "Skipping empty slot index $slot_index for $day"
                    continue
                end

                success, msg = SupabaseDbService.insert_timetable_slot(
                    programme, level, "first-semester", day, slot_index, slot_dict
                )
                if success
                    inserted += 1
                    @info "Inserted slot index $slot_index for $day"
                else
                    failed += 1
                    @warn "Failed to save timetable slot for $day index $slot_index: $msg"
                end
            end
            @info "Day $day: inserted=$inserted failed=$failed"
            total_inserted += inserted
            total_failed += failed
        end
        
        day_label = !isnothing(day_of_week) && day_of_week != "" ? " for $day_of_week" : ""
        message = "Timetable$day_label saved to database"
        if total_failed > 0
            message *= " (inserted: $total_inserted, failed: $total_failed)"
        end
        return json_cors(Dict("success" => true, "message" => message))
    else
        # Fallback to JSON
        data = Dict{String,Any}(
            "programme" => programme,
            "level" => level,
            "timetable" => timetable,
            "timestamp" => string(Dates.now())
        )
        AdminService.save_to_json("timetable.json", data)
        return json_cors(Dict("success" => true, "message" => "Timetable saved to JSON (DB not available)"))
    end
end

function admin_get_timetable()
    # Parse query parameters from request URL
    req = Genie.Requests.request()
    uri = req.target
    
    programme = nothing
    level = nothing
    
    if contains(uri, '?')
        query_string = split(uri, '?')[2]
        params_array = split(query_string, '&')
        for param in params_array
            if contains(param, '=')
                key, value = split(param, '=')
                key = strip(key)
                value = HTTP.URIs.unescapeuri(strip(value))
                if key == "programme"
                    programme = value
                elseif key == "level"
                    level = value
                end
            end
        end
    end
    
    if programme === nothing || level === nothing
        return HTTP.Response(400, ["Content-Type"=>"application/json", "Access-Control-Allow-Origin"=>"*"], JSON3.write(Dict("error"=>"programme and level parameters are required"); indent=2))
    end
    
    # Try database first
    if !isnothing(SupabaseDbService.DB_CONFIG)
        success, msg, slots = SupabaseDbService.get_timetable(programme, level, "first-semester")
        
        if success && !isempty(slots)
            # Convert flat slots to day-organized structure
            DAYS = ["Monday","Tuesday","Wednesday","Thursday","Friday"]
            result = Dict{String,Any}()
            for day in DAYS
                result[day] = []
            end
            
            for slot in slots
                day = get(slot, "day_of_week", "Monday")
                if haskey(result, day)
                    push!(result[day], Dict(
                        "course_code" => get(slot, "course_code", ""),
                        "course_title" => get(slot, "course_title", ""),
                        "venue" => get(slot, "venue", ""),
                        "time" => get(slot, "time", ""),
                        "duration" => get(slot, "duration", 1),
                        "lecturer" => get(slot, "lecturer", "")
                    ))
                end
            end
            
            body = JSON3.write(result; indent=2)
            return HTTP.Response(200, ["Content-Type"=>"application/json", "Access-Control-Allow-Origin"=>"*"], body)
        end
    end
    
    # Fallback to JSON
    data = AdminService.get_json_data("timetable.json")
    records = isa(data, Vector) ? data : (isa(data, Dict) ? [data] : [])
    
    rawprog = lowercase(strip(string(programme)))
    prog = rawprog in ("met","meteorology") ? "meteorology" : rawprog in ("geo","geography") ? "geography" : rawprog
    lvl = lowercase(strip(string(level)))
    
    for item in records
        if !haskey(item, "timetable")
            continue
        end
        ip = lowercase(strip(string(get(item, "programme", ""))))
        il = lowercase(strip(string(get(item, "level", ""))))
        
        prog_match = ip == prog
        level_match = il == lvl
        
        if prog_match && level_match
            tt = get(item, "timetable", Dict())
            days = ["Monday","Tuesday","Wednesday","Thursday","Friday"]
            result = Dict{String,Any}()
            for d in days
                raw_slots = get(tt, d, [])
                slots = Any[]
                for s in raw_slots
                    code = get(s, "code", "")
                    title = get(s, "title", "")
                    venue = get(s, "venue", "")
                    time_str = get(s, "time", "")
                    lecturer = get(s, "lecturer", "")
                    duration = get(s, "duration", "1")
                    
                    if !(isempty(code) && isempty(title) && isempty(venue) && isempty(time_str))
                        push!(slots, Dict(
                            "course_code" => code,
                            "course_title" => title,
                            "venue" => venue,
                            "time" => time_str,
                            "duration" => duration,
                            "lecturer" => lecturer
                        ))
                    end
                end
                result[d] = slots
            end
            body = JSON3.write(result; indent=2)
            return HTTP.Response(200, ["Content-Type"=>"application/json", "Access-Control-Allow-Origin"=>"*"], body)
        end
    end
    
    # If no data found, return empty structure with all days (instead of error)
    DAYS = ["Monday","Tuesday","Wednesday","Thursday","Friday"]
    empty_result = Dict{String,Any}()
    for day in DAYS
        empty_result[day] = []
    end
    body = JSON3.write(empty_result; indent=2)
    return HTTP.Response(200, ["Content-Type"=>"application/json", "Access-Control-Allow-Origin"=>"*"], body)
end

# Delete all timetable entries for a specific day
function delete_timetable_day()
    # For DELETE requests, we need to manually read the body
    req = Genie.Requests.request()
    body_str = String(req.body)
    
    println(stderr, "[DELETE_DAY] Raw body string: '$body_str'")
    
    pd = if isempty(body_str)
        Dict{String, Any}()
    else
        try
            JSON3.read(body_str, Dict{String, Any})
        catch e
            println(stderr, "[DELETE_DAY] Error parsing JSON: $(string(e))")
            return json_cors(Dict("success" => false, "message" => "Error parsing request: $(string(e))"))
        end
    end
    
    println(stderr, "[DELETE_DAY] Parsed dict: $pd")
    
    programme = get(pd, "programme", "")
    level = get(pd, "level", "")
    day = get(pd, "day", "")
    
    println(stderr, "[DELETE_DAY] Extracted - programme='$programme', level='$level', day='$day'")
    
    if isempty(programme) || isempty(level) || isempty(day)
        println(stderr, "[DELETE_DAY] Missing required parameters!")
        return json_cors(Dict("success" => false, "message" => "Missing required parameters: programme=$programme, level=$level, day=$day"))
    end
    
    @info "Deleting timetable day: programme=$programme, level=$level, day=$day"
    
    # Try database first
    if !isnothing(SupabaseDbService.DB_CONFIG)
        # First, get all slot IDs for this day
        success, msg, slot_data = SupabaseDbService.get_timetable_slot_ids_for_day(programme, level, "first-semester", day)
        
        @info "Get slot IDs result: success=$success, msg=$msg, count=$(length(slot_data))"
        
        if !success
            @warn "Failed to get slot IDs: $msg"
            return json_cors(Dict("success" => false, "message" => msg))
        end
        
        if isempty(slot_data)
            @info "No slots found for this day"
            return json_cors(Dict("success" => true, "message" => "No slots to delete"))
        end
        
        # Delete each slot by ID
        deleted_count = 0
        for slot in slot_data
            slot_id = get(slot, "id", nothing)
            if !isnothing(slot_id)
                # Convert to Int safely
                slot_id_int = try
                    isa(slot_id, Int) ? slot_id : Int(parse(Float64, string(slot_id)))
                catch e
                    @warn "Failed to parse slot ID: $slot_id, error: $e"
                    continue
                end
                
                @info "Deleting slot ID: $slot_id_int (type: $(typeof(slot_id_int)))"
                success, msg = SupabaseDbService.delete_timetable_slot_by_id(slot_id_int)
                if success
                    deleted_count += 1
                    @info "Deleted slot ID: $slot_id_int"
                else
                    @warn "Failed to delete slot ID $slot_id_int: $msg"
                end
            end
        end
        
        @info "Successfully deleted $deleted_count timetable slots for $day"
        return json_cors(Dict("success" => true, "message" => "Deleted $deleted_count timetable slot(s)"))
    else
        # Fallback: not supported for JSON
        return json_cors(Dict("success" => false, "message" => "Database not available"))
    end
end

# Delete a specific timetable slot
function delete_timetable_slot()
    raw = jsonpayload()
    pd = _to_native_dict(raw)
    
    programme = get(pd, "programme", "")
    level = get(pd, "level", "")
    day = get(pd, "day", "")
    slot_index = get(pd, "slot_index", -1)
    
    if isempty(programme) || isempty(level) || isempty(day) || slot_index < 0
        return json_cors(Dict("success" => false, "message" => "Missing required parameters"))
    end
    
    @info "Deleting timetable slot: programme=$programme, level=$level, day=$day, slot_index=$slot_index"
    
    # Try database first
    if !isnothing(SupabaseDbService.DB_CONFIG)
        success, msg = SupabaseDbService.delete_timetable_slot(programme, level, "first-semester", day, slot_index)
        if success
            @info "Successfully deleted timetable slot"
            return json_cors(Dict("success" => true, "message" => "Slot deleted successfully"))
        else
            @warn "Failed to delete timetable slot: $msg"
            return json_cors(Dict("success" => false, "message" => msg))
        end
    else
        # Fallback: not supported for JSON
        return json_cors(Dict("success" => false, "message" => "Database not available"))
    end
end

# ---------------- Courses ----------------
function post_courses()
    payload = get_payload()
    programme = get(payload, "programme", "All")
    level = get(payload, "level", "All")
    advisor = get(payload, "advisor", "")
    courses = get(payload, "courses", [])
    
    println("POST /api/admin/courses: programme=$programme, level=$level, #courses=$(length(courses))")
    
    # Validate required fields
    if isempty(programme) || isempty(level)
        return json_cors(
            Dict("success" => false, "message" => "Programme and level are required"),
            400
        )
    end
    
    # Try database first, fall back to JSON if DB not available
    if !isnothing(SupabaseDbService.DB_CONFIG)
        println("Database configured, saving courses...")
        # Save each course to database
        errors = []
        skipped = []
        inserted = []
        
        for course in courses
            course_code = get(course, "code", "")
            course_title = get(course, "title", "")
            lecturer1 = get(course, "lecturer1", "")
            lecturer2 = get(course, "lecturer2", "")
            lecturer3 = get(course, "lecturer3", "")
            units = parse(Int, string(get(course, "units", 1)))
            println("  Processing: $course_code with $units units")
            if !isempty(course_code)
                success, msg = SupabaseDbService.insert_course(
                    programme, level, course_code, course_title, advisor;
                    units=units, lecturer_1=lecturer1, lecturer_2=lecturer2, lecturer_3=lecturer3
                )
                if !success
                    # Check if this is a "already exists" message
                    if contains(msg, "already exists")
                        println("    SKIPPED (duplicate): $msg")
                        push!(skipped, msg)
                    else
                        println("    FAILED: $msg")
                        push!(errors, msg)
                    end
                else
                    println("    OK")
                    push!(inserted, course_code)
                end
            end
        end
        
        # Build response message
        response_dict = Dict{String,Any}("success" => true)
        
        if !isempty(inserted)
            response_dict["message"] = "Courses saved successfully"
            response_dict["inserted"] = length(inserted)
        else
            response_dict["message"] = "No new courses were saved"
            response_dict["inserted"] = 0
        end
        
        if !isempty(skipped)
            response_dict["skipped"] = length(skipped)
            # Limit skipped details to prevent stack overflow on frontend
            response_dict["skipped_details"] = skipped[1:min(10, length(skipped))]
        end
        
        if !isempty(errors)
            response_dict["success"] = false
            response_dict["errors"] = length(errors)
            response_dict["error_details"] = errors
            response_dict["message"] = "Some courses failed to save: $(join(errors, "; "))"
            
            return json_cors(response_dict, 400)
        end
        
        println("Response: $(response_dict)")
        return json_cors(response_dict)
    else
        println("Database NOT configured, using JSON fallback")
        # Fallback to JSON storage
        data = Dict{String,Any}(
            "programme" => programme,
            "level" => level,
            "advisor" => advisor,
            "courses" => courses,
            "timestamp" => string(Dates.now())
        )
        AdminService.save_to_json("courses.json", data)
        return json_cors(Dict("success" => true, "message" => "Courses saved to JSON (DB not available)"))
    end
end

function admin_get_courses()
    # Extract query parameters
    req = Genie.Requests.request()
    uri = req.target
    
    programme = nothing
    level = nothing
    
    if contains(uri, '?')
        query_string = split(uri, '?')[2]
        params_array = split(query_string, '&')
        for param in params_array
            if contains(param, '=')
                key, value = split(param, '='; limit=2)
                key = strip(key)
                value = HTTP.URIs.unescapeuri(strip(value))
                if key == "programme"
                    programme = value
                elseif key == "level"
                    level = value
                end
            end
        end
    end
    
    @info "admin_get_courses: uri=$uri, programme=$programme, level=$level"
    
    # Normalize level - ensure it's not empty or "undefined"
    if level === nothing || isempty(level) || level == "undefined" || level == "null"
        level = nothing
    end
    
    # Try database first - only proceed if ALL parameters are provided and valid
    if !isnothing(SupabaseDbService.DB_CONFIG) && programme !== nothing && level !== nothing
        @info "Fetching courses from Supabase: programme=$programme, level=$level"
        success, msg, courses = SupabaseDbService.get_courses(programme, level)
        
        if success
            # Transform field names for frontend compatibility
            transformed = []
            for course in courses
                transformed_course = Dict(
                    "id" => get(course, "id", ""),
                    "code" => get(course, "course_code", ""),
                    "title" => get(course, "course_title", ""),
                    "course_code" => get(course, "course_code", ""),
                    "course_title" => get(course, "course_title", ""),
                    "type" => get(course, "course_type", "compulsory"),
                    "units" => get(course, "course_units", 1),
                    "course_units" => get(course, "course_units", 1),
                    "lecturer1" => get(course, "lecturer_1", ""),
                    "lecturer2" => get(course, "lecturer_2", ""),
                    "lecturer3" => get(course, "lecturer_3", ""),
                    "advisor" => get(course, "advisor", "")
                )
                push!(transformed, transformed_course)
            end
            # Return courses array directly
            return json_cors(transformed)
        else
            @warn "Failed to fetch from database: $msg"
        end
    end
    
    # Fallback to JSON
    raw_data = AdminService.get_json_data("courses.json")
    
    valid_entries = []
    for entry in raw_data
        if haskey(entry, "programme") && haskey(entry, "level") && 
           haskey(entry, "courses") && entry["programme"] !== nothing && 
           entry["level"] !== nothing
            
            if programme !== nothing || level !== nothing
                entry_prog = lowercase(strip(string(get(entry, "programme", ""))))
                entry_level = lowercase(strip(string(get(entry, "level", ""))))
                req_prog = programme !== nothing ? lowercase(strip(string(programme))) : nothing
                req_level = level !== nothing ? lowercase(strip(string(level))) : nothing
                
                if req_prog !== nothing
                    req_prog = req_prog in ("met","meteorology") ? "meteorology" : req_prog in ("geo","geography") ? "geography" : req_prog
                end
                
                prog_match = req_prog === nothing || entry_prog == req_prog
                level_match = req_level === nothing || entry_level == req_level
                
                if !prog_match || !level_match
                    continue
                end
            end
            
            filtered_courses = []
            for course in entry["courses"]
                if haskey(course, "code") && haskey(course, "title") &&
                   (course["code"] != "" || course["title"] != "")
                    clean_course = Dict{String,Any}()
                    clean_course["code"] = course["code"]
                    clean_course["title"] = course["title"]
                    clean_course["type"] = get(course, "type", "compulsory")
                    
                    for i in 1:3
                        lecturer_key = "lecturer$i"
                        if haskey(course, lecturer_key) && course[lecturer_key] != ""
                            clean_course[lecturer_key] = course[lecturer_key]
                        end
                    end
                    push!(filtered_courses, clean_course)
                end
            end
            
            if length(filtered_courses) > 0
                clean_entry = Dict{String,Any}()
                clean_entry["programme"] = entry["programme"]
                clean_entry["level"] = entry["level"]
                clean_entry["advisor"] = get(entry, "advisor", "")
                clean_entry["courses"] = filtered_courses
                push!(valid_entries, clean_entry)
            end
        end
    end
    
    return json_cors(valid_entries)
end

"""
    update_courses()

Updates a course and renames associated materials in B2 storage.
Expects JSON payload with:
{
  "programme": "Meteorology",
  "level": "100",
  "old_course_code": "MET111",
  "new_course_code": "MET111",
  "old_title": "Old Title",
  "new_title": "New Title",
  ...other fields
}
"""
function update_courses()
    try
        # Get payload
        context = Genie.Router.current()
        payload = Dict{String, Any}()
        
        try
            raw_body = Genie.Requests.rawpayload()
            if raw_body !== nothing && !isempty(raw_body)
                payload = JSON3.read(String(raw_body), Dict{String, Any})
            end
        catch
            payload = _to_native_dict(get_payload())
        end
        
        programme = get(payload, "programme", "")
        level = get(payload, "level", "")
        old_code = get(payload, "old_course_code", "")
        new_code = get(payload, "new_course_code", "")
        new_title = get(payload, "new_title", "")
        
        if isempty(programme) || isempty(level) || isempty(old_code)
            return json_cors(
                Dict("success" => false, "message" => "programme, level, and old_course_code are required"),
                400
            )
        end
        
        # Load courses
        courses_data = AdminService.get_json_data("courses.json")
        
        # Find and update the course
        updated = false
        for entry in courses_data
            if entry["programme"] == programme && entry["level"] == level
                for course in entry["courses"]
                    if course["code"] == old_code
                        # If code changed, rename files in B2
                        if old_code != new_code
                            success, msg = AdminService.rename_course_materials_in_b2(
                                programme, level, old_code, new_code
                            )
                            if !success
                                return json_cors(
                                    Dict("success" => false, "message" => "Failed to rename materials: $msg"),
                                    500
                                )
                            end
                        end
                        
                        # Update course details
                        course["code"] = new_code
                        if !isempty(new_title)
                            course["title"] = new_title
                        end
                        
                        updated = true
                        break
                    end
                end
            end
        end
        
        if !updated
            return json_cors(
                Dict("success" => false, "message" => "Course not found"),
                404
            )
        end
        
        # Save updated courses
        AdminService.save_to_json("courses.json", courses_data)
        
        return json_cors(
            Dict("success" => true, "message" => "Course updated successfully")
        )
        
    catch e
        return json_cors(
            Dict("success" => false, "message" => "Error updating course: $(string(e))"),
            500
        )
    end
end

"""
    get_active_students()

Get list of active students seen within the last N minutes.
Admin-only endpoint protected by JWT validation.

Query Parameters:
- minutes: Time window in minutes (default 5)

Returns:
- List of active students with their profile information
- Last seen timestamp
"""
function get_active_students()
    try
        # Get query parameters (optional: custom time window)
        req = Genie.Requests.request()
        uri = req.target
        minutes = 5  # Default
        
        # Parse query string for minutes parameter
        if contains(uri, '?')
            query_string = split(uri, '?')[2]
            params_array = split(query_string, '&')
            for param in params_array
                if contains(param, "minutes=")
                    try
                        minutes = parse(Int, split(param, "=")[2])
                    catch
                        # Use default if parsing fails
                    end
                end
            end
        end
        
        # Call service to get active students
        success, students, error = ActiveStudentService.get_active_students(minutes)
        
        if !success
            return json_cors(
                Dict(
                    "success" => false,
                    "error" => error,
                    "message" => "Failed to fetch active students"
                ),
                500
            )
        end
        
        # Format students for response
        formatted_students = map(ActiveStudentService.format_active_student, students)
        
        return json_cors(
            Dict(
                "success" => true,
                "count" => length(students),
                "window_minutes" => minutes,
                "timestamp" => string(Dates.now(Dates.UTC)),
                "students" => formatted_students
            )
        )
        
    catch e
        @error "Error in get_active_students: $e"
        return json_cors(
            Dict(
                "success" => false,
                "error" => "Internal server error",
                "message" => string(e)
            ),
            500
        )
    end
end

end  # module AdminController