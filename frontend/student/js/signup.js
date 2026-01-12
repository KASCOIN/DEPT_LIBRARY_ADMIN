// signup.js
// Handles student signup - saves directly to profiles table with password hashing

// TODO: Replace SUPABASE_ANON_KEY with your actual anon key from Supabase dashboard
const SUPABASE_URL = "https://yecpwijvbiurqysxazva.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InllY3B3aWp2Yml1cnF5c3hhenZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5NTM1NzMsImV4cCI6MjA4MzUyOTU3M30.d9Azks_9e5ITT875tROI84RhbNyWsh1hgap4f9_CGXU";
const { createClient } = supabase;
const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Simple password hashing using SHA256 (for frontend demo)
// In production, password hashing should be done on backend!
async function hashPassword(password) {
  const encoder = new TextEncoder();
  const data = encoder.encode(password);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

document.getElementById('signup-form').addEventListener('submit', async function(e) {
  e.preventDefault();
  const errorMsg = document.getElementById('error-msg');
  errorMsg.textContent = '';
  errorMsg.style.color = '#dc2626'; // Red for errors

  // Collect form values
  const fullName = document.getElementById('fullName').value.trim();
  const matricNo = document.getElementById('matricNo').value.trim();
  const programme = document.getElementById('programme').value;
  const level = document.getElementById('level').value;
  const email = document.getElementById('email').value.trim();
  const countryCode = document.getElementById('countryCode').value;
  const phone = document.getElementById('phone').value.trim();
  const password = document.getElementById('password').value;

  // Validate phone number
  if (!/^\d{10}$/.test(phone)) {
    errorMsg.textContent = 'Phone number must be 10 digits.';
    return;
  }

  // Validate all fields
  if (!fullName || !matricNo || !programme || !level || !email || !countryCode || !phone || !password) {
    errorMsg.textContent = 'Please fill in all fields.';
    return;
  }

  try {
    const fullPhone = countryCode + phone;

    // Check if email, matric_no, or phone already exists
    console.log('Checking if user already exists...');
    
    const { data: existing, error: checkError } = await supabaseClient
      .from('profiles')
      .select('id, email, matric_no, phone')
      .or(`email.eq.${email},matric_no.eq.${matricNo},phone.eq.${fullPhone}`)
      .limit(1);

    if (checkError) {
      console.error('Check error:', checkError);
      errorMsg.textContent = 'Error checking existing users: ' + checkError.message;
      return;
    }

    if (existing && existing.length > 0) {
      console.log('User already exists:', existing[0]);
      errorMsg.textContent = 'User already exists! Email, Matric Number, or Phone Number is already registered.';
      return;
    }

    // Generate a simple ID (UUID-like)
    const userId = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });

    // Hash password using SHA256 (frontend only for demo)
    // TODO: Backend should use bcrypt for proper password hashing
    const passwordHash = await hashPassword(password);

    // Insert new profile
    console.log('Creating new profile...');
    const { data: newProfile, error: insertError } = await supabaseClient
      .from('profiles')
      .insert({
        id: userId,
        email,
        full_name: fullName,
        matric_no: matricNo,
        programme,
        level,
        phone: fullPhone,
        password_hash: passwordHash,
        role: 'student'
      })
      .select();

    if (insertError) {
      console.error('Insert error:', insertError);
      errorMsg.textContent = 'Error creating profile: ' + insertError.message;
      return;
    }

    console.log('✓ Profile created successfully:', newProfile);
    
    // Show success message
    errorMsg.style.color = '#16a34a'; // Green
    errorMsg.textContent = '✓ Signup successful! Redirecting to login...';
    
    // Redirect to login
    setTimeout(() => {
      window.location.href = 'login.html';
    }, 2000);

  } catch (e) {
    console.error('Signup error:', e);
    errorMsg.textContent = 'Error: ' + e.message;
  }
});
