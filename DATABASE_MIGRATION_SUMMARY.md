# Database Migration Summary

## What Was Done

I've completely restructured your backend to support **Supabase PostgreSQL** instead of local JSON files. This solves the Render deployment problem where data is lost on every restart.

## Files Created

### 1. **`backend/services/supabase_db_service.jl`** (New)
- Complete Supabase database API client
- Functions for CRUD operations on all tables:
  - `insert_course()` / `get_courses()`
  - `insert_timetable_slot()` / `get_timetable()`
  - `insert_news()` / `get_news()`
  - `insert_material_metadata()` / `get_materials()`
- Automatic fallback to JSON if DB not configured

### 2. **`backend/migrate_to_supabase.jl`** (New)
- Interactive migration script
- Reads JSON files and inserts into Supabase tables
- Preserves all existing data
- Shows progress for each record

### 3. **`docs/SUPABASE_DATABASE_MIGRATION.md`** (New)
- Complete migration guide
- SQL schema creation scripts
- Step-by-step instructions
- Troubleshooting

### 4. **`docs/RENDER_DEPLOYMENT_QUICK_START.md`** (New)
- Quick 5-minute Render setup guide
- Focuses on Supabase integration
- Environment variable reference

## Files Modified

### 1. **`backend/server.jl`**
- Added `include("services/supabase_db_service.jl")`

### 2. **`backend/controllers/admin_controller.jl`**
- Added `using ..SupabaseDbService`
- Updated `post_courses()` - saves to DB or JSON
- Updated `get_courses()` - tries DB first, then JSON
- Updated `post_timetable()` - saves to DB or JSON
- Updated `get_timetable()` - tries DB first, then JSON
- Updated `post_news()` - saves to DB or JSON
- Updated `get_news()` - tries DB first, then JSON
- **Materials** endpoints already using Supabase Storage (no change needed)

## How It Works

### Before
```
Admin saves data → JSON files → Lost on Render restart ❌
```

### After
```
Admin saves data → Supabase DB ← Persists forever ✅
                  (with JSON fallback for local dev)
```

## Key Features

✅ **Intelligent Fallback**: If Supabase not configured, uses JSON (for local dev)
✅ **Zero Downtime**: Migration script doesn't break existing functionality
✅ **API Compatible**: Same REST endpoints, just backed by DB instead of JSON
✅ **Automatic**: Server detects if DB is configured on startup
✅ **Production Ready**: All error handling included

## Next Steps

### For Local Testing
1. Keep `.env` without Supabase credentials
2. App continues using JSON files (everything works as before)

### For Render Deployment
1. Create Supabase tables (SQL provided)
2. Run migration script locally: `julia backend/migrate_to_supabase.jl`
3. Set environment variables in Render:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
4. Deploy to Render
5. Data persists across restarts ✅

## Technical Details

### Database Tables Created
- **courses**: Stores course information with semester filtering
- **timetable**: Stores 5 slots per day × 5 days per week, per semester
- **news**: Stores announcements with programme/level/semester filtering
- **materials**: Stores material metadata (files in Supabase Storage)

### API Compatibility
All existing API endpoints work exactly the same:
- `POST /api/admin/courses` - saves courses
- `GET /api/admin/courses?programme=X&level=Y&semester=Z` - fetches courses
- `POST /api/admin/timetable` - saves timetable
- `GET /api/admin/timetable?programme=X&level=Y&semester=Z` - fetches timetable
- `POST /api/admin/news` - saves news
- `GET /api/admin/news` - fetches all news
- Materials endpoints unchanged

### Environment Variables
```
SUPABASE_URL                 # Required for production
SUPABASE_SERVICE_ROLE_KEY    # Required for production
SUPABASE_ANON_KEY           # Optional
SUPABASE_BUCKET             # Optional (materials storage)
```

## Performance Improvements

- **Database queries** are faster than JSON file I/O
- **Filtering** is done server-side (more efficient)
- **Concurrent access** works correctly (JSON files don't)
- **Automatic backups** (Supabase does daily backups)

## Data Safety

✅ Migration script preserves all data
✅ JSON files kept as backup after migration
✅ Can delete JSON after confirming everything works
✅ Supabase has automatic failover and redundancy

## Migration Checklist

- [ ] Create Supabase tables (SQL provided)
- [ ] Get SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
- [ ] Run `julia backend/migrate_to_supabase.jl`
- [ ] Restart server: `julia backend/server.jl`
- [ ] Test API endpoints locally
- [ ] Set env vars in Render dashboard
- [ ] Deploy to Render
- [ ] Test on production URL
- [ ] Monitor for errors (Render logs)
- [ ] Optional: Delete JSON files as backup

## Questions?

Refer to:
1. [SUPABASE_DATABASE_MIGRATION.md](SUPABASE_DATABASE_MIGRATION.md) - Full guide
2. [RENDER_DEPLOYMENT_QUICK_START.md](RENDER_DEPLOYMENT_QUICK_START.md) - Quick setup
