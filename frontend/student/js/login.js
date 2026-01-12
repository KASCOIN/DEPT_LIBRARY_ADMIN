// login.js
// Handles student login - validates against backend API with password verification

const BACKEND_URL = window.location.origin || "http://localhost:8000";

document.getElementById('login-form').addEventListener('submit', async function(e) {
  e.preventDefault();
  const errorMsg = document.getElementById('error-msg');
  errorMsg.textContent = '';
  errorMsg.style.color = '#dc2626'; // Red for errors

  const email = document.getElementById('email').value.trim();
  const password = document.getElementById('password').value;

  if (!email || !password) {
    errorMsg.textContent = 'Please fill in all fields.';
    return;
  }

  try {
    console.log('Attempting login with email:', email);
    
    // Call backend login endpoint
    const response = await fetch(`${BACKEND_URL}/api/student/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ email, password })
    });

    console.log('Login response status:', response.status);
    const data = await response.json();
    console.log('Login response:', data);

    if (!response.ok || !data.success) {
      console.error('Login failed:', data.error);
      errorMsg.textContent = data.error || 'Invalid email or password.';
      return;
    }

    if (!data.profile) {
      errorMsg.textContent = 'No profile found.';
      return;
    }

    console.log('✓ Login successful! User:', data.profile);
    
    // Save session
    const sessionData = {
      user_id: data.profile.id,
      email: data.profile.email,
      full_name: data.profile.full_name,
      matric_no: data.profile.matric_no,
      programme: data.profile.programme,
      level: data.profile.level,
      phone: data.profile.phone,
      role: data.profile.role,
      login_time: new Date().toISOString()
    };
    
    localStorage.setItem('student_session', JSON.stringify(sessionData));
    
    errorMsg.style.color = '#16a34a'; // Green
    errorMsg.textContent = '✓ Login successful! Redirecting...';
    
    setTimeout(() => {
      window.location.href = 'student-main.html';
    }, 1500);

  } catch (e) {
    console.error('Login error:', e);
    errorMsg.textContent = 'Error: ' + e.message;
  }
});
