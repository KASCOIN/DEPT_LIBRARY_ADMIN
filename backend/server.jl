using Genie
using Genie.Router
using Genie.Renderer.Json
using Dates

include("config/app.jl")
include("models.jl")
include("services/supabase_service.jl")
include("services/supabase_db_service.jl")
include("services/auth_middleware.jl")
include("services/active_student_service.jl")
include("services/admin_service.jl")
include("controllers/admin_controller.jl")
include("controllers/student_controller.jl")
include("routes/admin.jl")
include("routes/student.jl")

AdminService.ensure_data_dirs()

# Log Supabase configuration status
if !isempty(get(ENV, "SUPABASE_URL", "")) && !isempty(get(ENV, "SUPABASE_SERVICE_ROLE_KEY", ""))
    println("[✓] Supabase Storage configured and enabled")
    println("[ℹ] Bucket: $(get(ENV, "SUPABASE_BUCKET", "materials"))")
else
    println("[!] Supabase Storage NOT configured. Set environment variables: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY")
    println("[!] See docs/SUPABASE_SETUP.md for configuration instructions")
end

# Serve static files from frontend directory
Genie.config.server_document_root = normpath(joinpath(@__DIR__, "..", "frontend"))

# CORS (version-safe)
Genie.config.cors_allowed_origins = ["*"]
Genie.config.cors_headers = Dict(
    "Access-Control-Allow-Headers" => "Content-Type",
    "Access-Control-Allow-Methods" => "GET, POST, PUT, DELETE, OPTIONS"
)

Genie.config.run_as_server = true
Genie.config.server_host = "0.0.0.0"

println("\n[✓] Web Server starting at http://0.0.0.0:8000 - press Ctrl/Cmd+C to stop the server.")
println("[✓] Open admin panel: http://127.0.0.1:8000/admin.html\n")

# Start the server and keep it running
try
    up(8000; async=false)
catch e
    @error "Server error: $e"
    rethrow()
end
