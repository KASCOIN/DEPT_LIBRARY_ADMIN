# App configuration
module AppConfig

const PORT = 8000
const HOST = "127.0.0.1"
const DATA_DIR = joinpath(@__DIR__, "..", "data")
const UPLOAD_DIR = joinpath(DATA_DIR, "uploads")  # Deprecated: files now in B2

# ==================== BACKBLAZE B2 OBJECT STORAGE CONFIGURATION ====================
# Supports loading a local `.env` file into ENV for convenience during
# development. Production deployments should still set environment variables
# securely (systemd, Docker, CI, etc.).

# Try to load a .env file from likely locations (repo root, backend dir)
function _load_dotenv_if_present()
    candidates = [
        joinpath(@__DIR__, "..", "..", ".env"),
        joinpath(@__DIR__, "..", ".env"),
        joinpath(@__DIR__, ".env")
    ]

    for path in candidates
        try
            if isfile(path)
                raw = read(path, String)
                for line in split(raw, '\n')
                    s = strip(line)
                    # skip comments and empty lines
                    if isempty(s) || startswith(s, "#")
                        continue
                    end
                    # parse KEY=VALUE pairs
                    # support lines starting with `export ` (common in shell-style .env)
                    if startswith(s, "export ")
                        s = strip(s[8:end])
                    end

                    if occursin('=', s)
                        parts = split(s, '=', limit=2)
                        key = strip(parts[1])
                        val = strip(parts[2])
                        # remove surrounding quotes if present
                        if startswith(val, '"') && endswith(val, '"')
                            val = val[2:end-1]
                        elseif startswith(val, '\'') && endswith(val, '\'')
                            val = val[2:end-1]
                        end
                        # Only set ENV if not already present (allow env override)
                        if !haskey(ENV, key)
                            ENV[key] = val
                        end
                    end
                end
                @info "Loaded environment variables from $path"
                return
            end
        catch e
            @warn "Failed to load .env file at $path: $(string(e))"
        end
    end
end

# Load .env if available
_load_dotenv_if_present()

# All credentials must be provided via environment variables
# DO NOT hard-code secrets - always use ENV

"""
    get_supabase_config()::Union{Dict, Nothing}

Loads Supabase Storage configuration from environment variables.
Returns a Dict with credentials, or Nothing if not configured.

Required environment variables:
- SUPABASE_URL: Supabase project URL
- SUPABASE_SERVICE_ROLE_KEY: Service role API key (backend-only)
- SUPABASE_BUCKET: Storage bucket name (default: materials)

Returns: Dict with keys (url, service_role_key, bucket) or Nothing
"""
function get_supabase_config()::Union{Dict, Nothing}
    required_vars = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"]
    
    # Check if required variables are set
    missing_vars = filter(var -> !haskey(ENV, var), required_vars)
    
    if !isempty(missing_vars)
        @warn "Supabase Storage not configured. Missing: $(join(missing_vars, ", "))"
        return nothing
    end
    
    return Dict(
        "url" => ENV["SUPABASE_URL"],
        "service_role_key" => ENV["SUPABASE_SERVICE_ROLE_KEY"],
        "bucket" => get(ENV, "SUPABASE_BUCKET", "materials")
    )
end

# Check if Supabase Storage is available on startup
const SUPABASE_CONFIG = get_supabase_config()
const SUPABASE_ENABLED = !isnothing(SUPABASE_CONFIG)

end
