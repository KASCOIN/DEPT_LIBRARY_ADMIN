/**
 * session.js
 * Session management using Supabase Auth JWT tokens
 * 
 * Handles:
 * - JWT token storage and retrieval
 * - Session initialization and validation
 * - User authentication checks
 * - Authorization headers for API requests
 */

// Supabase client is initialized in config.js

/**
 * Get current session from Supabase Auth
 * Returns { user, session } or null
 */
async function getSession() {
  try {
    const { data: { session }, error } = await supabaseClient.auth.getSession();
    if (error) {
      console.error("Error getting session:", error);
      return null;
    }
    return session;
  } catch (e) {
    console.error("Session retrieval failed:", e);
    return null;
  }
}

/**
 * Get current user from Supabase Auth
 * Returns { id, email, user_metadata } or null
 */
async function getCurrentUser() {
  try {
    const { data: { user }, error } = await supabaseClient.auth.getUser();
    if (error) {
      console.error("Error getting user:", error);
      return null;
    }
    return user;
  } catch (e) {
    console.error("User retrieval failed:", e);
    return null;
  }
}

/**
 * Get JWT access token for API requests
 * Returns token string or null
 */
async function getAccessToken() {
  try {
    const session = await getSession();
    return session?.access_token || null;
  } catch (e) {
    console.error("Error getting access token:", e);
    return null;
  }
}

/**
 * Check if user is authenticated
 * If not, redirect to login
 * Returns user object or null
 */
async function checkAuth() {
  try {
    const { data: { user }, error } = await supabaseClient.auth.getUser();
    if (error || !user) {
      console.log("Not authenticated, redirecting to login");
      window.location.href = 'login.html';
      return null;
    }

    // Get JWT token for backend API
    const { data: { session } } = await supabaseClient.auth.getSession();
    if (!session) {
      console.error("No session available");
      window.location.href = 'login.html';
      return null;
    }

    // Fetch complete profile from backend API (avoids RLS issues)
    const response = await fetch(`/api/student/profile/${user.id}`, {
      headers: {
        'Authorization': `Bearer ${session.access_token}`,
        'Content-Type': 'application/json'
      }
    });

    if (!response.ok) {
      console.error("Error fetching profile from backend:", response.status);
      const errorText = await response.text();
      console.error("Error response:", errorText);
      // Return user data even if profile fetch fails, with defaults for missing fields
      return {
        id: user.id,
        email: user.email,
        full_name: user.user_metadata?.full_name || '-',
        matric_no: '-',
        programme: '-',
        level: '-',
        phone: '-',
        role: 'student'
      };
    }

    const profileData = await response.json();
    console.log("Profile data from backend:", profileData);
    
    // Return merged user and profile data
    if (profileData.success && profileData.profile) {
      return {
        id: user.id,
        email: user.email || profileData.profile.email,
        full_name: profileData.profile.full_name || user.user_metadata?.full_name || '-',
        matric_no: profileData.profile.matric_no || '-',
        programme: profileData.profile.programme || '-',
        level: profileData.profile.level || '-',
        phone: profileData.profile.phone || '-',
        role: profileData.profile.role || 'student'
      };
    } else {
      // Fallback if profile data is not in expected format
      return {
        id: user.id,
        email: user.email,
        full_name: user.user_metadata?.full_name || '-',
        matric_no: '-',
        programme: '-',
        level: '-',
        phone: '-',
        role: 'student'
      };
    }
  } catch (e) {
    console.error("Auth check failed:", e);
    window.location.href = 'login.html';
    return null;
  }
}

/**
 * Fetch with automatic Authorization header
 * Includes Bearer token for all API requests
 * 
 * Usage: fetchWithAuth('/api/endpoint', { method: 'POST', body: ... })
 */
async function fetchWithAuth(url, options = {}) {
  const token = await getAccessToken();
  
  if (!token) {
    console.log("No token available, redirecting to login");
    window.location.href = 'login.html';
    return null;
  }
  
  const headers = {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
    ...options.headers
  };
  
  try {
    const response = await fetch(url, {
      ...options,
      headers
    });
    
    // If 401, token expired or invalid - logout
    if (response.status === 401) {
      console.log("Authentication failed (401), logging out");
      await logout();
      window.location.href = 'login.html';
      return null;
    }
    
    return response;
  } catch (error) {
    console.error("Fetch error:", error);
    throw error;
  }
}

/**
 * Logout user and clear session
 */
async function logout() {
  try {
    const { error } = await supabaseClient.auth.signOut();
    if (error) {
      console.error("Logout error:", error);
    }
    console.log("User logged out successfully");
  } catch (e) {
    console.error("Error during logout:", e);
  }
}

/**
 * ============================================================================
 * INACTIVITY TIMEOUT MANAGEMENT
 * ============================================================================
 * 
 * Logs out students after a configurable period of inactivity
 * Activity includes: mouse movement, clicks, keyboard, scrolling
 * Warning shown 1 minute before logout
 */

// Configuration
const INACTIVITY_TIMEOUT = 15 * 60 * 1000; // 15 minutes in milliseconds
const WARNING_TIME = 1 * 60 * 1000; // Show warning 1 minute before logout

let inactivityTimeout = null;
let warningTimeout = null;
let lastActivityTime = Date.now();

/**
 * Reset inactivity timer - called on user activity
 */
function resetInactivityTimer() {
  lastActivityTime = Date.now();
  
  // Clear existing timeouts
  if (inactivityTimeout) clearTimeout(inactivityTimeout);
  if (warningTimeout) clearTimeout(warningTimeout);
  
  // Hide warning if visible
  const warningModal = document.getElementById('inactivityWarningModal');
  if (warningModal && !warningModal.classList.contains('hidden')) {
    warningModal.classList.add('hidden');
  }
  
  // Set warning timeout (shows warning before logout)
  warningTimeout = setTimeout(() => {
    showInactivityWarning();
  }, INACTIVITY_TIMEOUT - WARNING_TIME);
  
  // Set logout timeout
  inactivityTimeout = setTimeout(() => {
    performInactivityLogout();
  }, INACTIVITY_TIMEOUT);
  
  console.log(`[Session] Activity detected, timer reset. Timeout in ${INACTIVITY_TIMEOUT / 1000}s`);
}

/**
 * Show warning modal before logout
 */
function showInactivityWarning() {
  const warningModal = document.getElementById('inactivityWarningModal');
  if (warningModal) {
    warningModal.classList.remove('hidden');
    console.log('[Session] Inactivity warning shown');
    
    // Start countdown timer in the modal
    let remainingSeconds = Math.floor(WARNING_TIME / 1000);
    const countdownEl = document.getElementById('inactivityCountdown');
    
    const countdownInterval = setInterval(() => {
      remainingSeconds--;
      if (countdownEl) {
        countdownEl.textContent = remainingSeconds;
      }
      
      if (remainingSeconds <= 0) {
        clearInterval(countdownInterval);
      }
    }, 1000);
  }
}

/**
 * Perform automatic logout due to inactivity
 */
async function performInactivityLogout() {
  console.log('[Session] Logging out due to inactivity');
  
  // Clear the session
  clearSession();
  
  // Show message and redirect
  const warningModal = document.getElementById('inactivityWarningModal');
  if (warningModal) {
    warningModal.innerHTML = `
      <div class="inactivity-modal-content">
        <div class="inactivity-modal-header">
          <h2>Session Expired</h2>
        </div>
        <div class="inactivity-modal-body">
          <p>Your session has expired due to inactivity.</p>
          <p>You have been logged out for security purposes.</p>
        </div>
        <div class="inactivity-modal-footer">
          <button onclick="window.location.href='login.html'" class="inactivity-btn-continue">Go to Login</button>
        </div>
      </div>
    `;
  }
  
  // Redirect to login after 3 seconds
  setTimeout(() => {
    window.location.href = 'login.html';
  }, 3000);
}

/**
 * User clicked "Continue Working" - reset the timer
 */
function continueWorking() {
  console.log('[Session] User clicked "Continue Working"');
  resetInactivityTimer();
}

/**
 * Manual logout
 */
function manualLogout() {
  // Clear timeouts
  if (inactivityTimeout) clearTimeout(inactivityTimeout);
  if (warningTimeout) clearTimeout(warningTimeout);
  
  // Perform logout
  logout();
  window.location.href = 'login.html';
}

/**
 * Setup activity listeners - detect user activity
 */
function setupActivityListeners() {
  const activityEvents = [
    'mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart', 'click'
  ];
  
  activityEvents.forEach(event => {
    document.addEventListener(event, resetInactivityTimer, true);
  });
  
  console.log('[Session] Activity listeners initialized');
}

/**
 * Setup auth state listener
 * Called on page load to detect auth changes
 */
function setupAuthListener() {
  supabaseClient.auth.onAuthStateChange((event, session) => {
    console.log('Auth state changed:', event);
    if (event === 'SIGNED_OUT' || !session) {
      console.log('User signed out');
      // Optionally redirect to login
      // window.location.href = 'login.html';
    } else if (event === 'SIGNED_IN') {
      console.log('User signed in:', session.user.email);
    }
  });
}

// Initialize auth listener and activity tracking when page loads
document.addEventListener('DOMContentLoaded', () => {
  setupAuthListener();
  setupActivityListeners();
  resetInactivityTimer(); // Start the timer
});

