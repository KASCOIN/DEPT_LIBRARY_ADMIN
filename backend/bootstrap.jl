#!/usr/bin/env julia
# Production bootstrap.jl for Render deployment
# Run with: CMD ["julia", "--project=.", "bootstrap.jl"]

# Activate the project environment
using Pkg
Pkg.activate(@__DIR__)

# Load environment variables from ENV (no .env files in production)

# Set production environment if not already set
if !haskey(ENV, "GENIE_ENV")
    ENV["GENIE_ENV"] = "prod"
end

# Get port from ENV (Render sets this), default to 8000
const PORT = parse(Int, get(ENV, "PORT", "8000"))
const HOST = "0.0.0.0"

# Load Genie and application
using Genie
using Genie.AppServer

# Include app files in proper order
include(joinpath(@__DIR__, "config", "app.jl"))
include(joinpath(@__DIR__, "models.jl"))
include(joinpath(@__DIR__, "services", "supabase_service.jl"))
include(joinpath(@__DIR__, "services", "supabase_db_service.jl"))
include(joinpath(@__DIR__, "services", "auth_middleware.jl"))
include(joinpath(@__DIR__, "services", "active_student_service.jl"))
include(joinpath(@__DIR__, "services", "admin_service.jl"))
include(joinpath(@__DIR__, "controllers", "admin_controller.jl"))
include(joinpath(@__DIR__, "controllers", "student_controller.jl"))
include(joinpath(@__DIR__, "routes", "admin.jl"))
include(joinpath(@__DIR__, "routes", "student.jl"))

# Ensure data directories exist
AdminService.ensure_data_dirs()

# Configure static file serving
Genie.config.server_document_root = normpath(joinpath(@__DIR__, "..", "frontend"))

# CORS settings
Genie.config.cors_allowed_origins = ["*"]
Genie.config.cors_headers = Dict(
    "Access-Control-Allow-Headers" => "Content-Type",
    "Access-Control-Allow-Methods" => "GET, POST, PUT, DELETE, OPTIONS"
)

# Production server settings
Genie.config.run_as_server = true
Genie.config.server_host = HOST

# Startup log
println("="^60)
println("  Dept Library Admin - Production Server")
println("="^60)
println("  GENIE_ENV:    $(ENV["GENIE_ENV"])")
println("  HOST:         $HOST")
println("  PORT:         $PORT")
println("  Julia:        $(VERSION)")
println("  PID:          $(getpid())")
println("="^60)
println()

# Start the Genie HTTP server in blocking mode
try
    Genie.AppServer.startup(host=HOST, port=PORT, async=false)
catch e
    println("[!] Server error: $e")
    rethrow()
end

