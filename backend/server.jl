using Genie
using Genie.Router
using Genie.Renderer.Json
using Dates

# Load environment variables from .env file
dotenv_path = normpath(joinpath(@__DIR__, "..", ".env"))
if isfile(dotenv_path)
    # Parse and load .env file
    open(dotenv_path) do f
        for line in readlines(f)
            line = strip(line)
            # Skip comments and empty lines
            if !startswith(line, "#") && !isempty(line) && !startswith(line, "export")
                # Remove 'export ' prefix if present
                line = replace(line, r"^export\s+" => "")
                if contains(line, "=")
                    parts = split(line, "="; limit=2)
                    if length(parts) == 2
                        key = strip(parts[1])
                        value = strip(parts[2], ['"', '\''])
                        ENV[key] = value
                    end
                end
            end
        end
    end
    println("[✓] Loaded environment variables from .env")
end

include("config/app.jl")
include("models.jl")
include("services/supabase_service.jl")
include("services/supabase_db_service.jl")
include("services/auth_middleware.jl")
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
up(8000)
