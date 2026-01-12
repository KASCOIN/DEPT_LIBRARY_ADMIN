/**
 * admin-config.js
 * Supabase configuration for admin portal
 */

const SUPABASE_URL = "https://yecpwijvbiurqysxazva.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InllY3B3aWp2Yml1cnF5c3hhenZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5NTM1NzMsImV4cCI6MjA4MzUyOTU3M30.d9Azks_9e5ITT875tROI84RhbNyWsh1hgap4f9_CGXU";
const { createClient } = supabase;
const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

/**
 * Get admin JWT token from session storage or Supabase
 */
async function getAdminToken() {
  // Try session storage first
  const stored = sessionStorage.getItem('admin_access_token');
  if (stored) {
    return stored;
  }

  // Try getting from Supabase session
  try {
    const { data: { session } } = await supabaseClient.auth.getSession();
    if (session && session.access_token) {
      sessionStorage.setItem('admin_access_token', session.access_token);
      return session.access_token;
    }
  } catch (e) {
    console.debug('No Supabase session available');
  }

  return null;
}

/**
 * Store admin token
 */
function setAdminToken(token) {
  if (token) {
    sessionStorage.setItem('admin_access_token', token);
  }
}

/**
 * Clear admin token on logout
 */
function clearAdminToken() {
  sessionStorage.removeItem('admin_access_token');
}
