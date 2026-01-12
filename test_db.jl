using Pkg
Pkg.activate("./backend")

# Load environment variables
dotenv_path = ".env"
if isfile(dotenv_path)
    open(dotenv_path) do f
        for line in readlines(f)
            line = strip(line)
            if !startswith(line, "#") && !isempty(line) && !startswith(line, "export")
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
end

include("backend/services/supabase_db_service.jl")

println("Database config: ", SupabaseDbService.DB_CONFIG)

if !isnothing(SupabaseDbService.DB_CONFIG)
    println("\nTesting get_courses...")
    success, msg, data = SupabaseDbService.get_courses("Meteorology", "100", "first-semester")
    println("Success: $success")
    println("Message: $msg")
    println("Data: $data")
end
