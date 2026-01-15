"""
    active_student_service.jl
    
Manages active student tracking by updating last_seen timestamp in the database.
Allows querying of active students based on a configurable time window.

Features:
- Update student last_seen timestamp on API activity
- Query active students within a time window
- Configurable activity window (default 5 minutes)
- No in-memory state or local storage - all data persisted in Supabase
"""

module ActiveStudentService

using Dates
using HTTP
using JSON3
using ..SupabaseDbService

# Configuration
const ACTIVE_WINDOW_MINUTES = 5  # Students active within last 5 minutes

"""
    update_last_seen(user_id::String)

Update the last_seen timestamp for a student.
Called on every authenticated student API request.

Args:
    user_id: UUID of the student

Returns:
    Tuple: (success::Bool, error::String)
"""
function update_last_seen(user_id::String)
    try
        if isempty(user_id)
            return (false, "user_id is required")
        end
        
        # Update last_seen in Supabase using curl (more reliable for HTTPS)
        supabase_url = get(ENV, "SUPABASE_URL", "")
        service_role_key = get(ENV, "SUPABASE_SERVICE_ROLE_KEY", "")
        
        if isempty(supabase_url) || isempty(service_role_key)
            @warn "Supabase not configured for last_seen update"
            return (false, "Supabase not configured")
        end
        
        # Build request to update profile
        url = "$(supabase_url)/rest/v1/profiles?id=eq.$(user_id)"
        
        # Create JSON payload
        body = JSON3.write(Dict(
            "last_seen" => string(Dates.now(Dates.UTC))
        ))
        
        # Use curl since HTTP.jl can hang on HTTPS connections
        cmd = Cmd([
            "curl", "-s", "-X", "PATCH",
            "-H", "apikey: $service_role_key",
            "-H", "Authorization: Bearer $service_role_key",
            "-H", "Content-Type: application/json",
            "-d", body,
            url
        ])
        
        result = read(cmd, String)
        
        # Check for curl errors (non-zero exit code handled by read)
        # Supabase returns 204 No Content on successful PATCH
        @debug "Updated last_seen for user: $user_id"
        return (true, "")
        
    catch e
        @error "Error updating last_seen for $user_id: $e"
        return (false, string(e))
    end
end

"""
    get_active_students(minutes::Int=ACTIVE_WINDOW_MINUTES)

Query active students from the database.
Returns students seen within the specified time window.

Args:
    minutes: Time window in minutes (default 5)

Returns:
    Tuple: (success::Bool, students::Vector{Dict}, error::String)
"""
function get_active_students(minutes::Int=ACTIVE_WINDOW_MINUTES)
    try
        supabase_url = get(ENV, "SUPABASE_URL", "")
        service_role_key = get(ENV, "SUPABASE_SERVICE_ROLE_KEY", "")
        
        if isempty(supabase_url) || isempty(service_role_key)
            @warn "Supabase not configured"
            return (false, [], "Supabase not configured")
        end
        
        # Calculate cutoff time: now minus X minutes
        cutoff_time = Dates.now(Dates.UTC) - Dates.Minute(minutes)
        
        # Query active students using curl
        # Select: id, email, full_name, matric_no, programme, level, last_seen
        # Where: last_seen >= cutoff_time AND role = 'student'
        # Order by: last_seen DESC
        
        query_params = [
            "select=id,email,full_name,matric_no,programme,level,last_seen,role",
            "role=eq.student",
            "last_seen=gte.$(HTTP.escapeuri(string(cutoff_time)))",
            "order=last_seen.desc"
        ]
        
        url = "$(supabase_url)/rest/v1/profiles?" * join(query_params, "&")
        
        # Use curl for reliable HTTPS
        cmd = Cmd([
            "curl", "-s",
            "-H", "apikey: $service_role_key",
            "-H", "Authorization: Bearer $service_role_key",
            url
        ])
        
        result = read(cmd, String)
        
        if !isempty(result)
            try
                students = JSON3.read(result, Vector{Dict{String,Any}})
                @info "Retrieved $(length(students)) active students"
                return (true, students, "")
            catch e
                @warn "Failed to parse active students response: $e"
                return (false, [], "Parse error: $(string(e))")
            end
        else
            @info "No active students found"
            return (true, [], "")
        end
        
    catch e
        @error "Error fetching active students: $e"
        return (false, [], string(e))
    end
end

"""
    get_active_count(minutes::Int=ACTIVE_WINDOW_MINUTES)

Get count of active students.

Args:
    minutes: Time window in minutes (default 5)

Returns:
    Int: Count of active students
"""
function get_active_count(minutes::Int=ACTIVE_WINDOW_MINUTES)
    success, students, _ = get_active_students(minutes)
    return success ? length(students) : 0
end

"""
    format_active_student(student::Dict)

Format student data for API response.

Args:
    student: Raw student dict from database

Returns:
    Dict: Formatted student data
"""
function format_active_student(student::Dict)
    return Dict(
        "id" => get(student, "id", ""),
        "email" => get(student, "email", "Unknown"),
        "full_name" => get(student, "full_name", ""),
        "matric_no" => get(student, "matric_no", ""),
        "programme" => get(student, "programme", ""),
        "level" => get(student, "level", ""),
        "last_seen" => get(student, "last_seen", ""),
        "status" => "active"
    )
end

end  # module ActiveStudentService
