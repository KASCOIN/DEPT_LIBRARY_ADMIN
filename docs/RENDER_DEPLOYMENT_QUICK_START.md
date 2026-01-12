# Quick Render Deployment Guide

## Problem
Local JSON files don't persist on Render (ephemeral filesystem = lost data on every restart).

## Solution
Use Supabase PostgreSQL to store data instead.

## Quick Setup (5 minutes)

### 1. Create Supabase Tables (2 min)

Go to [supabase.com](https://supabase.com) → Your Project → SQL Editor → Paste and run:

```sql
CREATE TABLE courses (id BIGSERIAL PRIMARY KEY, programme TEXT NOT NULL, discipline TEXT NOT NULL, level TEXT NOT NULL, semester TEXT NOT NULL, advisor TEXT, course_code TEXT, course_title TEXT, created_at TIMESTAMP DEFAULT NOW(), UNIQUE(programme, discipline, level, semester, course_code));

CREATE TABLE timetable (id BIGSERIAL PRIMARY KEY, programme TEXT NOT NULL, level TEXT NOT NULL, semester TEXT NOT NULL, day_of_week TEXT NOT NULL, slot_index INTEGER, course_code TEXT, course_title TEXT, time TEXT, duration NUMERIC, venue TEXT, lecturer TEXT, created_at TIMESTAMP DEFAULT NOW(), UNIQUE(programme, level, semester, day_of_week, slot_index));

CREATE TABLE news (id BIGSERIAL PRIMARY KEY, programme TEXT NOT NULL, level TEXT NOT NULL, semester TEXT NOT NULL, title TEXT, content TEXT, created_at TIMESTAMP DEFAULT NOW());

CREATE TABLE materials (id BIGSERIAL PRIMARY KEY, programme TEXT NOT NULL, discipline TEXT NOT NULL, level TEXT NOT NULL, semester TEXT NOT NULL, course_code TEXT, material_name TEXT, material_type TEXT, storage_path TEXT, created_at TIMESTAMP DEFAULT NOW());
```

### 2. Get Credentials (1 min)

Supabase → Settings → API:
- Copy `SUPABASE_URL` (looks like `https://xxxx.supabase.co`)
- Copy `SUPABASE_SERVICE_ROLE_KEY` (looks like `eyJhbG...`)

### 3. Migrate Data (1 min)

Locally, run:
```bash
cd backend
julia migrate_to_supabase.jl
```

Type `yes` to migrate your existing JSON data.

### 4. Deploy to Render (1 min)

Render Dashboard → Your Service → Environment:

Add these environment variables:
```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbG...
```

Push to GitHub → Render auto-deploys → Done! ✅

## That's It!

Your data now persists on Render. Test with:
```bash
curl "https://your-render-url.onrender.com/api/admin/courses?programme=Meteorology&level=100&semester=first-semester"
```

## Why This Works

| Aspect | JSON Files | Supabase DB |
|--------|-----------|-----------|
| **Persist on Render?** | ❌ No (deleted on restart) | ✅ Yes (cloud storage) |
| **Multiple Instances** | ❌ Data conflicts | ✅ Single source of truth |
| **Backups** | ❌ Manual | ✅ Automatic daily |
| **Scaling** | ❌ Limited | ✅ No limits |
| **Cost** | Free but doesn't work | Free tier (generous) |

## Troubleshooting

**Q: Data not showing after deploy?**
A: Check Render logs for errors. Verify env vars are set in Render dashboard.

**Q: Still using JSON instead of database?**
A: App falls back to JSON if env vars are missing. Check they're set in Render.

**Q: Can I keep JSON files as backup?**
A: Yes! They're not deleted. Just keep them or delete after confirming DB works.

## Need Help?

See full guide: [SUPABASE_DATABASE_MIGRATION.md](SUPABASE_DATABASE_MIGRATION.md)
