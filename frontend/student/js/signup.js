/**
 * signup.js
 * Student signup using Supabase Auth
 * 
 * Handles:
 * - New user registration with Supabase Auth
 * - Profile creation in profiles table
 * - Password hashing by Supabase (bcrypt)
 * - Email validation
 * - Duplicate user prevention
 * - Redirect to login on success
 */

// Supabase client is initialized in config.js

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

  // Validate password strength
  if (password.length < 6) {
    errorMsg.textContent = 'Password must be at least 6 characters.';
    return;
  }

  try {
    const fullPhone = countryCode + phone;

    // Check if matric_no or phone already exists
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
      const existingUser = existing[0];
      if (existingUser.email === email) {
        errorMsg.textContent = 'Email already registered!';
      } else if (existingUser.matric_no === matricNo) {
        errorMsg.textContent = 'Matric number already registered!';
      } else if (existingUser.phone === fullPhone) {
        errorMsg.textContent = 'Phone number already registered!';
      } else {
        errorMsg.textContent = 'User already exists!';
      }
      return;
    }

    console.log('Creating new user account...');
    
    // Sign up with Supabase Auth - password is hashed by Supabase (bcrypt)
    const { data: authData, error: authError } = await supabaseClient.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: fullName
        }
      }
    });

    if (authError) {
      console.error('Auth signup error:', authError);
      errorMsg.textContent = 'Signup error: ' + authError.message;
      return;
    }

    if (!authData.user) {
      errorMsg.textContent = 'Signup failed: No user returned.';
      return;
    }

    console.log('✓ Auth user created:', authData.user.id);
    
    // Create profile record linked to auth.users
    console.log('Creating profile record...');
    const { data: profileData, error: profileError } = await supabaseClient
      .from('profiles')
      .insert({
        id: authData.user.id,
        email,
        full_name: fullName,
        matric_no: matricNo,
        programme,
        level,
        phone: fullPhone,
        role: 'student'
      })
      .select();

    if (profileError) {
      console.error('Profile insert error:', profileError);
      errorMsg.textContent = 'Error creating profile: ' + profileError.message;
      // Note: Auth user was created, but profile failed - may need manual cleanup
      return;
    }

    console.log('✓ Profile created successfully:', profileData);
    
    // Show success message
    errorMsg.style.color = '#16a34a'; // Green
    errorMsg.textContent = '✓ Signup successful! Redirecting to login...';
    
    // Redirect to login
    setTimeout(() => {
      window.location.href = 'login.html';
    }, 2000);

  } catch (e) {
    console.error('Signup error:', e);
    errorMsg.textContent = 'Error: ' + (e.message || 'Unknown error');
  }
});
