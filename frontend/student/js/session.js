// session.js
// Handles session management - simple localStorage-based session

// Store session in localStorage
function saveSession(session) {
  localStorage.setItem('student_session', JSON.stringify(session));
}

// Retrieve session from localStorage
function getSession() {
  const session = localStorage.getItem('student_session');
  return session ? JSON.parse(session) : null;
}

// Clear session on logout
function clearSession() {
  localStorage.removeItem('student_session');
}

// Check if user is logged in, redirect to login if not
function checkAuth() {
  const session = getSession();
  if (!session || !session.user_id) {
    window.location.href = 'login.html';
    return null;
  }
  return session;
}

// Logout user
function logout() {
  clearSession();
  window.location.href = 'login.html';
}
