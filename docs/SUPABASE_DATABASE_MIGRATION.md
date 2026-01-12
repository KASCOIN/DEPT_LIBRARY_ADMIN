# Supabase Database Migration Guide

## Overview

Your application now supports storing data in **Supabase PostgreSQL** instead of local JSON files. This is essential for deploying on Render (or any cloud platform) because Render's filesystem is ephemeral—local files get deleted on every restart.

## What Changed

### Before (Local JSON)
```
backend/data/
├── courses.json
├── timetable.json
├── news.json
└── materials_metadata.json
```

### After (Supabase Database)
```
Supabase PostgreSQL Tables:
├── courses
├── timetable
├── materials
├── news
```

## Step 1: Create Supabase Tables

Log in to [supabase.com](https://supabase.com) and go to your project. Open **SQL Editor** and run this script:

```sql
-- Courses Table
CREATE TABLE courses (
  id BIGSERIAL PRIMARY KEY,
  programme TEXT NOT NULL,
  discipline TEXT NOT NULL,
  level TEXT NOT NULL,
  semester TEXT NOT NULL,
  advisor TEXT,
  course_code TEXT,
  course_title TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(programme, discipline, level, semester, course_code)
);

-- Materials Table
CREATE TABLE materials (
  id BIGSERIAL PRIMARY KEY,
  programme TEXT NOT NULL,
  discipline TEXT NOT NULL,
  level TEXT NOT NULL,
  semester TEXT NOT NULL,
  course_code TEXT,
  material_name TEXT,
  material_type TEXT,
  storage_path TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Timetable Table
CREATE TABLE timetable (
  id BIGSERIAL PRIMARY KEY,
  programme TEXT NOT NULL,
  level TEXT NOT NULL,
  semester TEXT NOT NULL,
  day_of_week TEXT NOT NULL,
  slot_index INTEGER,
  course_code TEXT,
  course_title TEXT,
  time TEXT,
  duration NUMERIC,
  venue TEXT,
  lecturer TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(programme, level, semester, day_of_week, slot_index)
);

-- News Table
CREATE TABLE news (
  id BIGSERIAL PRIMARY KEY,
  programme TEXT NOT NULL,
  level TEXT NOT NULL,
  semester TEXT NOT NULL,
  title TEXT,
  content TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## Step 2: Verify Environment Variables

Make sure your `.env` file has:

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_ANON_KEY=your-anon-key  # optional
```

You can find these in Supabase: **Settings** → **API**

## Step 3: Run Migration Script

The application includes a migration script to move your existing JSON data to Supabase:

```bash
cd backend
julia migrate_to_supabase.jl
```

This will:
- Read all JSON files from `backend/data/`
- Insert data into Supabase tables
- Show progress for each record
- Keep JSON files as backup (optional: you can delete them later)

## Step 4: Restart Server

```bash
julia server.jl
```

The server will automatically use Supabase if the credentials are configured.

## Fallback Behavior

The application is **smart about fallbacks**:

1. **If Supabase is configured** → Uses database
2. **If Supabase is NOT configured** → Falls back to JSON files

This means:
- Local development can still use JSON if you don't set env vars
- Production on Render will use Supabase (set env vars in Render)
- Zero downtime migration

## Testing

After migration, test these endpoints:

```bash
# Get courses for a semester
curl "http://localhost:8000/api/admin/courses?programme=Meteorology&level=100&semester=first-semester"

# Get timetable
curl "http://localhost:8000/api/admin/timetable?programme=Meteorology&level=100&semester=first-semester"

# Get news
curl "http://localhost:8000/api/admin/news"
```

## Deploying to Render

1. **Create free Postgres database** in Render or link existing Supabase
2. **Add environment variables** in Render:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SUPABASE_ANON_KEY` (optional)
3. **Push to GitHub**
4. **Deploy from Render**

Data will persist across restarts because it's stored in Supabase, not ephemeral Render filesystem.

## Database Schema Details

### Courses Table
```sql
programme   TEXT    -- e.g., "Meteorology"
level       TEXT    -- e.g., "100", "200"
semester    TEXT    -- e.g., "first-semester"
course_code TEXT    -- e.g., "MET 101"
course_title TEXT   -- e.g., "General Meteorology"
advisor     TEXT    -- Course advisor name
```

### Timetable Table
```sql
programme   TEXT    -- e.g., "Meteorology"
level       TEXT    -- e.g., "100"
semester    TEXT    -- e.g., "first-semester"
day_of_week TEXT    -- "Monday", "Tuesday", etc.
slot_index  INT     -- 1, 2, 3, 4, 5 (5 slots per day)
course_code TEXT    -- e.g., "MET 101"
course_title TEXT
time        TEXT    -- e.g., "09:00"
duration    NUMERIC -- e.g., 1, 1.5, 2 hours
venue       TEXT    -- e.g., "Chemistry Lab"
lecturer    TEXT    -- Lecturer name
```

### News Table
```sql
programme TEXT  -- "All" or specific programme
level     TEXT  -- "All" or specific level
semester  TEXT  -- "All" or specific semester
title     TEXT
content   TEXT
```

### Materials Table
```sql
programme     TEXT  -- e.g., "Meteorology"
level         TEXT  -- e.g., "100"
semester      TEXT  -- e.g., "first-semester"
course_code   TEXT  -- e.g., "MET 101"
material_name TEXT
material_type TEXT  -- "general", "lecture", "assignment"
storage_path  TEXT  -- Supabase Storage path
```

## Troubleshooting

### Error: "Database not configured"
- Check `.env` file has `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`
- Restart server after setting env vars

### Migration fails
- Verify Supabase tables are created (use SQL Editor)
- Check that service role key has proper permissions
- Run migration again (it's idempotent)

### Data not persisting on Render
- Verify env vars are set in Render dashboard
- Check server logs for errors (Render → Logs)
- Verify Supabase URL is correct

## Performance Notes

- Database queries are **much faster** than JSON file I/O
- Supabase free tier includes **500MB** storage and **5GB** bandwidth
- More than enough for a small educational system

## Keeping JSON Files

After successful migration, you can optionally delete the JSON files to save space:

```bash
rm backend/data/courses.json
rm backend/data/timetable.json
rm backend/data/news.json
rm backend/data/materials_metadata.json
```

The app will continue working because it uses the database.

## Next Steps

1. ✅ Create Supabase tables
2. ✅ Set environment variables
3. ✅ Run migration script
4. ✅ Test endpoints
5. ✅ Deploy to Render with env vars
6. ✅ Monitor in Render dashboard

Your data is now cloud-hosted and ready for production! 🎉
