# Supabase Migration Setup Guide

## 1. Create Supabase Project

1. Go to https://app.supabase.com
2. Click "New Project"
3. **Project Name:** `dept-library`
4. **Database Password:** Save securely (you'll need this)
5. **Region:** Select the closest region to your deployment
6. Click "Create new project" (wait 5-10 minutes for initialization)

## 2. Create Storage Bucket

1. In Supabase dashboard, go to **Storage** (left sidebar)
2. Click **Create a new bucket**
3. **Bucket name:** `materials`
4. **Privacy:** Keep **PRIVATE** (do NOT enable public access)
5. Click **Create bucket**

## 3. Retrieve API Credentials

1. Go to **Project Settings** (bottom left gear icon)
2. Click **API** tab
3. Copy and save these values:
   - **Project URL** → `SUPABASE_URL`
   - **Service Role Key** (under "Service role secret") → `SUPABASE_SERVICE_ROLE_KEY`

⚠️ **SECURITY:** The Service Role Key has full database and storage access. Keep it secret. Store only in `.env` file on backend.

## 4. Update Backend Environment

Edit `.env` in the project root:

```bash
#!/bin/bash
export SUPABASE_URL="https://your-project-id.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
export SUPABASE_BUCKET="materials"
```

## 5. Verify Credentials (Optional)

Test the connection by running:

```bash
julia> using HTTP
julia> url = ENV["SUPABASE_URL"] * "/storage/v1/buckets"
julia> headers = ["Authorization" => "Bearer " * ENV["SUPABASE_SERVICE_ROLE_KEY"]]
julia> response = HTTP.get(url, headers)
julia> println(String(response.body))
```

Should return bucket information.

## Storage Path Convention

All files uploaded to Supabase follow this structure:

```
materials/undergraduate/{programme}/level-{level}/{semester}/{course_code}/{category}/{filename}
```

**Example:**
```
materials/undergraduate/meteorology/level-300/first-semester/MTC301/lectures/intro.pdf
```

## Reverting (If Needed)

All Supabase data can be deleted by removing the bucket. Local backups of metadata are stored in `backend/data/materials_metadata.json`.
