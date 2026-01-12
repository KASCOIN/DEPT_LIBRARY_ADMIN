using JSON3

db_config_service_role_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InllY3B3aWp2Yml1cnF5c3hhenZhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2Nzk1MzU3MywiZXhwIjoyMDgzNTI5NTczfQ.3t6LjSHcefYbbaBYSU3C3PShbVIqfvLbiCTSmeVKaHE"
url = "https://yecpwijvbiurqysxazva.supabase.co/rest/v1/courses?programme=eq.Meteorology&level=eq.100&semester=eq.first-semester"

cmd = Cmd([
    "curl", "-s", 
    "-H", "apikey: $db_config_service_role_key",
    "-H", "Authorization: Bearer $db_config_service_role_key",
    url
])

println("Running command...")
result = read(cmd, String)
println("Got result with $(length(result)) characters")

if !isempty(result)
    data = JSON3.read(result, Vector)
    println("Parsed $(length(data)) courses:")
    for course in data
        println("  - $(course["course_code"]): $(course["course_title"])")
    end
end
