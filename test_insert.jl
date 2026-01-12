using HTTP
using JSON3

supabase_url = "https://yecpwijvbiurqysxazva.supabase.co"
service_role_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InllY3B3aWp2Yml1cnF5c3hhenZhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2Nzk1MzU3MywiZXhwIjoyMDgzNTI5NTczfQ.3t6LjSHcefYbbaBYSU3C3PShbVIqfvLbiCTSmeVKaHE"

url = "$supabase_url/rest/v1/courses"

headers = [
    "apikey" => service_role_key,
    "Authorization" => "Bearer $service_role_key",
    "Content-Type" => "application/json"
]

body = Dict(
    "programme" => "Meteorology",
    "level" => "100",
    "semester" => "first-semester",
    "course_code" => "MET101",
    "course_title" => "Test Course",
    "advisor" => "Prof. Smith"
)

println("Posting to Supabase...")
try
    response = HTTP.post(url, headers, JSON3.write(body); status_exception=false)
    println("Status: $(response.status)")
    println("Body: $(String(response.body))")
catch e
    println("Error: $(string(e))")
end
