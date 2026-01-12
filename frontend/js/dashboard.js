/**
 * Admin Dashboard
 * Displays current time, calendar, and students online
 */

let currentMonth = new Date().getMonth();
let currentYear = new Date().getFullYear();
let holidays = {}; // Store holidays in format YYYY-MM-DD: {name}
let loadedYears = new Set(); // Track which years have been loaded
let navigationLocked = false; // Prevent rapid clicking


// Initialize dashboard on page load
document.addEventListener('DOMContentLoaded', function() {
    initDashboard();
});

function initDashboard() {
    updateTime();
    loadHolidays();
    renderCalendar();
    updateOnlineStudents();
    
    // Update time every second
    setInterval(updateTime, 1000);
    
    // Setup calendar navigation
    const prevBtn = document.getElementById('prev-month');
    const nextBtn = document.getElementById('next-month');
    
    if (prevBtn) {
        prevBtn.addEventListener('click', function() {
            if (navigationLocked) return; // Prevent rapid clicks
            navigationLocked = true;
            
            console.log(`Before: Month=${currentMonth}, Year=${currentYear}`);
            currentMonth--;
            if (currentMonth < 0) {
                currentMonth = 11;
                currentYear--;
                loadHolidays();
            }
            console.log(`After: Month=${currentMonth}, Year=${currentYear}`);
            renderCalendar();
            
            setTimeout(() => { navigationLocked = false; }, 300);
        });
    }
    
    if (nextBtn) {
        nextBtn.addEventListener('click', function() {
            if (navigationLocked) return; // Prevent rapid clicks
            navigationLocked = true;
            
            console.log(`Before: Month=${currentMonth}, Year=${currentYear}`);
            currentMonth++;
            if (currentMonth > 11) {
                currentMonth = 0;
                currentYear++;
                loadHolidays();
            }
            console.log(`After: Month=${currentMonth}, Year=${currentYear}`);
            renderCalendar();
            
            setTimeout(() => { navigationLocked = false; }, 300);
        });
    }
    
    // Update online students every 30 seconds
    setInterval(updateOnlineStudents, 30000);
}

/**
 * Update current time and date
 */
function updateTime() {
    const now = new Date();
    
    // Format time as HH:MM:SS
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');
    const timeStr = `${hours}:${minutes}:${seconds}`;
    
    // Format date as MMM DD, YYYY
    const options = { year: 'numeric', month: 'long', day: 'numeric' };
    const dateStr = now.toLocaleDateString('en-US', options);
    
    const timeElement = document.getElementById('current-time');
    const dateElement = document.getElementById('current-date');
    
    if (timeElement) timeElement.textContent = timeStr;
    if (dateElement) dateElement.textContent = dateStr;
}

/**
 * Load public holidays for Nigeria
 */
async function loadHolidays() {
    // Skip if already loaded for this year
    if (loadedYears.has(currentYear)) {
        return;
    }
    
    try {
        const response = await fetch(`https://date.nager.at/api/v3/PublicHolidays/${currentYear}/NG`);
        const data = await response.json();
        
        data.forEach(holiday => {
            const dateStr = holiday.date;
            holidays[dateStr] = {
                name: holiday.name
            };
        });
        
        loadedYears.add(currentYear);
        console.log(`✓ Nigeria holidays loaded for ${currentYear}: ${Object.keys(holidays).length} holidays`);
    } catch (error) {
        console.warn(`Error loading holidays for ${currentYear}:`, error);
        // Mark as loaded anyway to avoid retrying
        loadedYears.add(currentYear);
    }
}

/**
 * Render calendar for current month
 */
function renderCalendar() {
    const monthYearElement = document.getElementById('month-year');
    const calendarGrid = document.getElementById('calendar-grid');
    
    if (!calendarGrid) return;
    
    // Update month/year display
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                       'July', 'August', 'September', 'October', 'November', 'December'];
    if (monthYearElement) {
        monthYearElement.textContent = `${monthNames[currentMonth]} ${currentYear}`;
    }
    
    // Clear calendar
    calendarGrid.innerHTML = '';
    
    // Add day headers
    const dayHeaders = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    dayHeaders.forEach(day => {
        const dayHeader = document.createElement('div');
        dayHeader.style.cssText = `
            font-weight: bold;
            text-align: center;
            padding: 6px 2px;
            background-color: #f0f0f0;
            border-radius: 3px;
            font-size: 12px;
        `;
        dayHeader.textContent = day;
        calendarGrid.appendChild(dayHeader);
    });
    
    // Get first day of month and number of days
    const firstDay = new Date(currentYear, currentMonth, 1).getDay();
    const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate();
    const today = new Date();
    
    // Add empty cells for days before month starts
    for (let i = 0; i < firstDay; i++) {
        const emptyCell = document.createElement('div');
        emptyCell.style.cssText = 'background-color: white;';
        calendarGrid.appendChild(emptyCell);
    }
    
    // Add day cells
    for (let day = 1; day <= daysInMonth; day++) {
        const dayCell = document.createElement('div');
        const dateStr = `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
        const holidayData = holidays[dateStr];
        const isHoliday = !!holidayData;
        
        dayCell.style.cssText = `
            padding: 6px 2px;
            text-align: center;
            border: 1px solid #e0e0e0;
            border-radius: 3px;
            cursor: pointer;
            background-color: white;
            transition: all 0.2s;
            font-size: 12px;
            position: relative;
        `;
        dayCell.textContent = day;
        
        // Highlight today
        if (day === today.getDate() && 
            currentMonth === today.getMonth() && 
            currentYear === today.getFullYear()) {
            dayCell.style.backgroundColor = '#2196F3';
            dayCell.style.color = 'white';
            dayCell.style.fontWeight = 'bold';
            dayCell.style.borderColor = '#2196F3';
        } 
        // Highlight holidays in red
        else if (isHoliday) {
            dayCell.style.backgroundColor = '#FFE5E5';
            dayCell.style.borderColor = '#FF6B6B';
            dayCell.style.color = '#D32F2F';
            dayCell.style.fontWeight = 'bold';
        }
        
        // Hover effect
        dayCell.addEventListener('mouseover', () => {
            if (isHoliday) {
                // Show tooltip for holidays
                const tooltip = document.createElement('div');
                tooltip.style.cssText = `
                    position: absolute;
                    bottom: 100%;
                    left: 50%;
                    transform: translateX(-50%);
                    background-color: #D32F2F;
                    color: white;
                    padding: 5px 8px;
                    border-radius: 3px;
                    font-size: 10px;
                    white-space: nowrap;
                    margin-bottom: 5px;
                    z-index: 1000;
                `;
                tooltip.textContent = holidayData.name;
                dayCell.appendChild(tooltip);
            } else if (!(day === today.getDate() && 
                  currentMonth === today.getMonth() && 
                  currentYear === today.getFullYear())) {
                dayCell.style.backgroundColor = '#e3f2fd';
            }
        });
        dayCell.addEventListener('mouseout', () => {
            // Remove tooltip
            const tooltip = dayCell.querySelector('div');
            if (tooltip) tooltip.remove();
            
            if (isHoliday) {
                dayCell.style.backgroundColor = '#FFE5E5';
            } else if (!(day === today.getDate() && 
                  currentMonth === today.getMonth() && 
                  currentYear === today.getFullYear())) {
                dayCell.style.backgroundColor = 'white';
            }
        });
        
        calendarGrid.appendChild(dayCell);
    }
}

/**
 * Update students online count
 * This is a placeholder - connect to real data source
 */
function updateOnlineStudents() {
    // Fetch and display active students from backend
    fetchActiveStudents().then(data => {
        const onlineCount = document.getElementById('online-count');
        const onlineList = document.getElementById('online-students-list');
        
        if (onlineCount) {
            onlineCount.textContent = data.count || 0;
        }
        
        if (onlineList) {
            if (!data.success || !data.students || data.students.length === 0) {
                onlineList.innerHTML = '<p style="text-align: center; color: #999;">No students online</p>';
            } else {
                onlineList.innerHTML = data.students.map(student => `
                    <div style="padding: 10px; border-bottom: 1px solid #eee;">
                        <strong>${student.full_name}</strong>
                        <br>
                        <small style="color: #999;">${student.programme} - Level ${student.level}</small>
                        <br>
                        <small style="color: #ccc;">Last seen: ${formatLastSeen(student.last_seen)}</small>
                    </div>
                `).join('');
            }
        }
    }).catch(error => {
        console.error('Failed to update online students:', error);
        const onlineList = document.getElementById('online-students-list');
        if (onlineList) {
            onlineList.innerHTML = '<p style="text-align: center; color: #999;">Error loading students</p>';
        }
    });
}
