-- ============================================================================
-- SUPABASE AUTH MIGRATION: Set up profiles table linked to auth.users
-- ============================================================================
-- 
-- This script creates the profiles table linked to Supabase Auth's auth.users
-- table, enabling proper JWT-based authentication and role management.
--
-- Steps to execute:
-- 1. Go to Supabase Dashboard → Your Project → SQL Editor
-- 2. Create new query and paste this entire script
-- 3. Click "Run" to execute all statements
-- 4. Verify: Check Tables view to confirm 'profiles' table exists
--
-- ============================================================================

-- Drop existing profiles table if it exists (CAUTION: This deletes all data!)
-- Uncomment only if you want to reset the table:
-- DROP TABLE IF EXISTS profiles CASCADE;

-- ============================================================================
-- 1. Create profiles table linked to auth.users
-- ============================================================================

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  matric_no TEXT UNIQUE,
  programme TEXT,
  level TEXT,
  phone TEXT,
  role TEXT DEFAULT 'student' CHECK (role IN ('student', 'admin')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add comments for documentation
COMMENT ON TABLE profiles IS 'User profile data linked to auth.users, includes academic info and role';
COMMENT ON COLUMN profiles.id IS 'Foreign key to auth.users(id), unique per user';
COMMENT ON COLUMN profiles.email IS 'User email, synced from auth.users';
COMMENT ON COLUMN profiles.full_name IS 'Student full name';
COMMENT ON COLUMN profiles.matric_no IS 'Unique matric number for student identification';
COMMENT ON COLUMN profiles.programme IS 'Student programme/course (e.g., Computer Science)';
COMMENT ON COLUMN profiles.level IS 'Student level (100, 200, 300, 400, etc.)';
COMMENT ON COLUMN profiles.phone IS 'Student phone number';
COMMENT ON COLUMN profiles.role IS 'User role: student or admin';
COMMENT ON COLUMN profiles.created_at IS 'Account creation timestamp';
COMMENT ON COLUMN profiles.updated_at IS 'Last profile update timestamp';

-- ============================================================================
-- 2. Enable Row Level Security (RLS)
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can read their own profile
CREATE POLICY "users_read_own_profile" ON profiles
  FOR SELECT
  USING (auth.uid() = id);

-- Policy 2: Users can update their own profile (except role)
CREATE POLICY "users_update_own_profile" ON profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Policy 3: Service role (backend) can do everything
CREATE POLICY "service_role_all_access" ON profiles
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role')
  WITH CHECK (auth.jwt()->>'role' = 'service_role');

-- ============================================================================
-- 3. Create trigger to sync email from auth.users
-- ============================================================================

CREATE OR REPLACE FUNCTION sync_user_email()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE profiles SET email = NEW.email WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if it already exists
DROP TRIGGER IF EXISTS on_auth_user_email_updated ON auth.users;

-- Create trigger when email is updated in auth.users
CREATE TRIGGER on_auth_user_email_updated
AFTER UPDATE OF email ON auth.users
FOR EACH ROW
EXECUTE FUNCTION sync_user_email();

-- ============================================================================
-- 4. Create function to handle new auth user signups
-- ============================================================================

CREATE OR REPLACE FUNCTION handle_new_auth_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if it already exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger when new user is created in auth.users
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION handle_new_auth_user();

-- ============================================================================
-- 5. Create function to update updated_at timestamp
-- ============================================================================

CREATE OR REPLACE FUNCTION update_profiles_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if it already exists
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;

-- Create trigger to auto-update updated_at on any profile change
CREATE TRIGGER update_profiles_updated_at
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION update_profiles_timestamp();

-- ============================================================================
-- 6. Create indexes for performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_matric_no ON profiles(matric_no);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON profiles(created_at);

-- ============================================================================
-- 7. Grant proper permissions
-- ============================================================================

-- Allow authenticated users to read and update their own profile
GRANT SELECT, UPDATE ON profiles TO authenticated;

-- Allow anonymous users to read public profiles (if needed)
-- GRANT SELECT ON profiles TO anon;

-- ============================================================================
-- 8. Migration from old password-based system (Optional)
-- ============================================================================

-- If you have existing users in the old 'users' or 'profiles' table with passwords:
-- 1. Users must reset their passwords via Supabase Auth
-- 2. Delete the old password_hash column after all users have migrated
-- 3. Example:
--    ALTER TABLE profiles DROP COLUMN IF EXISTS password_hash;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check that profiles table exists and has correct structure:
-- SELECT * FROM information_schema.columns WHERE table_name = 'profiles';

-- Check that RLS policies are enabled:
-- SELECT schemaname, tablename, rowsecurity FROM pg_tables WHERE tablename = 'profiles';

-- Check that triggers are created:
-- SELECT trigger_name FROM information_schema.triggers WHERE event_object_table = 'profiles';

-- ============================================================================
-- END OF MIGRATION SCRIPT
-- ============================================================================
