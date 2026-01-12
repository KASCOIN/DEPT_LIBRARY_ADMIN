-- ============================================================================
-- ADD LAST_SEEN COLUMN TO PROFILES TABLE
-- ============================================================================
-- 
-- This migration adds a last_seen timestamp to track when students were last active.
-- Used for active student monitoring in the admin dashboard.
--
-- Steps to execute:
-- 1. Go to Supabase Dashboard → Your Project → SQL Editor
-- 2. Create new query and paste this script
-- 3. Click "Run" to execute
-- 4. Verify: Check Tables → profiles → Columns, should see 'last_seen'
--
-- ============================================================================

-- Add last_seen column if it doesn't exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE DEFAULT NULL;

-- Add comment for documentation
COMMENT ON COLUMN profiles.last_seen IS 'Timestamp of last API activity by the student, used for active student tracking';

-- Create index for efficient querying active students
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen ON profiles(last_seen DESC);

-- Update existing rows to set last_seen to their created_at (for existing students)
UPDATE profiles SET last_seen = created_at WHERE last_seen IS NULL;

-- ============================================================================
-- VERIFICATION QUERY
-- ============================================================================
-- 
-- Run this to verify the column was added:
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'profiles' 
-- ORDER BY ordinal_position;
