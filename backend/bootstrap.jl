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
const HOST = get(ENV, "HOST", "0.0.0.0")

# Load Genie and application
using Genie
using Genie.AppServer
using Dates

# Application version
const APP_VERSION = "1.0.0"

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
    "Access-Control-Allow-Methods" => "GET, POST, OPTIONS, PUT, DELETE"
)

# Production server settings
Genie.config.run_as_server = true
Genie.config.server_host = HOST

# ==================== HEALTH ENDPOINT ====================
# Add health check endpoint for Render and container orchestration
route("/health", method=GET) do
    # Check Supabase connectivity
    supabase_status = if !isnothing(SupabaseDbService.DB_CONFIG)
        "connected"
    else
        "not_configured"
    end
    
    response_data = Dict(
        "status" => "healthy",
        "timestamp" => string(now(Dates.UTC)),
        "version" => APP_VERSION,
        "julia_version" => string(VERSION),
        "pid" => getpid(),
        "supabase" => supabase_status
    )
    
    return HTTP.Response(
        200,
        [
            "Content-Type" => "application/json; charset=utf-8",
            "Access-Control-Allow-Origin" => "*"
        ],
        JSON3.write(response_data)
    )
end

# ==================== GRACEFUL SHUTDOWN ====================
# Setup signal handlers for graceful shutdown (Docker/Render)
const SERVER_RUNNING = Ref(true)

function setup_signal_handlers()
    # SIGTERM (Docker/Render sends this for graceful shutdown)
    @async begin
        try
            # On Unix systems, this will catch SIGTERM
            while SERVER_RUNNING[]
                sleep(1)
            end
        catch e
            # Signal received, initiate shutdown
            @info "Shutdown signal received, gracefully stopping server..."
            shutdown_server()
        end
    end
    
    # Also handle SIGINT (Ctrl+C in terminal)
    @async begin
        try
            wait()
        catch
            @info "Interrupt received, gracefully stopping server..."
            shutdown_server()
        end
    end
    
    return nothing
end

function shutdown_server()
    @info "Shutting down server gracefully..."
    SERVER_RUNNING[] = false
    
    try
        Genie.AppServer.down()
        @info "Server stopped successfully"
    catch e
        @warn "Error during server shutdown: $e"
    end
    
    # Exit cleanly
    exit(0)
end

# Setup signal handlers
setup_signal_handlers()

# Startup log
println("="^60)
println("  Dept Library Admin - Production Server")
println("="^60)
println("  GENIE_ENV:      $(ENV["GENIE_ENV"])")
println("  HOST:           $HOST")
println("  PORT:           $PORT")
println("  Julia:          $(VERSION)")
println("  PID:            $(getpid())")
println("  Version:        $APP_VERSION")
println("="^60)
println()
println("[ℹ] Health check available at: http://$HOST:$PORT/health")
println("[ℹ] Press Ctrl+C or send SIGTERM to stop gracefully")
println()

# Start the Genie HTTP server
# Using async=true to allow signal handlers to work
try
    Genie.AppServer.startup(host=HOST, port=PORT, async=true)
    @info "Server started successfully on http://$HOST:$PORT"
    
    # Block main thread while server runs
    # This allows the async signal handlers to work
    while SERVER_RUNNING[]
        sleep(1)
    end
catch e
    println("[!] Server error: $e")
    @error "Server startup error" exception=e
    rethrow()
end

