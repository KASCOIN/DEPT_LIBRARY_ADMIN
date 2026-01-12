# Department Library Admin Backend

This is the backend for the Department Library Admin system, built with Julia and Genie.jl.

## Setup

1. Ensure Julia is installed.
2. Navigate to the backend directory.
3. Install dependencies: `julia --project -e 'using Pkg; Pkg.instantiate()'`
4. Run the server: `julia --project server.jl`

The server will start on http://127.0.0.1:8000

## API Endpoints

### POST Endpoints (for admin uploads)
- `/api/admin/news` - Post announcements
- `/api/admin/materials` - Upload materials (files)
- `/api/admin/timetable` - Update timetable
- `/api/admin/courses` - Add courses

### GET Endpoints (for public access)
- `/api/news` - Get news/announcements as JSON
- `/api/materials` - Get materials metadata as JSON
- `/api/timetable` - Get timetable as JSON
- `/api/courses` - Get courses as JSON

Data is stored in JSON files in the `data/` directory.