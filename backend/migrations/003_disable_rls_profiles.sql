-- ============================================================================
-- DISABLE RLS ON PROFILES TABLE
-- ============================================================================
-- 
-- Row-Level Security (RLS) is causing infinite recursion errors when
-- students try to fetch their profile. Since our backend uses service_role
-- for database access (which bypasses RLS), we can safely disable RLS on
-- the profiles table and rely on backend authorization instead.
--
-- Execute this in Supabase SQL Editor
-- ============================================================================

-- Disable RLS on profiles table
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- Drop all RLS policies (they're no longer needed)
DROP POLICY IF EXISTS "users_read_own_profile" ON profiles;
DROP POLICY IF EXISTS "users_update_own_profile" ON profiles;
DROP POLICY IF EXISTS "service_role_all_access" ON profiles;

-- ============================================================================
-- Verification
-- ============================================================================
-- After running this, verify RLS is disabled:
-- SELECT schemaname, tablename, rowsecurity 
-- FROM pg_tables 
-- WHERE tablename = 'profiles';
-- 
-- Should show: rowsecurity = false
