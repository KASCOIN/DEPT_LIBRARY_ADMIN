#!/usr/bin/env julia

"""
Test script for deleting timetable by day
Tests the DELETE /api/admin/timetable/day endpoint
"""

using HTTP
using JSON3
using Base64

# Configuration
API_URL = "http://localhost:8000"
ADMIN_TOKEN = "test-admin-token"  # You may need to adjust this based on your auth setup

function test_delete_timetable_day()
    println("\n" * "="^60)
    println("Testing DELETE /api/admin/timetable/day")
    println("="^60)
    
    # Test payload
    payload = Dict(
        "programme" => "BSc Computer Science",
        "level" => "100",
        "semester" => "first-semester",
        "day" => "Monday"
    )
    
    println("\nPayload:")
    println(JSON3.pretty(payload))
    
    # Make request
    endpoint = "$API_URL/api/admin/timetable/day"
    println("\nEndpoint: $endpoint")
    
    try
        headers = [
            "Content-Type" => "application/json",
            "Authorization" => "Bearer $ADMIN_TOKEN"
        ]
        
        response = HTTP.delete(
            endpoint,
            headers,
            body=JSON3.write(payload)
        )
        
        println("\nStatus Code: $(response.status)")
        println("Headers: $(response.headers)")
        
        body = String(response.body)
        println("\nResponse Body:")
        if !isempty(body)
            try
                data = JSON3.read(body)
                println(JSON3.pretty(data))
            catch
                println(body)
            end
        else
            println("(empty)")
        end
        
        if response.status in [200, 204]
            println("\n✓ DELETE request successful!")
            return true
        else
            println("\n✗ DELETE request failed with status $(response.status)")
            return false
        end
        
    catch e
        println("\n✗ Error: $(string(e))")
        return false
    end
end

function test_get_and_delete_cycle()
    println("\n" * "="^60)
    println("Testing GET and DELETE cycle")
    println("="^60)
    
    # First, let's get the current timetable data
    println("\n1. Getting timetable data...")
    
    endpoint = "$API_URL/api/admin/timetable"
    query_params = Dict(
        "programme" => "BSc Computer Science",
        "level" => "100",
        "semester" => "first-semester",
        "day" => "Monday"
    )
    
    try
        uri = HTTP.URI(endpoint; query=query_params)
        response = HTTP.get(uri)
        
        body = String(response.body)
        if !isempty(body)
            data = JSON3.read(body)
            println("Found timetable entries:")
            println(JSON3.pretty(data))
            
            if !isempty(data)
                println("\n2. Now attempting to delete Monday's timetable...")
                return test_delete_timetable_day()
            else
                println("No timetable entries found for Monday")
                return true
            end
        end
    catch e
        println("Error fetching timetable: $(string(e))")
        return false
    end
end

# Run tests
if isinteractive()
    println("Interactive mode - run test functions manually:")
    println("  test_delete_timetable_day()")
    println("  test_get_and_delete_cycle()")
else
    # Run all tests
    success = true
    success &= test_delete_timetable_day()
    
    # Uncomment to test the full cycle:
    # success &= test_get_and_delete_cycle()
    
    if success
        println("\n" * "="^60)
        println("All tests passed!")
        println("="^60)
        exit(0)
    else
        println("\n" * "="^60)
        println("Some tests failed!")
        println("="^60)
        exit(1)
    end
end
