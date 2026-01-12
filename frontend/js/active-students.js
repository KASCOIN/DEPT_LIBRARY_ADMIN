/**
 * active-students.js
 * 
 * Displays active students on the admin dashboard
 * Fetches data from /api/admin/active-students endpoint
 * Updates periodically without in-memory state or local storage
 */

const ACTIVE_STUDENTS_REFRESH_INTERVAL = 30 * 1000; // 30 seconds
const ACTIVE_WINDOW_MINUTES = 5; // Match backend config

let activeStudentsRefreshTimer = null;

/**
 * Get authorization token - tries multiple sources
 */
async function getAuthToken() {
  console.log('[Active Students] getAuthToken() called');
  
  // Try localStorage for new admin token system FIRST
  let token = localStorage.getItem('admin_token');
  if (token) {
    console.log('[Active Students] Found admin_token in localStorage');
    return token;
  }
  console.log('[Active Students] No admin_token in localStorage');
  
  // Try sessionStorage for admin token
  token = sessionStorage.getItem('admin_access_token');
  if (token) {
    console.log('[Active Students] Found admin_access_token in sessionStorage');
    return token;
  }
  console.log('[Active Students] No admin_access_token in sessionStorage');
  
  // Try getting admin token (from admin-config.js)
  if (typeof getAdminToken === 'function') {
    try {
      const token = await getAdminToken();
      if (token) {
        console.log('[Active Students] Got token from getAdminToken()');
        return token;
      }
    } catch (e) {
      console.warn('[Active Students] getAdminToken() failed:', e);
    }
  }

  // Try localStorage
  token = localStorage.getItem('access_token');
  if (token) {
    console.log('[Active Students] Found access_token in localStorage');
    return token;
  }

  // Try sessionStorage for regular access token
  token = sessionStorage.getItem('access_token');
  if (token) {
    console.log('[Active Students] Found access_token in sessionStorage');
    return token;
  }

  // Try Supabase session if available
  if (typeof supabaseClient !== 'undefined') {
    try {
      const { data: { session } } = await supabaseClient.auth.getSession();
      if (session && session.access_token) {
        console.log('[Active Students] Got token from Supabase session');
        return session.access_token;
      }
    } catch (e) {
      console.warn('[Active Students] Supabase session check failed:', e);
    }
  }

  console.warn('[Active Students] *** NO TOKEN FOUND - All sources exhausted ***');
  return null;
}

/**
 * Fetch active students from backend
 */
async function fetchActiveStudents() {
  try {
    const token = await getAuthToken();
    
    console.log('[Active Students] Fetching with token:', token ? 'YES (length: ' + token.length + ')' : 'NO');
    
    const headers = {
      'Content-Type': 'application/json'
    };
    
    // Add auth header if token available
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
      console.log('[Active Students] Authorization header added');
    } else {
      console.warn('[Active Students] WARNING: No token available for authentication');
    }

    console.log('[Active Students] Requesting:', `/api/admin/active-students?minutes=${ACTIVE_WINDOW_MINUTES}`);
    
    const response = await fetch(
      `/api/admin/active-students?minutes=${ACTIVE_WINDOW_MINUTES}`,
      {
        method: 'GET',
        headers: headers
      }
    );

    console.log('[Active Students] Response status:', response.status);
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error('[Active Students] Error response:', errorText);
      
      if (response.status === 401) {
        console.warn('Unauthorized: No valid authentication token. Please log in.');
        return { success: false, error: 'Unauthorized', count: 0, students: [] };
      }
      if (response.status === 403) {
        console.warn('Forbidden: User may not have required permissions');
        return { success: false, error: 'Forbidden', count: 0, students: [] };
      }
      throw new Error(`HTTP ${response.status}: ${errorText}`);
    }

    const data = await response.json();
    console.log('[Active Students] Successfully fetched:', data.count, 'students');
    return data;
  } catch (error) {
    console.error('Error fetching active students:', error);
    return { success: false, error: error.message, count: 0, students: [] };
  }
}

/**
 * Format timestamp for display
 */
function formatLastSeen(timestamp) {
  if (!timestamp) return 'Unknown';
  
  try {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now - date;
    const seconds = Math.floor(diff / 1000);
    const minutes = Math.floor(seconds / 60);
    
    if (seconds < 60) {
      return 'Just now';
    } else if (minutes < 60) {
      return `${minutes}m ago`;
    } else {
      const hours = Math.floor(minutes / 60);
      return `${hours}h ago`;
    }
  } catch {
    return 'Unknown';
  }
}

/**
 * Update active students display
 */
async function updateActiveStudentsDisplay() {
  const data = await fetchActiveStudents();
  
  if (!data.success) {
    // Show error or empty state
    document.getElementById('online-count').textContent = '0';
    document.getElementById('online-students-list').innerHTML = 
      '<p style="text-align: center; color: #999; padding: 20px 0;">Unable to load active students</p>';
    return;
  }

  const count = data.count || 0;
  const students = data.students || [];

  // Update count
  document.getElementById('online-count').textContent = count;

  // Update list
  const listContainer = document.getElementById('online-students-list');
  
  if (students.length === 0) {
    listContainer.innerHTML = 
      '<p style="text-align: center; color: #999; padding: 20px 0;">No students currently active</p>';
    return;
  }

  // Create student items
  const studentItems = students.map(student => {
    const lastSeen = formatLastSeen(student.last_seen);
    const fullName = student.full_name || 'Unknown';
    const email = student.email || 'No email';
    const programme = student.programme || 'N/A';
    const level = student.level || 'N/A';
    
    return `
      <div style="
        padding: 12px;
        border-bottom: 1px solid #f0f0f0;
        display: flex;
        justify-content: space-between;
        align-items: center;
        font-size: 13px;
      ">
        <div>
          <div style="font-weight: 500; color: #333;">${fullName}</div>
          <div style="color: #999; font-size: 12px; margin-top: 2px;">${email}</div>
          <div style="color: #999; font-size: 11px; margin-top: 2px;">
            ${programme} - Level ${level}
          </div>
        </div>
        <div style="
          text-align: right;
          font-size: 12px;
          color: #666;
          white-space: nowrap;
          margin-left: 10px;
        ">
          <span style="
            display: inline-block;
            width: 8px;
            height: 8px;
            background-color: #4CAF50;
            border-radius: 50%;
            margin-right: 6px;
          "></span>
          ${lastSeen}
        </div>
      </div>
    `;
  }).join('');

  listContainer.innerHTML = studentItems;
}

/**
 * Start periodic updates
 */
function startActiveStudentsTracking() {
  // Initial update
  updateActiveStudentsDisplay();

  // Set up periodic updates
  if (activeStudentsRefreshTimer) {
    clearInterval(activeStudentsRefreshTimer);
  }

  activeStudentsRefreshTimer = setInterval(() => {
    updateActiveStudentsDisplay();
  }, ACTIVE_STUDENTS_REFRESH_INTERVAL);

  console.log('[Active Students] Tracking started, updating every 30s');
}

/**
 * Stop periodic updates
 */
function stopActiveStudentsTracking() {
  if (activeStudentsRefreshTimer) {
    clearInterval(activeStudentsRefreshTimer);
    activeStudentsRefreshTimer = null;
    console.log('[Active Students] Tracking stopped');
  }
}

// Start tracking when dashboard loads
document.addEventListener('DOMContentLoaded', startActiveStudentsTracking);

// Stop tracking when leaving page
document.addEventListener('beforeunload', stopActiveStudentsTracking);
