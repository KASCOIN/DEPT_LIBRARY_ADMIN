using HTTP
using JSON3

# Direct test without any modules
supabase_url = "https://yecpwijvbiurqysxazva.supabase.co"
service_role_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXV0oiLCJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InllY3B3aWp2Yml1cnF5c3hhenZhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2Nzk1MzU3MywiZXhwIjoyMDgzNTI5NTczfQ.3t6LjSHcefYbbaBYSU3C3PShbVIqfvLbiCTSmeVKaHE"

println("Testing HTTP connection to Supabase...")
url = "$supabase_url/rest/v1/courses?programme=eq.Meteorology&level=eq.100&semester=eq.first-semester"
println("URL: $url")

headers = [
    "apikey" => service_role_key,
    "Authorization" => "Bearer $service_role_key",
    "Content-Type" => "application/json"
]

try
    println("Making request...")
    response = HTTP.get(url, headers; status_exception=false, connect_timeout=5, readtimeout=5)
    println("Response status: $(response.status)")
    println("Response body: $(String(response.body))")
catch e
    println("Error: $(string(e))")
    println("Exception type: $(typeof(e))")
end
