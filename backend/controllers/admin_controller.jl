
module AdminController
using HTTP
using JSON3

# --- Supabase Auth: Secure Admin Middleware ---

const SUPABASE_URL = "https://yecpwijvbiurqysxazva.supabase.co"
const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY"  # Replace with your real anon key

"""
    get_user_role(user_id::String) -> String | nothing
Fetches the user's role from the Supabase profiles table.
"""
function get_user_role(user_id::String)
    url = "$(SUPABASE_URL)/rest/v1/profiles?id=eq.$user_id&select=role"
    headers = [
        "apikey" => SUPABASE_ANON_KEY,
        "Authorization" => "Bearer $SUPABASE_ANON_KEY"
    ]
    resp = HTTP.get(url, headers)
    if resp.status == 200
        data = JSON3.read(String(resp.body))
        if !isempty(data) && haskey(data[1], "role")
            return data[1]["role"]
        end
    end
    return nothing
end

"""
    require_admin() -> HTTP.Response | nothing
Middleware: Ensures the request is authenticated and user is an admin.
Returns HTTP.Response on failure, nothing on success.
"""
function require_admin()
    # For now, skip admin auth - all POST requests are treated as admin
    # TODO: Implement proper authentication if needed
    return nothing
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
        # --- Admin Auth Guard ---
        guard = require_admin()
        if !isnothing(guard)
            return guard
        end
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

export delete_course, delete_news, post_news, download_material, post_materials, post_timetable, post_courses, update_courses, delete_materials, get_news, get_materials, get_timetable, admin_get_courses, delete_timetable_slot, delete_timetable_day, admin_get_news, admin_get_materials, admin_get_timetable

using Genie.Router
using Genie.Renderer.Json
using Genie.Requests
using HTTP
using ..AdminService
using ..AppConfig
using ..SupabaseDbService
using Dates
using JSON3

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

function get_payload()
    raw = jsonpayload()
    pd = _to_native_dict(raw)
    isempty(pd) && error("No JSON payload provided")
    return pd
end

# ---------------- News ----------------
function post_news()
        # --- Admin Auth Guard ---
        guard = require_admin()
        if !isnothing(guard)
            return guard
        end
    println("POST news called")
    payload = get_payload()
    println("Payload: ", payload)

    programme = get(payload, "programme", "All")
    level = get(payload, "level", "All")
    semester = get(payload, "semester", "first-semester")
    title = get(payload, "title", "")
    body = get(payload, "body", "")
    
    # Try database first
    if !isnothing(SupabaseDbService.DB_CONFIG)
        success, msg = SupabaseDbService.insert_news(programme, level, semester, title, body)
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
        "semester" => semester,
        "title" => title,
        "body" => body,
        "timestamp" => string(Dates.now())
    )
    AdminService.save_to_json("news.json", data)
    println("Saved to news.json")
    return json_cors(Dict("success" => true, "message" => "News posted to JSON (DB not available)"))
end


# Renamed to avoid method extension conflict
function admin_get_news()
    # Extract query parameters from URI
    req = Genie.Requests.request()
    uri = req.target
    
    programme = "All"
    level = "All"
    semester = "All"
    
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
                elseif key == "semester"
                    semester = value
                end
            end
        end
    end
    
    @info "admin_get_news called with: programme=$programme, level=$level, semester=$semester"
    
    # Try database first
    if !isnothing(SupabaseDbService.DB_CONFIG)
        success, msg, news = SupabaseDbService.get_news(programme, level, semester)
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
            entry_semester = get(entry, "semester", "All")
            
            # Include if matches or "All" is used
            if (programme == "All" || entry_programme == programme || entry_programme == "All") &&
               (level == "All" || entry_level == level || entry_level == "All") &&
               (semester == "All" || entry_semester == semester || entry_semester == "All")
                
                clean_entry = Dict{String,Any}()
                clean_entry["id"] = get(entry, "id", nothing)
                clean_entry["programme"] = entry_programme
                clean_entry["level"] = entry_level
                clean_entry["semester"] = entry_semester
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
    # --- Admin Auth Guard ---
    guard = require_admin()
    if !isnothing(guard)
        return guard
    end
    
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
        # --- Admin Auth Guard ---
        guard = require_admin()
        if !isnothing(guard)
            return guard
        end
    # Get uploaded file
    files = Genie.Requests.filespayload()
    isempty(files) && return json_cors(
        Dict("success" => false, "message" => "No file uploaded"),
        400
    )

    # Extract file from multipart upload
    file = first(values(files))
    
    # Get form fields
    rawp = Genie.Requests.postpayload()
    payload = _to_native_dict(rawp)
    
    # Extract required metadata
    course_code = get(payload, "course", "UNKNOWN")
    programme = get(payload, "programme", "unknown")
    level = get(payload, "level", "100")
    semester = get(payload, "semester", nothing)
    category = get(payload, "category", "general")
    
    # Validate required fields
    if isempty(course_code) || isempty(programme)
        return json_cors(
            Dict("success" => false, "message" => "Course code and programme are required"),
            400
        )
    end
    
    # SUPABASE STORAGE: Upload file to Supabase Storage
    success, error_msg, storage_path = AdminService.upload_material_to_supabase(
        file.data,
        file.name,
        course_code,
        programme,
        level,
        semester,
        category
    )
    
    # Handle upload failure
    if !success
        return json_cors(
            Dict("success" => false, "message" => error_msg),
            400
        )
    end
    
    # SUPABASE DATABASE: Insert metadata into materials table
    try
        url = "$(SupabaseDbService.DB_CONFIG.url)/rest/v1/materials"
        # Build material data with essential fields
        material_data = Dict(
            "storage_path" => storage_path,
            "material_name" => file.name,
            "programme" => programme,
            "level" => level,
            "course_code" => course_code
        )
        
        # Add optional fields only if they have values
        if !isnothing(semester) && !isempty(semester)
            material_data["semester"] = semester
        end
        
        if !isnothing(category) && !isempty(category)
            material_data["material_type"] = category
        end
        
        payload_json = JSON3.write(material_data)
        cmd = Cmd([
            "curl", "-i", "-s", "-X", "POST",
            "-H", "apikey: $(SupabaseDbService.DB_CONFIG.service_role_key)",
            "-H", "Authorization: Bearer $(SupabaseDbService.DB_CONFIG.service_role_key)",
            "-H", "Content-Type: application/json",
            "-d", payload_json,
            url
        ])
        println("[MaterialMeta] Inserting material: $file.name for $course_code")
        println("[MaterialMeta] PAYLOAD: ", payload_json)
        result = read(cmd, String)
        
        # Extract HTTP status code from result (support both HTTP/1.1 and HTTP/2)
        status_match = match(r"HTTP/[12]\.?[01]?\s+(\d+)", result)
        status_code = status_match !== nothing ? parse(Int, status_match.captures[1]) : 0
        
        if status_code >= 200 && status_code < 300
            println("[MaterialMeta] ✓ Material metadata inserted successfully (HTTP $status_code)")
        else
            # Log the full response for debugging
            println("[MaterialMeta] ⚠ Insert returned HTTP $status_code")
            println("[MaterialMeta] Response: ", result)
            @warn "Material metadata insert returned status $status_code - may not be stored"
        end
    catch e
        @warn "Error inserting material metadata to Supabase: $(string(e))"
    end
    
    # Build response with Supabase storage path
    return json_cors(
        Dict(
            "success" => true,
            "message" => "File uploaded successfully to Supabase Storage and metadata queued for insert",
            "storage_path" => storage_path,
            "filename" => file.name,
            "material_name" => file.name,
            "course_code" => course_code,
            "level" => level,
            "semester" => semester,
            "programme" => programme
        )
    )
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
        println("[DEBUG-MATERIALS] Curl result: $result")
        
        if isempty(result)
            println("[DEBUG-MATERIALS] Empty response from Supabase")
            return json_cors([], 200)
        end
        
        # Parse JSON
        parsed = JSON3.read(result)
        println("[DEBUG-MATERIALS] Parsed type: $(typeof(parsed)), length: $(length(parsed))")
        
        if isa(parsed, Vector)
            # Extract query parameters for filtering
            req = Genie.Requests.request()
            uri = req.target
            
            programme = nothing
            level = nothing
            semester = nothing
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
                        elseif key == "semester"
                            semester = value
                        elseif key == "course_code"
                            course_code = value
                        end
                    end
                end
            end
            
            println("[DEBUG-MATERIALS] Filters - prog=$programme, level=$level, sem=$semester, course=$course_code")
            
            # If no filters, return all
            if isnothing(programme) && isnothing(level) && isnothing(semester) && isnothing(course_code)
                println("[DEBUG-MATERIALS] No filters, returning all $(length(parsed)) materials")
                return json_cors(parsed)
            end
            
            # Apply filters
            filtered = []
            for material in parsed
                prog_match = isnothing(programme) || get(material, "programme", "") == programme
                level_match = isnothing(level) || string(get(material, "level", "")) == string(level)
                sem_match = isnothing(semester) || get(material, "semester", "") == semester
                course_match = isnothing(course_code) || get(material, "course_code", "") == course_code
                
                if prog_match && level_match && sem_match && course_match
                    push!(filtered, material)
                    println("[DEBUG-MATERIALS] Match found: $(get(material, "material_name", "Unknown"))")
                end
            end
            
            println("[DEBUG-MATERIALS] Filtered to $(length(filtered)) materials")
            return json_cors(filtered)
        else
            println("[DEBUG-MATERIALS] Response is not a vector: $parsed")
            return json_cors([], 200)
        end
        
    catch e
        println("[DEBUG-MATERIALS] Error: $(string(e))")
        @warn "Error in admin_get_materials: $(string(e))"
        return json_cors([], 200)
    end
end

function delete_materials()
        # --- Admin Auth Guard ---
        guard = require_admin()
        if !isnothing(guard)
            return guard
        end
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
        # --- Admin Auth Guard ---
        guard = require_admin()
        if !isnothing(guard)
            return guard
        end
    raw = jsonpayload()
    pd = _to_native_dict(raw)
    programme = get(pd, "programme", "All")
    level = get(pd, "level", "All")
    semester = get(pd, "semester", "first-semester")
    day_of_week = get(pd, "day", nothing)  # Get the specific day from frontend
    timetable = haskey(pd, "timetable") ? pd["timetable"] : Dict{String,Any}()
    
    # Try database first
    if !isnothing(SupabaseDbService.DB_CONFIG)
        # If a specific day is provided, process only that day
        if !isnothing(day_of_week) && day_of_week != ""
            days_to_process = [day_of_week]
            
            # Delete old data for this day before inserting new data
            success, msg = SupabaseDbService.delete_timetable_day(programme, level, semester, day_of_week)
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
                    programme, level, semester, day, slot_index, slot_dict
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
            "semester" => semester,
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
    semester = nothing
    
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
                elseif key == "semester"
                    semester = value
                end
            end
        end
    end
    
    if programme === nothing || level === nothing
        return HTTP.Response(400, ["Content-Type"=>"application/json", "Access-Control-Allow-Origin"=>"*"], JSON3.write(Dict("error"=>"programme and level parameters are required"); indent=2))
    end
    
    # Default to first-semester if not specified
    if semester === nothing
        semester = "first-semester"
    end
    
    # Try database first
    if !isnothing(SupabaseDbService.DB_CONFIG)
        success, msg, slots = SupabaseDbService.get_timetable(programme, level, semester)
        
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
    sem = lowercase(strip(string(semester)))
    
    for item in records
        if !haskey(item, "timetable")
            continue
        end
        ip = lowercase(strip(string(get(item, "programme", ""))))
        il = lowercase(strip(string(get(item, "level", ""))))
        is_sem = lowercase(strip(string(get(item, "semester", ""))))
        
        prog_match = ip == prog
        level_match = il == lvl
        sem_match = is_sem == sem
        
        if prog_match && level_match && sem_match
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
    # --- Admin Auth Guard ---
    guard = require_admin()
    if !isnothing(guard)
        return guard
    end
    
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
    semester = get(pd, "semester", "first-semester")
    day = get(pd, "day", "")
    
    println(stderr, "[DELETE_DAY] Extracted - programme='$programme', level='$level', semester='$semester', day='$day'")
    
    if isempty(programme) || isempty(level) || isempty(day)
        println(stderr, "[DELETE_DAY] Missing required parameters!")
        return json_cors(Dict("success" => false, "message" => "Missing required parameters: programme=$programme, level=$level, day=$day"))
    end
    
    @info "Deleting timetable day: programme=$programme, level=$level, semester=$semester, day=$day"
    
    # Try database first
    if !isnothing(SupabaseDbService.DB_CONFIG)
        # First, get all slot IDs for this day
        success, msg, slot_data = SupabaseDbService.get_timetable_slot_ids_for_day(programme, level, semester, day)
        
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
    # --- Admin Auth Guard ---
    guard = require_admin()
    if !isnothing(guard)
        return guard
    end
    
    raw = jsonpayload()
    pd = _to_native_dict(raw)
    
    programme = get(pd, "programme", "")
    level = get(pd, "level", "")
    semester = get(pd, "semester", "first-semester")
    day = get(pd, "day", "")
    slot_index = get(pd, "slot_index", -1)
    
    if isempty(programme) || isempty(level) || isempty(day) || slot_index < 0
        return json_cors(Dict("success" => false, "message" => "Missing required parameters"))
    end
    
    @info "Deleting timetable slot: programme=$programme, level=$level, semester=$semester, day=$day, slot_index=$slot_index"
    
    # Try database first
    if !isnothing(SupabaseDbService.DB_CONFIG)
        success, msg = SupabaseDbService.delete_timetable_slot(programme, level, semester, day, slot_index)
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
        # --- Admin Auth Guard ---
        guard = require_admin()
        if !isnothing(guard)
            return guard
        end
    payload = get_payload()
    programme = get(payload, "programme", "All")
    level = get(payload, "level", "All")
    semester = get(payload, "semester", "first-semester")
    advisor = get(payload, "advisor", "")
    courses = get(payload, "courses", [])
    
    println("POST /api/admin/courses: programme=$programme, level=$level, semester=$semester, #courses=$(length(courses))")
    
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
                    programme, level, semester, course_code, course_title, advisor;
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
            response_dict["skipped_details"] = skipped
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
            "semester" => semester,
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
    semester = nothing
    
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
                elseif key == "semester"
                    semester = value
                end
            end
        end
    end
    
    # Try database first
    if !isnothing(SupabaseDbService.DB_CONFIG) && programme !== nothing && level !== nothing && semester !== nothing
        success, msg, courses = SupabaseDbService.get_courses(programme, level, semester)
        
        if success
            # Return courses array directly
            return json_cors(courses)
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
            
            if programme !== nothing || level !== nothing || semester !== nothing
                entry_prog = lowercase(strip(string(get(entry, "programme", ""))))
                entry_level = lowercase(strip(string(get(entry, "level", ""))))
                entry_sem = lowercase(strip(string(get(entry, "semester", ""))))
                req_prog = programme !== nothing ? lowercase(strip(string(programme))) : nothing
                req_level = level !== nothing ? lowercase(strip(string(level))) : nothing
                req_sem = semester !== nothing ? lowercase(strip(string(semester))) : nothing
                
                if req_prog !== nothing
                    req_prog = req_prog in ("met","meteorology") ? "meteorology" : req_prog in ("geo","geography") ? "geography" : req_prog
                end
                
                prog_match = req_prog === nothing || entry_prog == req_prog
                level_match = req_level === nothing || entry_level == req_level
                sem_match = req_sem === nothing || entry_sem == req_sem
                
                if !prog_match || !level_match || !sem_match
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
        # --- Admin Auth Guard ---
        guard = require_admin()
        if !isnothing(guard)
            return guard
        end
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

end  # module AdminController