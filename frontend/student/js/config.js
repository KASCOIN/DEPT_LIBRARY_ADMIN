/**
 * config.js
 * Shared Supabase configuration for all student pages
 * Import this file before other scripts to avoid duplicate declarations
 */

const SUPABASE_URL = "https://yecpwijvbiurqysxazva.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InllY3B3aWp2Yml1cnF5c3hhenZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5NTM1NzMsImV4cCI6MjA4MzUyOTU3M30.d9Azks_9e5ITT875tROI84RhbNyWsh1hgap4f9_CGXU";
const { createClient } = supabase;
const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
