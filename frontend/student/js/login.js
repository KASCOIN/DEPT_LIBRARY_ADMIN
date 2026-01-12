/**
 * login.js
 * Student login using Supabase Auth
 * 
 * Handles:
 * - Email/password authentication via Supabase
 * - JWT token retrieval and storage
 * - User profile loading
 * - Session initialization
 * - Redirect to dashboard on success
 */

// Supabase client is initialized in config.js

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
    
    // Sign in with Supabase Auth
    const { data, error } = await supabaseClient.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      console.error('Login error:', error.message);
      errorMsg.textContent = error.message || 'Invalid email or password.';
      return;
    }

    if (!data.user || !data.session) {
      errorMsg.textContent = 'Login failed: No session returned.';
      return;
    }

    console.log('✓ Login successful! User:', data.user.email);
    
    // Fetch additional profile data
    const { data: profile, error: profileError } = await supabaseClient
      .from('profiles')
      .select('*')
      .eq('id', data.user.id)
      .single();

    if (profileError) {
      console.warn('Profile fetch warning:', profileError);
    }

    // Store session (Supabase handles JWT internally)
    const sessionData = {
      user_id: data.user.id,
      email: data.user.email,
      full_name: profile?.full_name || '',
      matric_no: profile?.matric_no || '',
      programme: profile?.programme || '',
      level: profile?.level || '',
      phone: profile?.phone || '',
      role: profile?.role || 'student',
      login_time: new Date().toISOString(),
      access_token: data.session.access_token // Store JWT token
    };
    
    // Keep token in localStorage temporarily (in production, use httpOnly cookies)
    localStorage.setItem('student_session', JSON.stringify(sessionData));
    
    errorMsg.style.color = '#16a34a'; // Green for success
    errorMsg.textContent = '✓ Login successful! Redirecting...';
    
    // Redirect to dashboard
    setTimeout(() => {
      window.location.href = 'student-main.html';
    }, 1000);
    
  } catch (e) {
    console.error('Unexpected login error:', e);
    errorMsg.textContent = 'Error: ' + (e.message || 'Unknown error');
  }
});
