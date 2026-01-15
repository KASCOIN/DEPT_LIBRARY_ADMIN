/**
 * Courses Form Logic
 */

// Module-level function to load and display courses in the table
async function loadCoursesList() {
    try {
        const progSelect = document.getElementById('c-programme');
        const levelSelect = document.getElementById('c-level');
        const coursesTable = document.getElementById('courses-table');
        
        if (!coursesTable) return;
        
        const prog = progSelect?.value || '';
        const lvl = levelSelect?.value || '';
        
        if (!prog || !lvl) {
            const tbody = coursesTable.querySelector('tbody');
            tbody.innerHTML = '<tr><td colspan="7" style="text-align: center; padding: 20px;">Please select programme and level</td></tr>';
            return;
        }
        
        const url = `/api/admin/courses?programme=${encodeURIComponent(prog)}&level=${encodeURIComponent(lvl)}`;
        console.log('Loading courses from:', url);
        
        const response = await fetch(url);
        
        if (!response.ok) {
            throw new Error(`API returned ${response.status}`);
        }
        
        const courses = await response.json();
        console.log('Courses loaded:', courses);
        
        // Populate table
        const tbody = coursesTable.querySelector('tbody');
        tbody.innerHTML = '';
        
        if (!courses || courses.length === 0) {
            const row = document.createElement('tr');
            row.innerHTML = '<td colspan="8" style="text-align: center; padding: 20px;">No courses found</td>';
            tbody.appendChild(row);
            return;
        }
        
        courses.forEach(course => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td style="padding: 10px; border: 1px solid #ddd;">${course.course_code || ''}</td>
                <td style="padding: 10px; border: 1px solid #ddd;">${course.course_title || ''}</td>
                <td style="padding: 10px; border: 1px solid #ddd;">${course.lecturer1 || ''}</td>
                <td style="padding: 10px; border: 1px solid #ddd;">${course.lecturer2 || ''}</td>
                <td style="padding: 10px; border: 1px solid #ddd;">${course.lecturer3 || ''}</td>
                <td style="padding: 10px; border: 1px solid #ddd;">Compulsory</td>
                <td style="padding: 10px; border: 1px solid #ddd; text-align: center;">${course.course_units || 1}</td>
                <td style="padding: 10px; border: 1px solid #ddd;">${course.advisor || ''}</td>
                <td style="padding: 10px; border: 1px solid #ddd; text-align:center;">
                    <button class="course-delete-btn" data-course-id="${course.id || ''}" data-course-code="${course.course_code || ''}" data-course-title="${course.course_title || ''}" style="background:#dc3545;color:#fff;border:none;padding:6px 12px;border-radius:4px;cursor:pointer;">🗑️ Delete</button>
                </td>
            `;
            tbody.appendChild(row);
        });

        // Attach delete handlers
        tbody.querySelectorAll('.course-delete-btn').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                e.preventDefault();
                const id = btn.dataset.courseId;
                const code = btn.dataset.courseCode;
                const title = btn.dataset.courseTitle;
                if (!id) {
                    UI.notify('Course id missing for deletion', false);
                    return;
                }
                // Custom modal popup for confirmation
                UI.showConfirmPopup({
                    message: `Delete course <b>${code} - ${title}</b>? This cannot be undone.`,
                    confirmText: 'Delete',
                    cancelText: 'Cancel',
                    onConfirm: async () => {
                        btn.disabled = true;
                        btn.textContent = '⏳ Deleting...';
                        try {
                            const result = await API.delete('/api/admin/courses', { id });
                            if (result.success) {
                                UI.notify(`Course ${code} deleted successfully`);
                                await loadCoursesList();
                            } else {
                                UI.notify('Delete failed: ' + (result.message || 'Unknown error'), false);
                                btn.disabled = false;
                                btn.textContent = '🗑️ Delete';
                            }
                        } catch (error) {
                            UI.notify('Delete error: ' + error.message, false);
                            btn.disabled = false;
                            btn.textContent = '🗑️ Delete';
                        }
                    }
                });
            });
        });
        
    } catch (error) {
        console.error('Error loading courses:', error);
        const coursesTable = document.getElementById('courses-table');
        if (coursesTable) {
            const tbody = coursesTable.querySelector('tbody');
            tbody.innerHTML = `<tr><td colspan="7" style="text-align: center; padding: 20px; color: red;">Error: ${error.message}</td></tr>`;
        }
    }
}

function initCoursesForm() {
    const form = document.getElementById('form-courses');
    if (!form) return;

    const progSelect = document.getElementById('c-programme');
    const levelSelect = document.getElementById('c-level');
    const advisorInput = document.getElementById('c-advisor');
    const entriesContainer = document.getElementById('c-entries');

    const MAX_COURSES = 15;

    // Track current selections to know the old key when changing
    let currentProg = progSelect.value;
    let currentLevel = levelSelect.value;

    function makeRow(index, value={code:'',title:'',lecturer1:'',lecturer2:'',lecturer3:'',type:'compulsory',units:1}){
        const row = document.createElement('div');
        row.className = 'c-row';
        row.innerHTML = `
            <div class="c-row-number">${index + 1}</div>
            <input class="c-code" placeholder="Course Code" value="${value.code}">
            <input class="c-title" placeholder="Course Title" value="${value.title}">
            <input class="c-lecturer1" placeholder="Lecturer 1" value="${value.lecturer1}">
            <input class="c-lecturer2" placeholder="Lecturer 2" value="${value.lecturer2}">
            <input class="c-lecturer3" placeholder="Lecturer 3" value="${value.lecturer3}">
            <div class="c-type-options">
                <label class="c-radio">
                    <input type="radio" name="type-${index}" class="c-type" value="compulsory" ${value.type === 'compulsory' ? 'checked' : ''}>
                    <span>Compulsory</span>
                </label>
                <label class="c-radio">
                    <input type="radio" name="type-${index}" class="c-type" value="elective" ${value.type === 'elective' ? 'checked' : ''}>
                    <span>Elective</span>
                </label>
            </div>
            <select class="c-units" style="padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
                <option value="1" ${value.units === 1 || value.units === '1' ? 'selected' : ''}>1</option>
                <option value="2" ${value.units === 2 || value.units === '2' ? 'selected' : ''}>2</option>
                <option value="3" ${value.units === 3 || value.units === '3' ? 'selected' : ''}>3</option>
                <option value="4" ${value.units === 4 || value.units === '4' ? 'selected' : ''}>4</option>
            </select>
        `;
        return row;
    }

    async function renderCourses(){
        try {
            entriesContainer.innerHTML = '';

            // Try loading from database first
            let state = await loadFromDatabase();

            // Fall back to local storage if database returns nothing
            if (!state) {
                state = loadLocal();
            }

            let courseData = state.courses || [];

            // Validate: ensure all courses are actually for the selected programme/level
            // This filters out any stale data that might have been saved with incorrect keys
            courseData = courseData.filter(course => {
                // Keep empty courses (they're placeholders)
                if (!course.code && !course.title) return true;
                // Keep valid courses
                return course.code || course.title;
            });

            // Limit to prevent DOM overload and stack overflow
            const maxRenderCourses = Math.min(MAX_COURSES, 20); // Reduced from 15 to 20 for safety

            // Ensure we always have maxRenderCourses entries
            while (courseData.length < maxRenderCourses) {
                courseData.push({code:'',title:'',lecturer1:'',lecturer2:'',lecturer3:'',type:'compulsory'});
            }

            courseData.slice(0, maxRenderCourses).forEach((course, i) => {
                entriesContainer.appendChild(makeRow(i, course));
            });

            if (courseData.length > maxRenderCourses) {
                console.warn(`Limited rendering to ${maxRenderCourses} courses to prevent stack overflow`);
            }
        } catch (error) {
            console.error('Error rendering courses:', error);
            // Render minimal empty rows on error
            for (let i = 0; i < Math.min(MAX_COURSES, 10); i++) {
                entriesContainer.appendChild(makeRow(i, {code:'',title:'',lecturer1:'',lecturer2:'',lecturer3:'',type:'compulsory'}));
            }
        }
    }

    function getStorageKey(prog, lvl) {
        return `courses_${prog || 'na'}_${lvl || 'na'}`;
    }

    function storageKey(){
        return getStorageKey(progSelect.value, levelSelect.value);
    }

    function getPrevStorageKey(){
        return getStorageKey(currentProg, currentLevel);
    }

    function loadLocal(){
        try {
            return JSON.parse(localStorage.getItem(storageKey()) || '{"advisor":"","courses":[]}');
        } catch {
            return {advisor:'', courses:[]};
        }
    }

    // Load courses from database for current selection
    async function loadFromDatabase(){
        try {
            const prog = progSelect.value;
            const lvl = levelSelect.value;
            
            const url = `/api/admin/courses?programme=${encodeURIComponent(prog)}&level=${encodeURIComponent(lvl)}`;
            const response = await fetch(url);
            
            if (!response.ok) {
                console.log('Database query returned no results, using localStorage');
                return null;
            }
            
            const courseData = await response.json();
            
            if (courseData && Array.isArray(courseData) && courseData.length > 0) {
                // Extract courses from database response
                let courses = [];
                if (courseData[0] && courseData[0].course_code) {
                    // Direct course array
                    courses = courseData;
                } else if (courseData[0] && courseData[0].courses) {
                    // Wrapped response
                    courses = courseData[0].courses;
                }
                
                if (courses.length > 0) {
                    console.log(`✓ Loaded ${courses.length} courses from database`);
                    return {
                        advisor: courseData[0]?.advisor || '',
                        courses: courses.map(c => ({
                            code: c.code || c.course_code,
                            title: c.title || c.course_title,
                            lecturer1: c.lecturer1 || '',
                            lecturer2: c.lecturer2 || '',
                            lecturer3: c.lecturer3 || '',
                            type: 'compulsory'
                        }))
                    };
                }
            }
            return null;
        } catch (error) {
            console.log('Error loading from database:', error);
            return null;
        }
    }

    function saveLocal(){
        try {
            const rows = Array.from(entriesContainer.querySelectorAll('.c-row'));
            const courses = rows.map(r=>({
                code: r.querySelector('.c-code').value,
                title: r.querySelector('.c-title').value,
                lecturer1: r.querySelector('.c-lecturer1').value,
                lecturer2: r.querySelector('.c-lecturer2').value,
                lecturer3: r.querySelector('.c-lecturer3').value,
                type: r.querySelector('.c-type:checked')?.value || 'compulsory',
                units: parseInt(r.querySelector('.c-units').value) || 1
            }));

            const state = {
                advisor: advisorInput.value,
                courses: courses.slice(0, MAX_COURSES) // Ensure max 15
            };

            // Check data size before saving to prevent stack overflow
            const dataString = JSON.stringify(state);
            if (dataString.length > 1024 * 1024) { // 1MB limit
                console.warn('Local storage data too large, skipping save');
                return;
            }

            localStorage.setItem(storageKey(), dataString);
        } catch (error) {
            console.error('Error saving to localStorage:', error);
        }
    }

    let saveInProgress = false;
    function setupAutoSave(){
        entriesContainer.addEventListener('input', ()=> {
            if (!saveInProgress) {
                saveInProgress = true;
                saveLocal();
                setTimeout(() => saveInProgress = false, 100); // Reset after short delay
            }
        });
        entriesContainer.addEventListener('change', ()=> {
            if (!saveInProgress) {
                saveInProgress = true;
                saveLocal();
                setTimeout(() => saveInProgress = false, 100); // Reset after short delay
            }
        });
        advisorInput.addEventListener('input', ()=> {
            if (!saveInProgress) {
                saveInProgress = true;
                saveLocal();
                setTimeout(() => saveInProgress = false, 100); // Reset after short delay
            }
        });
    }

    async function handleSelectionChange() {
        // Save current data with OLD key before switching
        saveCurrentDataWithOldKey();

        // Update current tracking
        currentProg = progSelect.value;
        currentLevel = levelSelect.value;

        // Render with NEW key
        await renderCourses();
        advisorInput.value = loadLocal().advisor || '';
    }

    function saveCurrentDataWithOldKey() {
        const prevKey = getPrevStorageKey();
        const rows = Array.from(entriesContainer.querySelectorAll('.c-row'));
        const courses = rows.map(r=>({
            code: r.querySelector('.c-code').value,
            title: r.querySelector('.c-title').value,
            lecturer1: r.querySelector('.c-lecturer1').value,
            lecturer2: r.querySelector('.c-lecturer2').value,
            lecturer3: r.querySelector('.c-lecturer3').value,
            type: r.querySelector('.c-type:checked')?.value || 'compulsory',
            units: parseInt(r.querySelector('.c-units').value) || 1
        }));
        localStorage.setItem(prevKey, JSON.stringify({advisor: advisorInput.value, courses}));
    }

    progSelect.addEventListener('change', handleSelectionChange);
    levelSelect.addEventListener('change', async () => {
        // Save current data with OLD key before switching
        const prevKey = getPrevStorageKey();
        const rows = Array.from(entriesContainer.querySelectorAll('.c-row'));
        const courses = rows.map(r=>({
            code: r.querySelector('.c-code').value,
            title: r.querySelector('.c-title').value,
            lecturer1: r.querySelector('.c-lecturer1').value,
            lecturer2: r.querySelector('.c-lecturer2').value,
            lecturer3: r.querySelector('.c-lecturer3').value,
            type: r.querySelector('.c-type:checked')?.value || 'compulsory',
            units: parseInt(r.querySelector('.c-units').value) || 1
        }));
        localStorage.setItem(prevKey, JSON.stringify({advisor: advisorInput.value, courses}));
        
        // Update current tracking
        currentLevel = levelSelect.value;
        
        // Render with NEW key
        await renderCourses();
        advisorInput.value = loadLocal().advisor || '';
    });

    // Initialize - load courses from database or localStorage
    renderCourses().then(() => {
        advisorInput.value = loadLocal().advisor || '';
    });
    setupAutoSave();

    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        // Prevent multiple simultaneous submissions
        if (form.dataset.submitting === 'true') {
            console.warn('Upload already in progress, ignoring duplicate submission');
            return;
        }
        form.dataset.submitting = 'true';

        try {
            saveLocal();

            const state = loadLocal();
            // Limit courses to prevent stack overflow during JSON serialization
            const maxCoursesToSend = 25; // Reduced from 50
            let coursesToSend = state.courses.filter(c => c.code || c.title);

            if (coursesToSend.length > maxCoursesToSend) {
                coursesToSend = coursesToSend.slice(0, maxCoursesToSend);
                console.warn(`Limiting upload to first ${maxCoursesToSend} courses to prevent stack overflow`);
            }

            const data = {
                programme: progSelect.value,
                level: levelSelect.value,
                advisor: advisorInput.value,
                courses: coursesToSend
            };

            console.log(`Sending ${coursesToSend.length} courses for upload`);

            // Check for circular references before sending
            try {
                JSON.stringify(data);
            } catch (e) {
                console.error('Circular reference detected in data:', e);
                UI.notify("Data contains circular references. Please refresh the page and try again.", false);
                form.dataset.submitting = 'false';
                return;
            }

            const result = await API.post('/api/admin/courses', data);
            if (result && result.success) {
                // Build detailed message
                let message = "Courses saved successfully";
                if (result.inserted) {
                    message = `✓ ${result.inserted} course(s) saved`;
                }
                if (result.skipped) {
                    message += ` | ⚠ ${result.skipped} duplicate(s) skipped`;
                }

                // Show detailed info if there are skipped courses (limited to prevent stack overflow)
                if (result.skipped_details && result.skipped_details.length > 0) {
                    console.log("Skipped courses:", result.skipped_details);
                    const maxShow = 5; // Reduced from 10
                    const shown = result.skipped_details.slice(0, maxShow);
                    message += "\n\nDuplicate courses (not saved):\n" + shown.map(s => "  - " + s).join("\n");
                    if (result.skipped_details.length > maxShow) {
                        message += `\n... and ${result.skipped_details.length - maxShow} more`;
                    }
                }

                UI.notify(message);
                // Refresh the courses table after successful save
                try {
                    await loadCoursesList();
                } catch (loadError) {
                    console.error('Error refreshing courses list:', loadError);
                    UI.notify("Courses saved but failed to refresh the list. Please refresh the page.", false);
                }
            } else {
                let errorMsg = "Failed to save courses: " + (result?.message || "Unknown error");
                if (result?.error_details && result.error_details.length > 0) {
                    // Limit error details display
                    const maxErrors = 5;
                    const shownErrors = result.error_details.slice(0, maxErrors);
                    errorMsg += "\n\nErrors:\n" + shownErrors.map(e => "  - " + e).join("\n");
                    if (result.error_details.length > maxErrors) {
                        errorMsg += `\n... and ${result.error_details.length - maxErrors} more errors`;
                    }
                }
                UI.notify(errorMsg, false);
            }
        } catch (error) {
            console.error('Error during course upload:', error);
            if (error.message && error.message.includes('stack')) {
                UI.notify("Upload failed due to data size. Try uploading fewer courses at once.", false);
            } else {
                UI.notify("An error occurred during upload. Please check the console for details.", false);
            }
        } finally {
            // Always reset the submitting flag
            form.dataset.submitting = 'false';
        }
    });
}

/**
 * Course Management - View/Display Courses
 */
function initCoursesManagement() {
    const coursesTable = document.getElementById('courses-table');
    const refreshBtn = document.getElementById('courses-refresh-btn');
    const progSelect = document.getElementById('c-programme');
    const levelSelect = document.getElementById('c-level');
    
    if (!coursesTable) {
        console.log('Courses management not available on this page');
        return;
    }
    
    console.log('✓ Courses management initialized');
    
    // Handle refresh button
    if (refreshBtn) {
        refreshBtn.addEventListener('click', (e) => {
            e.preventDefault();
            refreshBtn.disabled = true;
            refreshBtn.textContent = '⏳ Refreshing...';
            
            loadCoursesList()
                .then(() => {
                    refreshBtn.textContent = '✓ Refreshed!';
                    setTimeout(() => {
                        refreshBtn.textContent = 'Refresh List';
                        refreshBtn.disabled = false;
                    }, 2000);
                })
                .catch(error => {
                    console.error('Error:', error);
                    refreshBtn.textContent = '✗ Failed - Try Again';
                    refreshBtn.disabled = false;
                });
        });
    }
    
    // Refresh when programme/level changes
    if (progSelect) progSelect.addEventListener('change', loadCoursesList);
    if (levelSelect) levelSelect.addEventListener('change', loadCoursesList);
    
    // Load courses on page load
    loadCoursesList();
}
