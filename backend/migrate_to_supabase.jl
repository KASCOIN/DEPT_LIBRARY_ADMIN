"""
Migration Script: JSON → Supabase Database

This script migrates all data from local JSON files to Supabase PostgreSQL tables.
Run this once when you're ready to switch to the database backend.

Usage:
    julia migrate_to_supabase.jl

Prerequisites:
- All Supabase tables created (courses, timetable, materials, news)
- SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY set in .env
- Local JSON files exist in backend/data/
"""

# Load configuration
include("config/app.jl")
include("services/supabase_db_service.jl")

using ..AppConfig
using ..SupabaseDbService
using JSON3

function migrate_courses()
    println("\n📚 Migrating courses...")
    courses_file = joinpath(AppConfig.DATA_DIR, "courses.json")
    
    if !isfile(courses_file)
        println("  ⚠️  No courses.json found")
        return
    end
    
    raw = read(courses_file, String)
    data = try
        JSON3.read(raw, Vector{Dict{String,Any}})
    catch
        []
    end
    
    count = 0
    for entry in data
        programme = get(entry, "programme", "Unknown")
        level = get(entry, "level", "Unknown")
        semester = get(entry, "semester", "first-semester")
        advisor = get(entry, "advisor", "")
        courses = get(entry, "courses", [])
        
        for course in courses
            course_code = get(course, "code", "")
            course_title = get(course, "title", "")
            
            if !isempty(course_code)
                success, msg = SupabaseDbService.insert_course(
                    programme, level, semester, course_code, course_title, advisor
                )
                if success
                    count += 1
                    println("  ✓ Migrated course: $programme - $level - $course_code")
                else
                    println("  ✗ Error: $msg")
                end
            end
        end
    end
    
    println("  ✓ Migrated $count courses")
end

function migrate_timetable()
    println("\n🕐 Migrating timetable...")
    timetable_file = joinpath(AppConfig.DATA_DIR, "timetable.json")
    
    if !isfile(timetable_file)
        println("  ⚠️  No timetable.json found")
        return
    end
    
    raw = read(timetable_file, String)
    data = try
        JSON3.read(raw, Vector{Dict{String,Any}})
    catch
        []
    end
    
    count = 0
    for entry in data
        programme = get(entry, "programme", "Unknown")
        level = get(entry, "level", "Unknown")
        semester = get(entry, "semester", "first-semester")
        days = get(entry, "days", Dict{String,Any}())
        
        for (day, slots) in days
            if isa(slots, Vector)
                for (slot_index, slot) in enumerate(slots)
                    if isa(slot, Dict) && !isempty(get(slot, "code", ""))
                        success, msg = SupabaseDbService.insert_timetable_slot(
                            programme, level, semester, day, slot_index, slot
                        )
                        if success
                            count += 1
                            println("  ✓ Migrated slot: $programme - $level - $day - Slot $slot_index")
                        else
                            println("  ✗ Error: $msg")
                        end
                    end
                end
            end
        end
    end
    
    println("  ✓ Migrated $count timetable slots")
end

function migrate_news()
    println("\n📰 Migrating news...")
    news_file = joinpath(AppConfig.DATA_DIR, "news.json")
    
    if !isfile(news_file)
        println("  ⚠️  No news.json found")
        return
    end
    
    raw = read(news_file, String)
    data = try
        JSON3.read(raw, Vector{Dict{String,Any}})
    catch
        []
    end
    
    count = 0
    for entry in data
        programme = get(entry, "programme", "All")
        level = get(entry, "level", "All")
        semester = get(entry, "semester", "first-semester")
        title = get(entry, "title", "")
        body = get(entry, "body", "")
        
        if !isempty(title) && !isempty(body)
            success, msg = SupabaseDbService.insert_news(
                programme, level, semester, title, body
            )
            if success
                count += 1
                println("  ✓ Migrated news: $title")
            else
                println("  ✗ Error: $msg")
            end
        end
    end
    
    println("  ✓ Migrated $count news items")
end

function migrate_materials_metadata()
    println("\n📄 Migrating materials metadata...")
    materials_file = joinpath(AppConfig.DATA_DIR, "materials_metadata.json")
    
    if !isfile(materials_file)
        println("  ⚠️  No materials_metadata.json found")
        return
    end
    
    raw = read(materials_file, String)
    data = try
        JSON3.read(raw, Vector{Dict{String,Any}})
    catch
        []
    end
    
    count = 0
    for entry in data
        programme = get(entry, "programme", "Unknown")
        level = get(entry, "level", "Unknown")
        semester = get(entry, "semester", "first-semester")
        course_code = get(entry, "course_code", "")
        material_name = get(entry, "material_name", "")
        material_type = get(entry, "material_type", "general")
        storage_path = get(entry, "storage_path", "")
        
        if !isempty(course_code) && !isempty(storage_path)
            success, msg = SupabaseDbService.insert_material_metadata(
                programme, level, semester, course_code, material_name, material_type, storage_path
            )
            if success
                count += 1
                println("  ✓ Migrated material: $course_code - $material_name")
            else
                println("  ✗ Error: $msg")
            end
        end
    end
    
    println("  ✓ Migrated $count material metadata entries")
end

# Main migration
println("=" ^ 60)
println("🔄 SUPABASE DATABASE MIGRATION")
println("=" ^ 60)
println("\nThis will migrate all data from JSON files to Supabase database.")
println("Make sure:")
println("  1. Supabase tables are created (courses, timetable, news, materials)")
println("  2. SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are in .env")
println("  3. You have backups of your data")

print("\nContinue? (yes/no): ")
flush(stdout)
response = readline()

if lowercase(strip(response)) == "yes"
    migrate_courses()
    migrate_timetable()
    migrate_news()
    migrate_materials_metadata()
    
    println("\n" * "=" ^ 60)
    println("✅ MIGRATION COMPLETE")
    println("=" ^ 60)
    println("\nNext steps:")
    println("  1. Restart the server: julia server.jl")
    println("  2. Test the app to ensure everything works")
    println("  3. You can keep the JSON files as backup or delete them")
else
    println("Migration cancelled.")
end
