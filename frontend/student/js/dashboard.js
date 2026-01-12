// dashboard.js
// Load and display student profile on dashboard

function loadProfile() {
  const session = checkAuth();
  if (!session) return;

  try {
    // Display profile from session
    const profile = session;
    
    document.getElementById('fullName').textContent = profile.full_name || 'N/A';
    document.getElementById('email').textContent = profile.email || 'N/A';
    document.getElementById('matricNo').textContent = profile.matric_no || 'N/A';
    document.getElementById('programme').textContent = profile.programme || 'N/A';
    document.getElementById('level').textContent = profile.level || 'N/A';
    document.getElementById('phone').textContent = profile.phone || 'N/A';
    
    document.getElementById('loading').style.display = 'none';
    document.getElementById('profile').style.display = 'block';
  } catch (error) {
    console.error('Error loading profile:', error);
    document.getElementById('loading').style.display = 'none';
    document.getElementById('error-msg').textContent = 'Failed to load profile: ' + error.message;
  }
}

// Load profile on page load
loadProfile();
