// student-main.js - Student dashboard main functionality
// Supabase client is initialized in config.js

let currentSession = null;

// Initialize dashboard on page load
document.addEventListener('DOMContentLoaded', async function() {
  // Check authentication
  currentSession = await checkAuth();
  if (!currentSession) {
    return;
  }

  // Load profile into popup
  loadProfilePopup(currentSession);

  // Load data for all sections
  loadDashboardData();
  loadCoursesForDashboard();
  loadMaterialsFilters();

  // Setup navigation
  setupNavigation();
});

/**
 * Setup sidebar navigation
 */
function setupNavigation() {
  const navItems = document.querySelectorAll('.nav-item');
  
  navItems.forEach(item => {
    item.addEventListener('click', function(e) {
      e.preventDefault();
      
      const section = this.dataset.section;
      
      // Remove active class from all nav items
      navItems.forEach(i => i.classList.remove('active'));
      
      // Add active class to clicked item
      this.classList.add('active');
      
      // Hide all sections
      document.querySelectorAll('.content-section').forEach(s => {
        s.classList.remove('active');
      });
      
      // Show selected section
      const sectionEl = document.getElementById(section);
      if (sectionEl) {
        sectionEl.classList.add('active');
        
        // Update title
        const titles = {
          'dashboard': 'Dashboard',
          'courses': 'Courses',
          'materials': 'Course Materials',
          'ai': 'AI Companion'
        };
        document.getElementById('section-title').textContent = titles[section] || 'Dashboard';
      }
    });
  });
}

/**
 * Toggle profile popup
 */
function toggleProfilePopup() {
  const popup = document.getElementById('profilePopup');
  popup.classList.toggle('hidden');
}

/**
 * Load profile into popup
 */
function loadProfilePopup(session) {
  document.getElementById('profileFullName').textContent = session.full_name || '-';
  document.getElementById('profileEmail').textContent = session.email || '-';
  document.getElementById('profileMatricNo').textContent = session.matric_no || '-';
  document.getElementById('profileProgramme').textContent = session.programme || '-';
  document.getElementById('profileLevel').textContent = session.level || '-';
  document.getElementById('profilePhone').textContent = session.phone || '-';
}

/**
 * Load dashboard data (news and timetable)
 */
async function loadDashboardData() {
  await loadNews();
  await loadTimetable();
}

/**
 * Load news from database
 */
async function loadNews() {
  try {
    console.log('Loading news for level:', currentSession.level);
    
    // Fetch news for student's level and for "All" level
    const url = `/api/news?level=${encodeURIComponent(currentSession.level)}`;
    console.log('Fetching news from:', url);
    
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    console.log('News loaded:', data);

    const newsList = document.getElementById('newsList');
    
    if (!data || data.length === 0) {
      newsList.innerHTML = '<div class="empty-state"><p>No news available</p></div>';
      return;
    }

    newsList.innerHTML = data.map(item => `
      <div class="news-item">
        <h4>${item.title || 'Untitled'}</h4>
        <p>${item.content || '-'}</p>
        <small style="color: #9ca3af;">
          ${new Date(item.created_at).toLocaleDateString()}
        </small>
      </div>
    `).join('');

  } catch (error) {
    console.error('Error loading news:', error);
    document.getElementById('newsList').innerHTML = '<div class="empty-state"><p>Error loading news</p></div>';
  }
}

/**
 * Load timetable from backend API with real-time day filtering
 */
async function loadTimetable() {
  try {
    const timetableList = document.getElementById('timetableList');
    timetableList.innerHTML = '<p class="loading">Loading timetable...</p>';

    const programme = currentSession.programme;
    const level = currentSession.level;

    if (!programme || !level) {
      timetableList.innerHTML = '<div class="empty-state"><p>Programme or level not set</p></div>';
      return;
    }

    // Get semester from selector if available, otherwise default to first-semester
    const semesterSelect = document.getElementById('semesterSelect');
    const semester = semesterSelect && semesterSelect.value ? semesterSelect.value : 'first-semester';

    const url = `/api/admin/timetable?programme=${encodeURIComponent(programme)}&level=${encodeURIComponent(level)}&semester=${encodeURIComponent(semester)}`;
    console.log('Loading timetable from:', url);
    
    const response = await fetch(url);
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    console.log('Timetable data:', data);
    
    // Get current day of week
    const now = new Date();
    const currentDayIndex = now.getDay(); // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
    const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const currentDayName = dayNames[currentDayIndex];
    
    // Determine what days to show based on current day
    let showToday = false;
    let showTomorrow = false;
    let todayDay = '';
    let tomorrowDay = '';
    let todayLabel = '';
    let tomorrowLabel = '';
    
    switch (currentDayName) {
      case 'Monday':
      case 'Tuesday':
      case 'Wednesday':
      case 'Thursday':
        showToday = true;
        showTomorrow = true;
        todayDay = currentDayName;
        tomorrowDay = dayNames[currentDayIndex + 1];
        todayLabel = 'Today';
        tomorrowLabel = 'Tomorrow';
        break;
      case 'Friday':
        showToday = true;
        showTomorrow = false;
        todayDay = currentDayName;
        todayLabel = 'Today';
        break;
      case 'Saturday':
        // No schedule for Saturday
        timetableList.innerHTML = '<div class="empty-state"><p>No schedule for Saturday</p></div>';
        return;
      case 'Sunday':
        showToday = false;
        showTomorrow = true;
        tomorrowDay = 'Monday';
        tomorrowLabel = 'Tomorrow (Monday)';
        break;
    }
    
    // Check if data is a dictionary with days or an array
    let allSlots = [];
    
    if (Array.isArray(data)) {
      // If it's an array, use it directly
      allSlots = data;
    } else if (typeof data === 'object' && data !== null) {
      // If it's a dictionary organized by days, flatten it
      const dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      for (const day of dayOrder) {
        if (data[day] && Array.isArray(data[day])) {
          for (const slot of data[day]) {
            allSlots.push({
              ...slot,
              day: day
            });
          }
        }
      }
    }
    
    if (!allSlots || allSlots.length === 0) {
      timetableList.innerHTML = '<div class="empty-state"><p>No timetable available</p></div>';
      return;
    }

    // Filter slots for today and tomorrow
    const todaySlots = showToday ? allSlots.filter(slot => slot.day === todayDay) : [];
    const tomorrowSlots = showTomorrow ? allSlots.filter(slot => slot.day === tomorrowDay) : [];
    
    // Sort slots by time
    const sortByTime = (slots) => {
      return slots.sort((a, b) => {
        const timeA = a.time || '00:00';
        const timeB = b.time || '00:00';
        return timeA.localeCompare(timeB);
      });
    };
    
    const sortedTodaySlots = sortByTime(todaySlots);
    const sortedTomorrowSlots = sortByTime(tomorrowSlots);
    
    // Generate HTML
    let html = '';
    
    if (showToday && sortedTodaySlots.length > 0) {
      html += `
        <div class="timetable-section">
          <h4 class="section-title">${todayLabel} (${todayDay})</h4>
          <div class="timetable-items">
            ${sortedTodaySlots.map(item => `
              <div class="timetable-item">
                <div>
                  <p style="font-weight: 600; margin-bottom: 4px;">${item.course_code || item.code || 'N/A'}</p>
                  ${item.venue ? `<p style="font-size: 12px; color: #666;">${item.venue}</p>` : ''}
                  ${item.lecturer ? `<p style="font-size: 12px; color: #888; font-style: italic;">${item.lecturer}</p>` : ''}
                </div>
                <span class="time-slot">${item.time || 'N/A'}</span>
              </div>
            `).join('')}
          </div>
        </div>
      `;
    } else if (showToday) {
      html += `
        <div class="timetable-section">
          <h4 class="section-title">${todayLabel} (${todayDay})</h4>
          <div class="empty-state"><p>No schedule for today</p></div>
        </div>
      `;
    }
    
    if (showTomorrow && sortedTomorrowSlots.length > 0) {
      html += `
        <div class="timetable-section">
          <h4 class="section-title">${tomorrowLabel}</h4>
          <div class="timetable-items">
            ${sortedTomorrowSlots.map(item => `
              <div class="timetable-item">
                <div>
                  <p style="font-weight: 600; margin-bottom: 4px;">${item.course_code || item.code || 'N/A'}</p>
                  ${item.venue ? `<p style="font-size: 12px; color: #666;">${item.venue}</p>` : ''}
                  ${item.lecturer ? `<p style="font-size: 12px; color: #888; font-style: italic;">${item.lecturer}</p>` : ''}
                </div>
                <span class="time-slot">${item.time || 'N/A'}</span>
              </div>
            `).join('')}
          </div>
        </div>
      `;
    } else if (showTomorrow) {
      html += `
        <div class="timetable-section">
          <h4 class="section-title">${tomorrowLabel}</h4>
          <div class="empty-state"><p>No schedule for tomorrow</p></div>
        </div>
      `;
    }
    
    if (!html) {
      html = '<div class="empty-state"><p>No schedule available</p></div>';
    }
    
    timetableList.innerHTML = html;

  } catch (error) {
    console.error('Error loading timetable:', error);
    document.getElementById('timetableList').innerHTML = '<div class="empty-state"><p>Error loading timetable</p></div>';
  }
}

/**
 * Load courses for the courses section (dashboard)
 */
async function loadCoursesForDashboard() {
  try {
    const { data, error } = await supabaseClient
      .from('courses')
      .select('*')
      .eq('level', currentSession.level)
      .eq('programme', currentSession.programme)
      .order('course_code', { ascending: true });

    if (error) throw error;

    const coursesList = document.getElementById('coursesList');
    
    if (!data || data.length === 0) {
      coursesList.innerHTML = '<div class="empty-state"><p>No courses available</p></div>';
      return;
    }

    coursesList.innerHTML = data.map(item => `
      <div class="course-item">
        <h4>${item.course_title || 'Untitled Course'}</h4>
        <p class="course-code"><strong>Code:</strong> ${item.course_code || 'N/A'}</p>
        <p><strong>Units:</strong> ${item.course_units || 1}</p>
      </div>
    `).join('');

  } catch (error) {
    console.error('Error loading courses:', error);
    document.getElementById('coursesList').innerHTML = '<div class="empty-state"><p>Error loading courses</p></div>';
  }
}

/**
 * Load materials filters (semesters)
 */
async function loadMaterialsFilters() {
  try {
    const semesterSelect = document.getElementById('semesterSelect');
    
    // Clear existing options
    semesterSelect.innerHTML = '<option value="">-- Select Semester --</option>';
    
    // Add hardcoded semesters
    const semesters = [
      { value: 'first-semester', label: 'First Semester' },
      { value: 'second-semester', label: 'Second Semester' }
    ];
    
    semesters.forEach(semester => {
      const option = document.createElement('option');
      option.value = semester.value;
      option.textContent = semester.label;
      semesterSelect.appendChild(option);
    });

  } catch (error) {
    console.error('Error loading semester filters:', error);
  }
}

/**
 * Handle semester selection change
 */
async function onSemesterChange() {
  const semesterSelect = document.getElementById('semesterSelect');
  const courseSelect = document.getElementById('courseSelect');
  const materialsList = document.getElementById('materialsList');

  const selectedSemester = semesterSelect.value;

  if (!selectedSemester) {
    courseSelect.innerHTML = '<option value="">-- Select Course --</option>';
    materialsList.innerHTML = '<p class="loading">Select a semester first</p>';
    return;
  }

  try {
    console.log('Loading courses for:', {
      level: currentSession.level,
      programme: currentSession.programme,
      semester: selectedSemester
    });

    // Get courses from backend API instead of direct Supabase query
    const url = `/api/admin/courses?programme=${encodeURIComponent(currentSession.programme)}&level=${encodeURIComponent(currentSession.level)}&semester=${encodeURIComponent(selectedSemester)}`;
    console.log('Fetching from:', url);
    
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const courses = await response.json();
    console.log('Courses fetched:', courses);

    // Populate course dropdown
    courseSelect.innerHTML = '<option value="">-- Select Course --</option>';
    
    if (courses && courses.length > 0) {
      courses.forEach(course => {
        const option = document.createElement('option');
        option.value = course.course_code;
        option.textContent = `${course.course_code} - ${course.course_title} (${course.course_units || 1} units)`;
        courseSelect.appendChild(option);
      });
    } else {
      courseSelect.innerHTML = '<option value="">No courses in this semester</option>';
    }

    materialsList.innerHTML = '<p class="loading">Select a course to view materials</p>';

  } catch (error) {
    console.error('Error loading courses for semester:', error);
    materialsList.innerHTML = '<div class="empty-state"><p>Error loading courses</p></div>';
  }
}

/**
 * Handle course selection change
 */
async function onCourseChange() {
  const courseSelect = document.getElementById('courseSelect');
  const materialsList = document.getElementById('materialsList');

  const selectedCourseCode = courseSelect.value;

  if (!selectedCourseCode) {
    materialsList.innerHTML = '<p class="loading">Select a course to view materials</p>';
    return;
  }

  try {
    console.log('Loading materials for course code:', selectedCourseCode);
    
    // Try backend API first, fall back to direct Supabase if needed
    let materials = [];
    let useBackend = true;
    
    try {
      // Get materials for selected course from backend API
      const url = `/api/materials?programme=${encodeURIComponent(currentSession.programme)}&level=${encodeURIComponent(currentSession.level)}&course_code=${encodeURIComponent(selectedCourseCode)}`;
      console.log('Fetching materials from:', url);
      
      const response = await fetch(url, { timeout: 5000 });
      if (response.ok) {
        materials = await response.json();
        console.log('Materials loaded from backend:', materials);
      } else {
        console.warn('Backend API failed with status:', response.status);
        useBackend = false;
      }
    } catch (backendError) {
      console.warn('Backend API error, falling back to direct Supabase query:', backendError);
      useBackend = false;
    }
    
    // If backend failed, fetch directly from Supabase
    if (!useBackend || !materials || materials.length === 0) {
      console.log('Fetching directly from Supabase...');
      const { data, error } = await supabaseClient
        .from('materials')
        .select('*')
        .eq('programme', currentSession.programme)
        .eq('level', currentSession.level)
        .eq('course_code', selectedCourseCode);
      
      if (error) {
        console.error('Supabase error:', error);
        materialsList.innerHTML = '<div class="empty-state"><p>Error loading materials</p></div>';
        return;
      }
      
      materials = data || [];
      console.log('Materials loaded directly from Supabase:', materials);
    }

    if (!materials || materials.length === 0) {
      materialsList.innerHTML = '<div class="empty-state"><p>No materials available for this course</p></div>';
      return;
    }

    materialsList.innerHTML = materials.map(item => {
      const fileName = item.material_name || '';
      const isPDF = fileName.toLowerCase().endsWith('.pdf');
      const isPPTX = fileName.toLowerCase().endsWith('.pptx');
      
      return `
      <div class="material-item">
        <span class="material-icon">📄</span>
        <div class="material-info">
          <p><strong>${item.material_name || 'Untitled Material'}</strong></p>
          <p style="font-size: 12px;">${item.course_code || 'N/A'}</p>
        </div>
        <div style="display: flex; gap: 10px; margin-top: 10px;">
          ${isPDF ? `<button class="material-view" onclick="viewPDFInline('${item.storage_path}', '${item.material_name}')">👁️ View PDF</button>` : ''}
          ${isPPTX ? `<button class="material-view" onclick="viewPPTXInline('${item.storage_path}', '${item.material_name}')">📊 View PPTX</button>` : ''}
          <button class="material-download" onclick="downloadMaterial('${item.storage_path}')">
            ⬇️ Download
          </button>
        </div>
      </div>
    `}).join('');

  } catch (error) {
    console.error('Error loading materials:', error);
    materialsList.innerHTML = '<div class="empty-state"><p>Error loading materials</p></div>';
  }
}

/**
 * Logout user
 */
function logout() {
  if (confirm('Are you sure you want to logout?')) {
    // Call logout from session.js
    if (typeof window.logout === 'function') {
      window.logout();
    } else {
      // Fallback if logout function not available
      console.warn('Logout function not found, redirecting to login');
    }
    setTimeout(() => {
      window.location.href = 'login.html';
    }, 500);
  }
}

// Close profile popup when clicking outside
document.addEventListener('click', function(e) {
  const popup = document.getElementById('profilePopup');
  const profileBtn = document.querySelector('.profile-btn');
  
  if (!popup.classList.contains('hidden') && 
      !popup.contains(e.target) && 
      !profileBtn.contains(e.target)) {
    popup.classList.add('hidden');
  }
});
