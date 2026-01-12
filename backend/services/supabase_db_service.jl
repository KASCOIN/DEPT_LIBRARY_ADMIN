
module SupabaseDbService

export DB_CONFIG, delete_course_by_id, delete_news_by_id, get_news, get_materials, get_timetable, delete_timetable_slot, delete_timetable_slot_by_id, get_timetable_slot_ids_for_day

function delete_course_by_id(id::AbstractString)::Tuple{Bool, String}
    if isnothing(DB_CONFIG)
        return (false, "Database not configured")
    end
    try
        # Ensure id is integer for Supabase bigserial
        id_int = try
            parse(Int, id)
        catch
            return (false, "Invalid id: must be an integer")
        end
        url = "$(DB_CONFIG.url)/rest/v1/courses?id=eq.$id_int"
        headers = [
            "apikey" => DB_CONFIG.service_role_key,
            "Authorization" => "Bearer $(DB_CONFIG.service_role_key)",
            "Content-Type" => "application/json"
        ]
        response = HTTP.delete(
            url,
            headers;
            status_exception=false,
            connect_timeout=10,
            readtimeout=10
        )
        if response.status in [200, 204]
            return (true, "")
        else
            body_str = String(response.body)
            return (false, "Delete error: $body_str")
        end
    catch e
        return (false, "Error deleting course: $(string(e))")
    end
end

export delete_course_by_id, delete_news_by_id

function delete_news_by_id(id::AbstractString)::Tuple{Bool, String}
    if isnothing(DB_CONFIG)
        return (false, "Database not configured")
    end
    try
        # Ensure id is integer for Supabase bigserial
        id_int = try
            parse(Int, id)
        catch
            return (false, "Invalid id: must be an integer")
        end
        url = "$(DB_CONFIG.url)/rest/v1/news?id=eq.$id_int"
        headers = [
            "apikey" => DB_CONFIG.service_role_key,
            "Authorization" => "Bearer $(DB_CONFIG.service_role_key)",
            "Content-Type" => "application/json"
        ]
        response = HTTP.delete(
            url,
            headers;
            status_exception=false,
            connect_timeout=10,
            readtimeout=10
        )
        if response.status in [200, 204]
            return (true, "")
        else
            body_str = String(response.body)
            return (false, "Delete error: $body_str")
        end
    catch e
        return (false, "Error deleting news: $(string(e))")
    end
end

# Delete a course from Supabase
function delete_course(
    programme::AbstractString,
    level::AbstractString,
    semester::AbstractString,
    course_code::AbstractString
)::Tuple{Bool, String}
    if isnothing(DB_CONFIG)
        return (false, "Database not configured")
    end
    try
        url = "$(DB_CONFIG.url)/rest/v1/courses?programme=eq.$(HTTP.URIs.escapeuri(programme))&level=eq.$(HTTP.URIs.escapeuri(level))&semester=eq.$(HTTP.URIs.escapeuri(semester))&course_code=eq.$(HTTP.URIs.escapeuri(course_code))"
        headers = [
            "apikey" => DB_CONFIG.service_role_key,
            "Authorization" => "Bearer $(DB_CONFIG.service_role_key)",
            "Content-Type" => "application/json"
        ]
        response = HTTP.delete(
            url,
            headers;
            status_exception=false,
            connect_timeout=10,
            readtimeout=10
        )
        if response.status in [200, 204]
            return (true, "")
        else
            body_str = String(response.body)
            return (false, "Delete error: $body_str")
        end
    catch e
        return (false, "Error deleting course: $(string(e))")
    end
end

using HTTP
using JSON3
using Dates
using ..AppConfig

"""
    SupabaseDBConfig

Configuration for Supabase PostgREST API access.
"""
struct SupabaseDBConfig
    url::String
    service_role_key::String
    anon_key::String
end

"""
    get_db_config()::Union{SupabaseDBConfig, Nothing}

Loads Supabase Database configuration from environment variables.

Required environment variables:
- SUPABASE_URL: Supabase project URL (e.g., https://xxxx.supabase.co)
- SUPABASE_SERVICE_ROLE_KEY: Service role API key (for backend)
- SUPABASE_ANON_KEY: Anon key (optional, for public queries)

Returns: SupabaseDBConfig or Nothing if not configured
"""
function get_db_config()::Union{SupabaseDBConfig, Nothing}
    required_vars = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"]
    
    missing_vars = filter(var -> !haskey(ENV, var), required_vars)
    if !isempty(missing_vars)
        @warn "Supabase DB not configured. Missing: $(join(missing_vars, ", "))"
        return nothing
    end
    
    return SupabaseDBConfig(
        ENV["SUPABASE_URL"],
        ENV["SUPABASE_SERVICE_ROLE_KEY"],
        get(ENV, "SUPABASE_ANON_KEY", "")
    )
end

const DB_CONFIG = get_db_config()

# Log database configuration status on startup
if !isnothing(DB_CONFIG)
    @info "✓ Supabase Database configured: $(DB_CONFIG.url)"
    println(stderr, "[DEBUG] Supabase DB_CONFIG: $(DB_CONFIG)")
else
    @warn "⚠ Supabase Database NOT configured - will use JSON fallback"
    println(stderr, "[DEBUG] Supabase DB_CONFIG is nothing! Check your environment variables.")
end

# ==================== COURSES ====================

"""
    course_exists(course_code::String, level::String, semester::String)::Bool

Check if a course with the given code, level, and semester already exists in the database.
"""
function course_exists(
    course_code::AbstractString,
    level::AbstractString,
    semester::AbstractString
)::Bool
    
    if isnothing(DB_CONFIG)
        return false
    end
    
    try
        # Query for existing course with same code, level, semester
        url = "$(DB_CONFIG.url)/rest/v1/courses?course_code=eq.$(HTTP.URIs.escapeuri(course_code))&level=eq.$(HTTP.URIs.escapeuri(level))&semester=eq.$(HTTP.URIs.escapeuri(semester))"
        
        cmd = Cmd([
            "curl", "-s",
            "-H", "apikey: $(DB_CONFIG.service_role_key)",
            "-H", "Authorization: Bearer $(DB_CONFIG.service_role_key)",
            url
        ])
        
        result = read(cmd, String)
        
        if !isempty(result)
            data = JSON3.read(result, Vector)
            return length(data) > 0
        end
        return false
    catch
        # On error, allow insertion (fail open)
        return false
    end
end

function insert_course(
    programme::AbstractString,
    level::AbstractString,
    semester::AbstractString,
    course_code::AbstractString,
    course_title::AbstractString,
    advisor::AbstractString="";
    units::Integer=1,
    kwargs...
)::Tuple{Bool, String}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured")
    end
    
    # Check if course already exists
    if course_exists(course_code, level, semester)
        return (false, "Course $course_code already exists for Level $level - $semester (skipped to prevent duplicates)")
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/courses"
        
        headers = [
            "apikey" => DB_CONFIG.service_role_key,
            "Authorization" => "Bearer $(DB_CONFIG.service_role_key)",
            "Content-Type" => "application/json",
            "Prefer" => "return=minimal"
        ]
        
        body = Dict(
            "programme" => programme,
            "level" => level,
            "semester" => semester,
            "course_code" => course_code,
            "course_title" => course_title,
            "advisor" => advisor,
            "course_units" => units,
              "lecturer_1" => get(kwargs, :lecturer_1, ""),
              "lecturer_2" => get(kwargs, :lecturer_2, ""),
              "lecturer_3" => get(kwargs, :lecturer_3, "")
        )
        
        println(stderr, "[INSERT_COURSE] Inserting: $course_code for $programme/$level/$semester with $units units")
        println(stderr, "[INSERT_COURSE] Body: $body")
        
        response = HTTP.post(
            url,
            headers,
            JSON3.write(body);
            status_exception=false,
            connect_timeout=10,
            readtimeout=10
        )
        
        response_body = String(response.body)
        println(stderr, "[INSERT_COURSE] Response: status=$(response.status), body_len=$(length(response_body))")
        
        if response.status in [200, 201]
            println(stderr, "[INSERT_COURSE] SUCCESS: $course_code")
            return (true, "")
        else
            println(stderr, "[INSERT_COURSE] FAIL: $course_code - $(response.status) - $response_body")
            return (false, "Database error ($(response.status)): $response_body")
        end
    catch e
        println(stderr, "[INSERT_COURSE] EXCEPTION: $course_code - $(string(e))")
        return (false, "Error inserting course: $(string(e))")
    end
end

function get_courses(
    programme::AbstractString,
    level::AbstractString,
    semester::AbstractString
)::Tuple{Bool, String, Vector}
    
    if isnothing(DB_CONFIG)
        println(stderr, "[ERROR] DB_CONFIG is nothing in get_courses!")
        return (false, "Database not configured", [])
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/courses?programme=eq.$(HTTP.URIs.escapeuri(programme))&level=eq.$(HTTP.URIs.escapeuri(level))&semester=eq.$(HTTP.URIs.escapeuri(semester))"
        
        println(stderr, "DEBUG: Fetching courses from Supabase: $url")
        
        # Use curl command as a list to properly escape
        cmd = Cmd([
            "curl", "-s", 
            "-H", "apikey: $(DB_CONFIG.service_role_key)",
            "-H", "Authorization: Bearer $(DB_CONFIG.service_role_key)",
            url
        ])
        
        result = try
            read(cmd, String)
        catch e
            println(stderr, "[ERROR] curl error in get_courses: $(string(e))")
            return (false, "Error fetching courses: $(string(e))", [])
        end
        
        println(stderr, "DEBUG: Got curl response")
        
        if !isempty(result)
            try
                raw_data = JSON3.read(result, Vector)
                # Map lecturer_1,2,3 to lecturer1,2,3 for frontend compatibility
                data = [merge(course, Dict(
                    "lecturer1" => get(course, "lecturer_1", ""),
                    "lecturer2" => get(course, "lecturer_2", ""),
                    "lecturer3" => get(course, "lecturer_3", "")
                )) for course in raw_data]
                println(stderr, "DEBUG: Parsed $(length(data)) courses")
                return (true, "", data)
            catch
                # If it fails, it's likely an error object
                println(stderr, "[ERROR] Failed to parse courses as array. Raw result: $result")
                try
                    error_obj = JSON3.read(result, Dict)
                    if haskey(error_obj, "code")
                        # This is an error response
                        error_msg = get(error_obj, "message", get(error_obj, "detail", "Unknown error"))
                        println(stderr, "[ERROR] Supabase error: $(error_obj["code"]) - $error_msg")
                        return (true, "", [])  # Return empty array, treat as no data
                    end
                catch
                    # Couldn't parse at all
                    println(stderr, "[ERROR] Could not parse Supabase error response: $result")
                    return (false, "Invalid response from Supabase: $result", [])
                end
            end
        else
            println(stderr, "[ERROR] Empty response from Supabase in get_courses")
            return (false, "Empty response from Supabase", [])
        end
    catch e
        println(stderr, "DEBUG: Exception: $(string(e))")
        return (false, "Error fetching courses: $(string(e))", [])
    end
end

# ==================== TIMETABLE ====================

function delete_timetable_day(
    programme::AbstractString,
    level::AbstractString,
    semester::AbstractString,
    day_of_week::AbstractString
)::Tuple{Bool, String}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured")
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/timetable?programme=eq.$(HTTP.URIs.escapeuri(programme))&level=eq.$(HTTP.URIs.escapeuri(level))&semester=eq.$(HTTP.URIs.escapeuri(semester))&day_of_week=eq.$(HTTP.URIs.escapeuri(day_of_week))"
        
        println(stderr, "[DELETE_TIMETABLE_DAY] URL: $url")
        println(stderr, "[DELETE_TIMETABLE_DAY] Deleting timetable for: $programme/$level/$semester/$day_of_week")
        
        # Use curl for reliable HTTPS deletion with status code checking
        cmd = Cmd([
            "curl", "-s", "-w", "\n%{http_code}", "-X", "DELETE",
            "-H", "apikey: $(DB_CONFIG.service_role_key)",
            "-H", "Authorization: Bearer $(DB_CONFIG.service_role_key)",
            "-H", "Content-Type: application/json",
            url
        ])
        
        result = read(cmd, String)
        
        # Split response and status code
        lines = split(strip(result), "\n")
        status_code = parse(Int, lines[end])
        response_body = join(lines[1:end-1], "\n")
        
        println(stderr, "[DELETE_TIMETABLE_DAY] Status: $status_code")
        println(stderr, "[DELETE_TIMETABLE_DAY] Response: $response_body")
        
        if status_code in [200, 204]
            println(stderr, "[DELETE_TIMETABLE_DAY] ✓ Successfully deleted")
            return (true, "")
        else
            println(stderr, "[DELETE_TIMETABLE_DAY] ✗ Failed: $response_body")
            return (false, "Delete failed with status $status_code: $response_body")
        end
    catch e
        println(stderr, "[DELETE_TIMETABLE_DAY] Exception: $(string(e))")
        return (false, "Error deleting timetable day: $(string(e))")
    end
end

"""
    delete_timetable_slot(
        programme::AbstractString,
        level::AbstractString,
        semester::AbstractString,
        day_of_week::AbstractString,
        slot_index::Int
    )::Tuple{Bool, String}

Delete a specific timetable slot from Supabase.
"""
function delete_timetable_slot(
    programme::AbstractString,
    level::AbstractString,
    semester::AbstractString,
    day_of_week::AbstractString,
    slot_index::Int
)::Tuple{Bool, String}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured")
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/timetable?programme=eq.$(HTTP.URIs.escapeuri(programme))&level=eq.$(HTTP.URIs.escapeuri(level))&semester=eq.$(HTTP.URIs.escapeuri(semester))&day_of_week=eq.$(HTTP.URIs.escapeuri(day_of_week))&slot_index=eq.$slot_index"
        
        # Use curl for DELETE since HTTP.jl can have HTTPS issues
        cmd = Cmd([
            "curl", "-s", "-X", "DELETE",
            "-H", "apikey: $(DB_CONFIG.service_role_key)",
            "-H", "Authorization: Bearer $(DB_CONFIG.service_role_key)",
            "-H", "Content-Type: application/json",
            url
        ])
        
        result = read(cmd, String)
        
        # If curl succeeded (exit code 0), the delete was successful
        # Supabase returns empty body for successful DELETE
        return (true, "")
    catch e
        return (false, "Error deleting timetable slot: $(string(e))")
    end
end
function insert_timetable_slot(
    programme::AbstractString,
    level::AbstractString,
    semester::AbstractString,
    day_of_week::AbstractString,
    slot_index::Int,
    course_data::Dict
)::Tuple{Bool, String}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured")
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/timetable"
        headers = [
            "apikey" => DB_CONFIG.service_role_key,
            "Authorization" => "Bearer $(DB_CONFIG.service_role_key)",
            "Content-Type" => "application/json",
            "Prefer" => "return=minimal"
        ]
        
        body = Dict(
            "programme" => programme,
            "level" => level,
            "semester" => semester,
            "day_of_week" => day_of_week,
            "slot_index" => slot_index,
            "course_code" => get(course_data, "code", ""),
            "course_title" => get(course_data, "title", ""),
            "time" => get(course_data, "time", "08:00"),
            "duration" => parse(Float64, get(course_data, "duration", "1")),
            "venue" => get(course_data, "venue", ""),
            "lecturer" => get(course_data, "lecturer", "")
        )
        
        response = HTTP.post(
            url,
            headers,
            JSON3.write(body);
            status_exception=false,
            connect_timeout=10,
            readtimeout=10
        )
        
        if response.status in [200, 201]
            return (true, "")
        else
            body_str = String(response.body)
            return (false, "Database error: $body_str")
        end
    catch e
        return (false, "Error inserting timetable slot: $(string(e))")
    end
end

function get_timetable(
    programme::AbstractString,
    level::AbstractString,
    semester::AbstractString
)::Tuple{Bool, String, Vector}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured", [])
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/timetable?programme=eq.$(HTTP.URIs.escapeuri(programme))&level=eq.$(HTTP.URIs.escapeuri(level))&semester=eq.$(HTTP.URIs.escapeuri(semester))&order=day_of_week.asc,slot_index.asc"
        
        # Use curl since HTTP.jl hangs on HTTPS
        cmd = Cmd([
            "curl", "-s",
            "-H", "apikey: $(DB_CONFIG.service_role_key)",
            "-H", "Authorization: Bearer $(DB_CONFIG.service_role_key)",
            url
        ])
        result = read(cmd, String)
        
        if !isempty(result)
            data = JSON3.read(result, Vector)
            return (true, "", data)
        else
            return (false, "Empty response from Supabase", [])
        end
    catch e
        return (false, "Error fetching timetable: $(string(e))", [])
    end
end

"""
    get_timetable_slot_ids_for_day(
        programme::AbstractString,
        level::AbstractString,
        semester::AbstractString,
        day_of_week::AbstractString
    )::Tuple{Bool, String, Vector}

Get all slot IDs for a specific day to enable deletion by ID.
"""
function get_timetable_slot_ids_for_day(
    programme::AbstractString,
    level::AbstractString,
    semester::AbstractString,
    day_of_week::AbstractString
)::Tuple{Bool, String, Vector}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured", [])
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/timetable?programme=eq.$(HTTP.URIs.escapeuri(programme))&level=eq.$(HTTP.URIs.escapeuri(level))&semester=eq.$(HTTP.URIs.escapeuri(semester))&day_of_week=eq.$(HTTP.URIs.escapeuri(day_of_week))&order=slot_index.asc&select=id"
        
        println(stderr, "[GET_SLOT_IDS] Fetching IDs from Supabase")
        println(stderr, "[GET_SLOT_IDS] Programme: $programme, Level: $level, Semester: $semester, Day: $day_of_week")
        println(stderr, "[GET_SLOT_IDS] URL: $url")
        
        headers = [
            "apikey" => DB_CONFIG.service_role_key,
            "Authorization" => "Bearer $(DB_CONFIG.service_role_key)",
            "Content-Type" => "application/json"
        ]
        
        response = HTTP.get(
            url,
            headers;
            status_exception=false,
            connect_timeout=10,
            readtimeout=10
        )
        
        println(stderr, "[GET_SLOT_IDS] HTTP Status: $(response.status)")
        
        if response.status == 200
            result = String(response.body)
            println(stderr, "[GET_SLOT_IDS] Response body: $result")
            
            if !isempty(result)
                data = JSON3.read(result, Vector)
                println(stderr, "[GET_SLOT_IDS] ✓ Found $(length(data)) slot(s)")
                return (true, "", data)
            else
                println(stderr, "[GET_SLOT_IDS] ✗ Empty response")
                return (false, "Empty response from Supabase", [])
            end
        else
            error_body = String(response.body)
            println(stderr, "[GET_SLOT_IDS] ✗ HTTP $(response.status): $error_body")
            return (false, "HTTP $(response.status): $error_body", [])
        end
    catch e
        println(stderr, "[GET_SLOT_IDS] ✗ Exception: $(string(e))")
        return (false, "Error fetching slot IDs: $(string(e))", [])
    end
end

"""
    delete_timetable_slot_by_id(slot_id::Int)::Tuple{Bool, String}

Delete a specific timetable slot by its ID.
"""
function delete_timetable_slot_by_id(slot_id::Int)::Tuple{Bool, String}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured")
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/timetable?id=eq.$slot_id"
        
        println(stderr, "[DELETE_BY_ID] Deleting slot ID: $slot_id")
        println(stderr, "[DELETE_BY_ID] URL: $url")
        
        headers = [
            "apikey" => DB_CONFIG.service_role_key,
            "Authorization" => "Bearer $(DB_CONFIG.service_role_key)",
            "Content-Type" => "application/json"
        ]
        
        response = HTTP.delete(
            url,
            headers;
            status_exception=false,
            connect_timeout=10,
            readtimeout=10
        )
        
        status_code = response.status
        response_body = String(response.body)
        
        println(stderr, "[DELETE_BY_ID] HTTP Status: $status_code")
        println(stderr, "[DELETE_BY_ID] Response body: $response_body")
        
        if status_code in [200, 204]
            println(stderr, "[DELETE_BY_ID] ✓ Successfully deleted slot $slot_id")
            return (true, "")
        else
            println(stderr, "[DELETE_BY_ID] ✗ Delete failed with status $status_code")
            return (false, "Delete failed with status $status_code: $response_body")
        end
    catch e
        println(stderr, "[DELETE_BY_ID] ✗ Exception: $(string(e))")
        return (false, "Error deleting slot: $(string(e))")
    end
end

# ==================== NEWS ====================

function insert_news(
    programme::AbstractString,
    level::AbstractString,
    semester::AbstractString,
    title::AbstractString,
    content::AbstractString
)::Tuple{Bool, String}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured")
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/news"
        headers = [
            "apikey" => DB_CONFIG.service_role_key,
            "Authorization" => "Bearer $(DB_CONFIG.service_role_key)",
            "Content-Type" => "application/json",
            "Prefer" => "return=minimal"
        ]
        
        body = Dict(
            "programme" => programme,
            "level" => level,
            "semester" => semester,
            "title" => title,
            "content" => content
        )
        
        response = HTTP.post(
            url,
            headers,
            JSON3.write(body);
            status_exception=false,
            connect_timeout=10,
            readtimeout=10
        )
        
        if response.status in [200, 201]
            return (true, "")
        else
            body_str = String(response.body)
            return (false, "Database error: $body_str")
        end
    catch e
        return (false, "Error inserting news: $(string(e))")
    end
end

function get_news(
    programme::AbstractString="All",
    level::AbstractString="All",
    semester::AbstractString="All"
)::Tuple{Bool, String, Vector}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured", [])
    end
    
    try
        query_parts = []
        if programme != "All"
            push!(query_parts, "programme=eq.$(HTTP.URIs.escapeuri(programme))")
        end
        if level != "All"
            push!(query_parts, "level=eq.$(HTTP.URIs.escapeuri(level))")
        end
        if semester != "All"
            push!(query_parts, "semester=eq.$(HTTP.URIs.escapeuri(semester))")
        end
        # Build query string with correct ?/& logic
        query_string = isempty(query_parts) ? "" : "?" * join(query_parts, "&")
        if isempty(query_string)
            url = "$(DB_CONFIG.url)/rest/v1/news?order=created_at.desc"
        else
            url = "$(DB_CONFIG.url)/rest/v1/news$query_string&order=created_at.desc"
        end
        # Use curl since HTTP.jl hangs on HTTPS
        cmd = Cmd([
            "curl", "-s",
            "-H", "apikey: $(DB_CONFIG.service_role_key)",
            "-H", "Authorization: Bearer $(DB_CONFIG.service_role_key)",
            url
        ])
        result = read(cmd, String)
        
        if !isempty(result)
            try
                # Try to parse as array first
                data = JSON3.read(result, Vector)
                return (true, "", data)
            catch
                # If it fails, it's likely an error object
                try
                    error_obj = JSON3.read(result, Dict)
                    if haskey(error_obj, "code")
                        # This is an error response
                        error_msg = get(error_obj, "message", get(error_obj, "detail", "Unknown error"))
                        @warn "Supabase error: $(error_obj["code"]) - $error_msg"
                        return (true, "", [])  # Return empty array, treat as no data
                    end
                catch
                    # Couldn't parse at all
                    return (false, "Invalid response from Supabase: $result", [])
                end
            end
        else
            return (false, "Empty response from Supabase", [])
        end
    catch e
        return (false, "Error fetching news: $(string(e))", [])
    end
end

# ==================== MATERIALS METADATA ====================

function insert_material_metadata(
    programme::AbstractString,
    level::AbstractString,
    semester::AbstractString,
    course_code::AbstractString,
    material_name::AbstractString,
    material_type::AbstractString,
    storage_path::AbstractString
)::Tuple{Bool, String}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured")
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/materials"
        headers = [
            "apikey" => DB_CONFIG.service_role_key,
            "Authorization" => "Bearer $(DB_CONFIG.service_role_key)",
            "Content-Type" => "application/json",
            "Prefer" => "return=minimal"
        ]
        
        body = Dict(
            "programme" => programme,
            "level" => level,
            "semester" => semester,
            "course_code" => course_code,
            "material_name" => material_name,
            "material_type" => material_type,
            "storage_path" => storage_path
        )
        
        response = HTTP.post(
            url,
            headers,
            JSON3.write(body);
            status_exception=false,
            connect_timeout=10,
            readtimeout=10
        )
        
        if response.status in [200, 201]
            return (true, "")
        else
            body_str = String(response.body)
            return (false, "Database error: $body_str")
        end
    catch e
        return (false, "Error inserting material metadata: $(string(e))")
    end
end

function get_materials(
    programme::AbstractString,
    level::AbstractString,
    semester::AbstractString
)::Tuple{Bool, String, Vector}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured", [])
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/materials?programme=eq.$(HTTP.URIs.escapeuri(programme))&level=eq.$(HTTP.URIs.escapeuri(level))&semester=eq.$(HTTP.URIs.escapeuri(semester))"
        
        # Use curl since HTTP.jl hangs on HTTPS
        cmd = Cmd([
            "curl", "-s",
            "-H", "apikey: $(DB_CONFIG.service_role_key)",
            "-H", "Authorization: Bearer $(DB_CONFIG.service_role_key)",
            url
        ])
        result = read(cmd, String)
        
        if !isempty(result)
            data = JSON3.read(result, Vector)
            return (true, "", data)
        else
            return (false, "Empty response from Supabase", [])
        end
    catch e
        return (false, "Error fetching materials: $(string(e))", [])
    end
end

"""
    get_student_profile(user_id::AbstractString)

Fetch student profile from the profiles table using user UUID.

Returns: (success::Bool, error::String, profile::Dict)
"""
function get_student_profile(user_id::AbstractString)::Tuple{Bool, String, Dict}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured", Dict())
    end
    
    if isempty(user_id)
        return (false, "User ID is required", Dict())
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/profiles?id=eq.$(HTTP.URIs.escapeuri(user_id))"
        
        # Use curl since HTTP.jl hangs on HTTPS
        cmd = Cmd([
            "curl", "-s",
            "-H", "apikey: $(DB_CONFIG.service_role_key)",
            "-H", "Authorization: Bearer $(DB_CONFIG.service_role_key)",
            url
        ])
        result = read(cmd, String)
        
        if !isempty(result)
            try
                data = JSON3.read(result, Vector)
                if !isempty(data)
                    profile = data[1]  # Get first (and only) result
                    return (true, "", profile)
                else
                    return (false, "Profile not found", Dict())
                end
            catch e
                return (false, "Error parsing response: $(string(e))", Dict())
            end
        else
            return (false, "Empty response from Supabase", Dict())
        end
    catch e
        return (false, "Error fetching profile: $(string(e))", Dict())
    end
end

"""
    get_student_by_email(email::AbstractString)

Fetch student profile from the profiles table by email address.

Returns: (success::Bool, error::String, profile::Dict)
"""
function get_student_by_email(email::AbstractString)::Tuple{Bool, String, Dict}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured", Dict())
    end
    
    if isempty(email)
        return (false, "Email is required", Dict())
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/profiles?email=eq.$(HTTP.URIs.escapeuri(email))"
        
        # Use curl since HTTP.jl hangs on HTTPS
        cmd = Cmd([
            "curl", "-s",
            "-H", "apikey: $(DB_CONFIG.service_role_key)",
            "-H", "Authorization: Bearer $(DB_CONFIG.service_role_key)",
            url
        ])
        result = read(cmd, String)
        
        if !isempty(result)
            try
                data = JSON3.read(result, Vector)
                if !isempty(data)
                    profile = data[1]  # Get first (and only) result
                    return (true, "", profile)
                else
                    return (false, "User not found", Dict())
                end
            catch e
                return (false, "Error parsing response: $(string(e))", Dict())
            end
        else
            return (false, "Empty response from Supabase", Dict())
        end
    catch e
        return (false, "Error fetching profile: $(string(e))", Dict())
    end
end

"""
    check_duplicate_student(email::AbstractString, matric_no::AbstractString, phone::AbstractString)

Check if a student with given email, matric_no, or phone already exists.

Returns: (exists::Bool, error::String)
"""
function check_duplicate_student(email::AbstractString, matric_no::AbstractString, phone::AbstractString)::Tuple{Bool, String}
    
    if isnothing(DB_CONFIG)
        return (true, "Database not configured")
    end
    
    try
        # Build filter: check if email OR matric_no OR phone exists
        filters = []
        !isempty(email) && push!(filters, "email.eq.$(HTTP.URIs.escapeuri(email))")
        !isempty(matric_no) && push!(filters, "matric_no.eq.$(HTTP.URIs.escapeuri(matric_no))")
        !isempty(phone) && push!(filters, "phone.eq.$(HTTP.URIs.escapeuri(phone))")
        
        if isempty(filters)
            return (false, "")
        end
        
        filter_query = join(filters, ",or(")
        filter_query = "or(" * filter_query * ")"
        
        url = "$(DB_CONFIG.url)/rest/v1/profiles?$(filter_query)&limit=1"
        
        # Use curl
        cmd = Cmd([
            "curl", "-s",
            "-H", "apikey: $(DB_CONFIG.service_role_key)",
            "-H", "Authorization: Bearer $(DB_CONFIG.service_role_key)",
            url
        ])
        result = read(cmd, String)
        
        if !isempty(result)
            try
                data = JSON3.read(result, Vector)
                if !isempty(data)
                    return (true, "User already exists")
                else
                    return (false, "")
                end
            catch e
                return (false, "")
            end
        else
            return (false, "")
        end
    catch e
        return (false, "")
    end
end

"""
    create_student_profile(user_id, email, full_name, matric_no, programme, level, phone, password_hash, role)

Create a new student profile in the profiles table using service role key.
This bypasses RLS policies.

Returns: (success::Bool, error::String)
"""
function create_student_profile(
    user_id::AbstractString,
    email::AbstractString,
    full_name::AbstractString,
    matric_no::AbstractString,
    programme::AbstractString,
    level::AbstractString,
    phone::AbstractString,
    password_hash::AbstractString,
    role::AbstractString="student"
)::Tuple{Bool, String}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured")
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/profiles"
        
        # Prepare the JSON payload
        payload = JSON3.write(Dict(
            "id" => user_id,
            "email" => email,
            "full_name" => full_name,
            "matric_no" => matric_no,
            "programme" => programme,
            "level" => level,
            "phone" => phone,
            "password_hash" => password_hash,
            "role" => role
        ))
        
        # Use curl to POST
        cmd = Cmd([
            "curl", "-s", "-X", "POST",
            "-H", "apikey: $(DB_CONFIG.service_role_key)",
            "-H", "Authorization: Bearer $(DB_CONFIG.service_role_key)",
            "-H", "Content-Type: application/json",
            "-d", payload,
            url
        ])
        result = read(cmd, String)
        
        # Check for errors in response
        if contains(result, "\"code\"") || contains(result, "\"message\"")
            return (false, result)
        end
        
        return (true, "")
    catch e
        return (false, "Error creating profile: $(string(e))")
    end
end

"""
    update_student_profile(user_id, full_name, matric_no, programme, level, phone)

Update student profile details using service role key.

Returns: (success::Bool, error::String)
"""
function update_student_profile(
    user_id::AbstractString,
    full_name::AbstractString,
    matric_no::AbstractString,
    programme::AbstractString,
    level::AbstractString,
    phone::AbstractString
)::Tuple{Bool, String}
    
    if isnothing(DB_CONFIG)
        return (false, "Database not configured")
    end
    
    try
        url = "$(DB_CONFIG.url)/rest/v1/profiles?id=eq.$(HTTP.URIs.escapeuri(user_id))"
        
        # Prepare the JSON payload - only update non-empty fields
        update_dict = Dict()
        !isempty(full_name) && (update_dict["full_name"] = full_name)
        !isempty(matric_no) && (update_dict["matric_no"] = matric_no)
        !isempty(programme) && (update_dict["programme"] = programme)
        !isempty(level) && (update_dict["level"] = level)
        !isempty(phone) && (update_dict["phone"] = phone)
        
        if isempty(update_dict)
            return (false, "No fields to update")
        end
        
        payload = JSON3.write(update_dict)
        
        # Use curl to PATCH (for partial updates)
        cmd = Cmd([
            "curl", "-s", "-X", "PATCH",
            "-H", "apikey: $(DB_CONFIG.service_role_key)",
            "-H", "Authorization: Bearer $(DB_CONFIG.service_role_key)",
            "-H", "Content-Type: application/json",
            "-d", payload,
            url
        ])
        result = read(cmd, String)
        
        # Check for errors in response
        if contains(result, "\"code\"") || contains(result, "\"message\"")
            return (false, result)
        end
        
        return (true, "")
    catch e
        return (false, "Error updating profile: $(string(e))")
    end
end

end
