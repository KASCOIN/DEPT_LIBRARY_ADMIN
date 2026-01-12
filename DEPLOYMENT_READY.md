# Complete Setup for Render Deployment

## ✅ What's Been Done

Your application is now **production-ready** for Render with persistent data storage in Supabase.

### Components Implemented

1. **Supabase Database Service** (`backend/services/supabase_db_service.jl`)
   - Full CRUD API for courses, timetable, news, materials metadata
   - Intelligent database connection handling
   - Error recovery and logging

2. **Updated Controllers** (`backend/controllers/admin_controller.jl`)
   - All endpoints now try Supabase first, fall back to JSON if needed
   - No breaking changes to API
   - Production-ready error handling

3. **Migration Script** (`backend/migrate_to_supabase.jl`)
   - Interactive tool to move your existing JSON data to Supabase
   - Preserves all data with proper formatting
   - Shows progress for each record

4. **Documentation**
   - [SUPABASE_DATABASE_MIGRATION.md](docs/SUPABASE_DATABASE_MIGRATION.md) - Complete guide
   - [RENDER_DEPLOYMENT_QUICK_START.md](docs/RENDER_DEPLOYMENT_QUICK_START.md) - 5-minute setup
   - [DATABASE_MIGRATION_SUMMARY.md](DATABASE_MIGRATION_SUMMARY.md) - Technical overview

## 🚀 Quick Start (10 minutes)

### Step 1: Create Database Tables

1. Go to [supabase.com](https://supabase.com) → Your Project → SQL Editor
2. Paste this SQL and run it:

```sql
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

CREATE TABLE news (
  id BIGSERIAL PRIMARY KEY,
  programme TEXT NOT NULL,
  level TEXT NOT NULL,
  semester TEXT NOT NULL,
  title TEXT,
  content TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

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
```

### Step 2: Get Your Credentials

1. In Supabase → Settings → API
2. Copy:
   - `SUPABASE_URL` (like `https://xxxx.supabase.co`)
   - `SUPABASE_SERVICE_ROLE_KEY` (long key starting with `eyJ`)

### Step 3: Migrate Your Data

```bash
cd backend
julia migrate_to_supabase.jl
```

Type `yes` when prompted. Your data transfers to the database.

### Step 4: Test Locally

```bash
julia server.jl
```

Visit: `http://localhost:8000/api/admin/courses?programme=Meteorology&level=100&semester=first-semester`

Should return JSON with your courses.

### Step 5: Deploy to Render

1. **In Render Dashboard**:
   - Go to your service → Environment
   - Add:
     ```
     SUPABASE_URL=https://xxxx.supabase.co
     SUPABASE_SERVICE_ROLE_KEY=eyJ...
     ```
   - Save

2. **Deploy**:
   - Push changes to GitHub
   - Render auto-deploys

3. **Test**:
   ```bash
   curl "https://your-service.onrender.com/api/admin/courses?programme=Meteorology&level=100&semester=first-semester"
   ```

## ✨ Key Features

✅ **Smart Fallback**: Uses Supabase if configured, JSON otherwise
✅ **No Downtime**: Migration keeps app working during transition
✅ **Auto Backups**: Supabase handles daily backups automatically
✅ **Scalable**: Handles unlimited data growth
✅ **Cost Effective**: Supabase free tier is generous for small apps
✅ **Production Ready**: Full error handling and logging

## 📊 Architecture

```
┌─────────────────────────────────────────┐
│  Frontend (HTML/JS/PDF viewer)          │
└────────────┬────────────────────────────┘
             │ HTTP REST API
             ▼
┌─────────────────────────────────────────┐
│  Backend (Julia/Genie)                  │
│  ├─ AdminController                     │
│  ├─ StudentController                   │
│  └─ Routes                              │
└────┬─────────────────────────────────────┘
     │
     ├─► Storage Layer (Intelligent)
     │   ├─ Try Supabase DB first
     │   └─ Fall back to JSON if needed
     │
     ├─► Supabase (Production)
     │   ├─ PostgreSQL DB (courses, timetable, news, materials)
     │   └─ Cloud Storage (PDF files)
     │
     └─► Local JSON (Development)
         ├─ courses.json
         ├─ timetable.json
         ├─ news.json
         └─ materials_metadata.json
```

## 🔄 Migration Path

```
Local Development:
  ✓ Keep .env without Supabase credentials
  ✓ App uses JSON files
  ✓ Everything works as before

Render Production:
  ✓ Set SUPABASE_* env vars in Render
  ✓ App uses Supabase database
  ✓ Data persists across restarts
```

## 📝 API Compatibility

All API endpoints work the same:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/admin/courses` | POST | Save courses |
| `/api/admin/courses?programme=X&level=Y&semester=Z` | GET | Fetch courses |
| `/api/admin/timetable` | POST | Save timetable |
| `/api/admin/timetable?programme=X&level=Y&semester=Z` | GET | Fetch timetable |
| `/api/admin/news` | POST | Post news |
| `/api/admin/news` | GET | Get all news |
| `/api/admin/materials` | POST | Upload material |

**No changes to frontend code needed** ✅

## ⚠️ Troubleshooting

**Q: Data not appearing after deploy?**
A: Check Render logs → View logs tab. Verify env vars are set.

**Q: Still getting 404 for timetable?**
A: Make sure semester is "first-semester" or "second-semester" (lowercase, with hyphen).

**Q: Can I keep JSON files?**
A: Yes! Migration keeps them. Delete after confirming DB works.

**Q: What if Supabase goes down?**
A: App automatically falls back to JSON files (if they exist).

## 📚 Full Documentation

- [Complete Migration Guide](docs/SUPABASE_DATABASE_MIGRATION.md)
- [Quick Render Setup](docs/RENDER_DEPLOYMENT_QUICK_START.md)
- [Technical Details](DATABASE_MIGRATION_SUMMARY.md)

## ✅ Verification Checklist

- [ ] Supabase tables created
- [ ] Credentials copied to `.env`
- [ ] Migration script run successfully
- [ ] Local server starts without errors
- [ ] API endpoints return data
- [ ] Render env vars set
- [ ] Deployed to Render
- [ ] Production endpoints working
- [ ] Data persists after Render restart

## 🎉 You're Ready!

Your application is now:
- ✅ Production-ready
- ✅ Cloud-deployable
- ✅ Data-persistent
- ✅ Scalable
- ✅ Backed up automatically

Deploy with confidence! 🚀
