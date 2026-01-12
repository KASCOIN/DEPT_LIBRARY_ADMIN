#!/usr/bin/env julia

"""
Test script to debug delete functionality
This script tests if we can actually connect to Supabase and delete records
"""

using HTTP
using JSON3
using Dates

# Load environment
include("backend/services/supabase_db_service.jl")

println("\n" * "="^70)
println("SUPABASE DELETE DEBUG TEST")
println("="^70)

# Check DB config
if isnothing(SupabaseDbService.DB_CONFIG)
    println("\n❌ ERROR: DB_CONFIG is not initialized!")
    println("This means the backend hasn't loaded the Supabase configuration yet.")
    exit(1)
else
    println("\n✓ DB_CONFIG loaded")
    println("  URL: $(SupabaseDbService.DB_CONFIG.url)")
end

# Test 1: Try to get ANY timetable record
println("\n" * "-"^70)
println("TEST 1: Fetch any timetable record")
println("-"^70)

try
    url = "$(SupabaseDbService.DB_CONFIG.url)/rest/v1/timetable?limit=1&select=id,programme,level,semester,day_of_week"
    
    headers = [
        "apikey" => SupabaseDbService.DB_CONFIG.service_role_key,
        "Authorization" => "Bearer $(SupabaseDbService.DB_CONFIG.service_role_key)",
        "Content-Type" => "application/json"
    ]
    
    response = HTTP.get(
        url,
        headers;
        status_exception=false,
        connect_timeout=10,
        readtimeout=10
    )
    
    println("Status: $(response.status)")
    
    if response.status == 200
        body = String(response.body)
        println("Response: $body")
        
        if !isempty(body)
            data = JSON3.read(body, Vector)
            if !isempty(data)
                record = data[1]
                println("\n✓ Found a timetable record:")
                println("  ID: $(get(record, "id", "?"))")
                println("  Programme: $(get(record, "programme", "?"))")
                println("  Level: $(get(record, "level", "?"))")
                println("  Day: $(get(record, "day_of_week", "?"))")
                
                # Test 2: Try to delete this record
                println("\n" * "-"^70)
                println("TEST 2: Attempt to delete this record")
                println("-"^70)
                
                slot_id = get(record, "id", nothing)
                if !isnothing(slot_id)
                    slot_id_int = isa(slot_id, Int) ? slot_id : Int(parse(Float64, string(slot_id)))
                    
                    delete_url = "$(SupabaseDbService.DB_CONFIG.url)/rest/v1/timetable?id=eq.$slot_id_int"
                    println("Delete URL: $delete_url")
                    
                    delete_response = HTTP.delete(
                        delete_url,
                        headers;
                        status_exception=false,
                        connect_timeout=10,
                        readtimeout=10
                    )
                    
                    println("Delete Status: $(delete_response.status)")
                    delete_body = String(delete_response.body)
                    println("Delete Response: $(isempty(delete_body) ? "(empty)" : delete_body)")
                    
                    if delete_response.status in [200, 204]
                        println("\n✓ Record deleted successfully!")
                        
                        # Verify it's deleted
                        println("\nVERIFICATION: Checking if record still exists...")
                        verify_url = "$(SupabaseDbService.DB_CONFIG.url)/rest/v1/timetable?id=eq.$slot_id_int"
                        verify_response = HTTP.get(
                            verify_url,
                            headers;
                            status_exception=false,
                            connect_timeout=10,
                            readtimeout=10
                        )
                        
                        verify_body = String(verify_response.body)
                        println("Verification response: $verify_body")
                        
                        if verify_body == "[]"
                            println("✓✓✓ Record confirmed deleted!")
                        else
                            println("❌ Record still exists after delete!")
                        end
                    else
                        println("❌ Delete failed with status $(delete_response.status)")
                    end
                end
            else
                println("⚠ No records found in timetable")
            end
        else
            println("⚠ Empty response body")
        end
    else
        println("❌ HTTP error: $(response.status)")
        println("Response: $(String(response.body))")
    end
    
catch e
    println("❌ Error: $(string(e))")
    println("Stack trace:")
    showerror(stderr, e, catch_backtrace())
end

println("\n" * "="^70)
println("END OF DEBUG TEST")
println("="^70 * "\n")
