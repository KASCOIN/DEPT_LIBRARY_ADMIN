/**
 * Material Upload Logic
 */

// Initialize Supabase client for fallback queries
const SUPABASE_URL = "https://yecpwijvbiurqysxazva.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InllY3B3aWp2Yml1cnF5c3hhenZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5NTM1NzMsImV4cCI6MjA4MzUyOTU3M30.d9Azks_9e5ITT875tROI84RhbNyWsh1hgap4f9_CGXU";
const { createClient } = supabase;
const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

function initMaterialsForm() {
    const form = document.getElementById('form-materials');
    const programmeSelect = document.getElementById('m-programme');
    const levelSelect = document.getElementById('m-level');
    const semesterSelect = document.getElementById('m-semester');
    const courseSelect = document.getElementById('m-course-select');
    const courseTitleDisplay = document.getElementById('m-course-title-display');
    const courseTitleSpan = document.getElementById('m-course-title');
    const filesContainer = document.getElementById('m-files-container');
    const fetchBtn = document.getElementById('m-fetch-btn');
    const fetchStatus = document.getElementById('m-fetch-status');
    
    if (!form) {
        console.error('Materials form not found!');
        return;
    }
    
    console.log('✓ Materials form initialized');
    console.log('✓ Fetch button exists:', fetchBtn !== null);
    console.log('✓ Fetch status element exists:', fetchStatus !== null);

    // Initialize file upload fields
    function initializeFileFields() {
        filesContainer.innerHTML = '';
        for (let i = 1; i <= 30; i++) {
            const fieldDiv = document.createElement('div');
            fieldDiv.className = 'field';
            fieldDiv.style.cssText = 'border: 1px solid #e0e0e0; padding: 15px; border-radius: 8px; background: #f9f9f9;';
            fieldDiv.dataset.slotIndex = i;
            fieldDiv.innerHTML = `
                <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 10px;">
                    <label class="slot-label-${i}" style="flex: 1; margin-bottom: 0;"><strong>Material ${i}</strong></label>
                    <span class="slot-status-${i}" style="font-size: 12px; color: #666;"></span>
                </div>
                <div style="display: flex; gap: 8px; margin-bottom: 10px; align-items: center;">
                    <label class="custom-file-label" style="position: relative; display: inline-block; overflow: hidden; background: #667eea; color: #fff; border-radius: 4px; padding: 8px 18px; cursor: pointer; font-size: 13px; font-weight: 500;">
                        <input type="file" name="material_${i}" class="material-file" accept=".pdf,.docx,.ppt,.pptx,.doc" style="position: absolute; left: 0; top: 0; opacity: 0; width: 100%; height: 100%; cursor: pointer;">
                        Choose file
                    </label>
                </div>
                <div style="display: grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap: 8px;">
                    <button type="button" class="slot-upload-btn" data-slot="${i}" style="padding: 8px; background-color: #667eea; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 12px;">📤 Upload</button>
                    <button type="button" class="slot-view-btn" data-slot="${i}" disabled style="padding: 8px; background-color: #667eea; color: white; border: none; border-radius: 4px; cursor: not-allowed; font-size: 12px; opacity: 0.5;">👁️ View</button>
                    <button type="button" class="slot-download-btn" data-slot="${i}" disabled style="padding: 8px; background-color: #28a745; color: white; border: none; border-radius: 4px; cursor: not-allowed; font-size: 12px; opacity: 0.5;">⬇️ Download</button>
                    <button type="button" class="slot-delete-btn" data-slot="${i}" disabled style="padding: 8px; background-color: #dc3545; color: white; border: none; border-radius: 4px; cursor: not-allowed; font-size: 12px; opacity: 0.5;">🗑️ Delete</button>
                </div>
            `;
            filesContainer.appendChild(fieldDiv);
        }
        
        // Hide files container until course is selected
        filesContainer.style.display = 'none';
    }

    // Load courses based on programme, level, and semester
    async function loadCourses() {
        try {
            const prog = programmeSelect.value;
            const lvl = levelSelect.value;
            const sem = semesterSelect.value;
            
            console.log(`Fetching courses for ${prog} Level ${lvl} - ${sem}...`);
            
            if (fetchStatus) {
                fetchStatus.textContent = '⏳ Loading...';
                fetchStatus.style.color = '#666';
            }
            
            // Clear course dropdown and form data
            courseSelect.innerHTML = '<option value="">-- Select a Course --</option>';
            courseSelect.value = '';
            courseTitleDisplay.style.display = 'none';
            
            // Validate selections
            if (!prog || !lvl || !sem) {
                if (fetchStatus) {
                    fetchStatus.textContent = 'Please select programme, level, and semester';
                    fetchStatus.style.color = '#dc3545';
                }
                return;
            }
            
            // Use query parameters to fetch only courses for the selected programme/level/semester
            const url = `/api/admin/courses?programme=${encodeURIComponent(prog)}&level=${encodeURIComponent(lvl)}&semester=${encodeURIComponent(sem)}`;
            console.log('Calling API:', url);
            
            const response = await fetch(url);
            
            if (!response.ok) {
                throw new Error(`API returned ${response.status}`);
            }
            
            const data = await response.json();
            console.log('✓ API response received:', data);
            
            let courses = [];
            
            // Handle different response formats from database vs JSON fallback
            if (Array.isArray(data)) {
                // Direct array response from database
                if (data.length > 0) {
                    if (data[0].course_code !== undefined) {
                        // Direct course array from database (course_code, course_title format)
                        courses = data;
                    } else if (data[0].code !== undefined) {
                        // Course array from database with different format (code, title)
                        courses = data;
                    } else if (data[0].courses !== undefined) {
                        // Wrapped response - first item has courses property
                        courses = data[0].courses;
                    }
                }
            } else if (data && data.courses !== undefined) {
                // Single object with courses array
                courses = data.courses;
            }
            
            if (courses && courses.length > 0) {
                // Deduplicate by code+title
                const seen = new Set();
                let uniqueCount = 0;
                courses.forEach(course => {
                    const code = course.code || course.course_code;
                    const title = course.title || course.course_title;
                    const key = code + '|' + title;
                    if (code && title && !seen.has(key)) {
                        seen.add(key);
                        uniqueCount++;
                        const option = document.createElement('option');
                        option.value = code;
                        option.textContent = `${code} - ${title}`;
                        option.dataset.title = title;
                        courseSelect.appendChild(option);
                    }
                });
                if (fetchStatus) {
                    fetchStatus.textContent = `✓ ${uniqueCount} course(s) loaded`;
                    fetchStatus.style.color = '#28a745';
                }
                console.log(`✓ ${courses.length} courses loaded`);
            } else {
                const noOption = document.createElement('option');
                noOption.disabled = true;
                noOption.textContent = '-- No courses available --';
                courseSelect.appendChild(noOption);
                
                if (fetchStatus) {
                    fetchStatus.textContent = `ℹ No courses available`;
                    fetchStatus.style.color = '#17a2b8';
                }
                console.log('No courses found');
            }
        } catch (error) {
            console.error('✗ Error loading courses:', error);
            if (fetchStatus) {
                fetchStatus.textContent = `✗ Error: ${error.message}`;
                fetchStatus.style.color = '#dc3545';
            }
            UI.notify('Error loading courses: ' + error.message, false);
        }
    }

    // Handle course selection
    courseSelect.addEventListener('change', (e) => {
        if (e.target.value) {
            const selectedOption = e.target.options[e.target.selectedIndex];
            courseTitleSpan.textContent = selectedOption.dataset.title;
            courseTitleDisplay.style.display = 'block';
            filesContainer.style.display = 'block'; // Show files container when course selected
            
            // Load existing materials for this course from Supabase
            const programme = programmeSelect.value;
            const level = levelSelect.value;
            const semester = semesterSelect ? semesterSelect.value : null;
            const courseCode = e.target.value;
            
            console.log(`📂 Course selected: ${courseCode}. Loading materials...`);
            loadAdminMaterials(programme, level, semester, courseCode);
        } else {
            courseTitleDisplay.style.display = 'none';
            filesContainer.style.display = 'none'; // Hide files container when no course selected
        }
    });

    // Handle programme, level, and semester changes
    programmeSelect.addEventListener('change', () => {
        loadCourses();
    });
    levelSelect.addEventListener('change', () => {
        loadCourses();
    });
    if (semesterSelect) {
        semesterSelect.addEventListener('change', () => {
            loadCourses();
        });
    }

    // Handle fetch button click
    if (fetchBtn) {
        fetchBtn.addEventListener('click', (e) => {
            e.preventDefault();
            console.log('Fetch Courses button clicked');
            
            fetchBtn.disabled = true;
            fetchBtn.textContent = '⏳ Fetching...';
            
            loadCourses()
                .then(() => {
                    console.log('✓ Courses loaded successfully');
                    fetchBtn.textContent = '✓ Fetched!';
                    setTimeout(() => {
                        fetchBtn.textContent = 'Fetch Courses';
                        fetchBtn.disabled = false;
                    }, 2000);
                })
                .catch(error => {
                    console.error('✗ Failed to load courses:', error);
                    fetchBtn.textContent = '✗ Failed - Try Again';
                    fetchBtn.disabled = false;
                });
        });
    } else {
        console.warn('✗ Fetch button not found!');
    }

    // Handle form submission
    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const selectedCourse = courseSelect.value;
        if (!selectedCourse) {
            UI.notify("Please select a course", false);
            return;
        }

        const programme = programmeSelect.value;
        const level = levelSelect.value;
        const semester = semesterSelect ? semesterSelect.value : null;
        
        // Require semester selection when the semester dropdown is present
        if (semesterSelect && (!semester || semester === '')) {
            UI.notify('Please select a semester (First or Second)', false);
            return;
        }

        const fileInputs = form.querySelectorAll('.material-file');
        const filesSelected = Array.from(fileInputs).filter(input => input.files.length > 0);
        
        if (filesSelected.length === 0) {
            UI.notify("Please select at least one file to upload", false);
            return;
        }

        try {
            // Upload each selected file
            for (const fileInput of filesSelected) {
                const formData = new FormData();
                formData.append('file', fileInput.files[0]);
                formData.append('programme', programme);
                formData.append('level', level);
                formData.append('course', selectedCourse);
                formData.append('title', fileInput.files[0].name);
                
                // Add semester if available
                if (semester) {
                    formData.append('semester', semester);
                }

                const result = await API.post('/api/admin/materials', formData, true);
                if (!result.success) {
                    UI.notify("Upload failed for " + fileInput.files[0].name + ": " + (result.message || "Unknown error"), false);
                    return;
                }
            }
            
            UI.notify(`Successfully uploaded ${filesSelected.length} file(s) to course ${selectedCourse}${semester ? ' (' + semester + ')' : ''}`);
            form.reset();
            courseTitleDisplay.style.display = 'none';
            initializeFileFields();
            
            // Reload materials after batch upload
            const prog = programmeSelect.value;
            const lvl = levelSelect.value;
            const sem = semesterSelect ? semesterSelect.value : null;
            setTimeout(() => {
                loadAdminMaterials(prog, lvl, sem, selectedCourse);
            }, 500);
        } catch (error) {
            UI.notify("Upload failed: " + error.message, false);
        }
    });

    // Initialize on load
    console.log('Initializing materials form');
    initializeFileFields();
    loadCourses().then(() => {
        console.log('Initial course load completed');
    }).catch(error => {
        console.error('Initial course load failed:', error);
    });
}

/**
 * Global material storage for admin materials management
 */
let adminSlotMaterials = {}; // { slotIndex: { material data } }
let adminFilesContainer = null;

/**
 * Load materials for a specific course from the backend API
 * This function is used to refresh the materials list in the admin portal
 */
async function loadAdminMaterials(filterProgramme = null, filterLevel = null, filterSemester = null, filterCourse = null) {
    if (!adminFilesContainer) {
        console.warn('Admin files container not available');
        return;
    }
    
    try {
        // Build query string with filters
        let url = '/api/materials';
        const params = new URLSearchParams();
        
        console.log(`📥 loadAdminMaterials called with: programme='${filterProgramme}', level='${filterLevel}', semester='${filterSemester}', course='${filterCourse}'`);
        
        if (filterProgramme) params.append('programme', filterProgramme);
        if (filterLevel) params.append('level', filterLevel);
        if (filterSemester) params.append('semester', filterSemester);
        if (filterCourse) params.append('course_code', filterCourse);
        
        if (params.toString()) {
            url += '?' + params.toString();
        }
        
        console.log('🔍 Fetching materials from:', url);
        let materials = [];
        let useBackend = true;
        
        try {
            const response = await fetch(url, { timeout: 5000 });
            if (response.ok) {
                materials = await response.json();
                console.log('📦 Materials loaded from API:', materials);
            } else {
                console.warn('Backend API failed, trying direct Supabase...');
                useBackend = false;
            }
        } catch (backendError) {
            console.warn('Backend API error, falling back to direct Supabase:', backendError);
            useBackend = false;
        }
        
        // If backend failed or no materials, try direct Supabase
        if (!useBackend || materials.length === 0) {
            console.log('📊 Fetching directly from Supabase...');
            let query = supabaseClient.from('materials').select('*');
            
            if (filterProgramme) query = query.eq('programme', filterProgramme);
            if (filterLevel) query = query.eq('level', filterLevel);
            if (filterSemester) query = query.eq('semester', filterSemester);
            if (filterCourse) query = query.eq('course_code', filterCourse);
            
            const { data, error } = await query;
            
            if (error) {
                throw new Error(`Supabase error: ${error.message}`);
            }
            
            materials = data || [];
            console.log('📦 Materials loaded from Supabase:', materials);
        }
        
        console.log(`📊 Received ${materials.length} materials`);
        
        // Reset slot materials
        adminSlotMaterials = {};
        
        // Assign filtered materials to slots (one material per slot)
        materials.forEach((material, index) => {
            if (index < 30) {
                adminSlotMaterials[index + 1] = material;
            }
        });
        
        console.log('🔧 Slot materials assigned:', adminSlotMaterials);
        
        // Update button states for each slot
        updateAdminButtonStates();
        
    } catch (error) {
        console.error('✗ Error loading materials:', error);
        UI.notify('Error loading materials: ' + error.message, false);
    }
}

/**
 * Update button states based on current slot materials
 */
function updateAdminButtonStates() {
    if (!adminFilesContainer) return;
    
    for (let i = 1; i <= 30; i++) {
        const hasMaterial = adminSlotMaterials[i] !== undefined;
        const uploadBtn = adminFilesContainer.querySelector(`.slot-upload-btn[data-slot="${i}"]`);
        const viewBtn = adminFilesContainer.querySelector(`.slot-view-btn[data-slot="${i}"]`);
        const downloadBtn = adminFilesContainer.querySelector(`.slot-download-btn[data-slot="${i}"]`);
        const deleteBtn = adminFilesContainer.querySelector(`.slot-delete-btn[data-slot="${i}"]`);
        const statusSpan = adminFilesContainer.querySelector(`.slot-status-${i}`);
        const fileInput = adminFilesContainer.querySelector(`input[name="material_${i}"]`);
        const label = adminFilesContainer.querySelector(`.slot-label-${i}`);
        
        if (hasMaterial) {
            const displayName = adminSlotMaterials[i].material_name || adminSlotMaterials[i].filename || '';
            console.log(`✓ Slot ${i} has material: ${displayName}`);
            
            // Material exists - disable upload and file input, enable others
            uploadBtn.disabled = true;
            uploadBtn.style.opacity = '0.5';
            uploadBtn.style.cursor = 'not-allowed';
            uploadBtn.textContent = '✓ Uploaded';
            if (fileInput) fileInput.disabled = true;
            
            // Set label to file name, green, with icon and size
            if (label) {
                const fname = displayName;
                let sizeText = '';
                if (typeof adminSlotMaterials[i].size_bytes === 'number' && !isNaN(adminSlotMaterials[i].size_bytes)) {
                    sizeText = ` <span style="color:#888;font-size:13px;">(${(adminSlotMaterials[i].size_bytes / (1024 * 1024)).toFixed(2)} MB)</span>`;
                }
                if (fname && typeof fname === 'string') {
                    const ext = fname.split('.').pop().toLowerCase();
                    let icon = '';
                    if (ext === 'pdf') icon = '📄';
                    else if (ext === 'ppt' || ext === 'pptx') icon = '📊';
                    else if (ext === 'doc' || ext === 'docx') icon = '📝';
                    else icon = '📁';
                    label.innerHTML = `<strong style="color:#28a745;display:flex;align-items:center;gap:6px;">${icon} ${fname}${sizeText}</strong>`;
                } else {
                    label.innerHTML = `<strong style="color:#28a745;">[No filename]</strong>`;
                }
            }
            
            viewBtn.disabled = false;
            viewBtn.style.opacity = '1';
            viewBtn.style.cursor = 'pointer';
            downloadBtn.disabled = false;
            downloadBtn.style.opacity = '1';
            downloadBtn.style.cursor = 'pointer';
            deleteBtn.disabled = false;
            deleteBtn.style.opacity = '1';
            deleteBtn.style.cursor = 'pointer';
            statusSpan.textContent = '';
        } else {
            // No material - enable upload and file input, disable others
            console.log(`✗ Slot ${i} is empty`);
            uploadBtn.disabled = false;
            uploadBtn.style.opacity = '1';
            uploadBtn.style.cursor = 'pointer';
            uploadBtn.textContent = '📤 Upload';
            if (fileInput) fileInput.disabled = false;
            if (label) label.innerHTML = `<strong>Material ${i}</strong>`;
            
            viewBtn.disabled = true;
            viewBtn.style.opacity = '0.5';
            viewBtn.style.cursor = 'not-allowed';
            downloadBtn.disabled = true;
            downloadBtn.style.opacity = '0.5';
            downloadBtn.style.cursor = 'not-allowed';
            deleteBtn.disabled = true;
            deleteBtn.style.opacity = '0.5';
            deleteBtn.style.cursor = 'not-allowed';
            statusSpan.textContent = 'Empty';
        }
    }
    
    console.log(`✓ Button states updated`);
}

/**
 * Attach event handlers for per-slot material operations (upload, view, download, delete)
 */
function attachAdminSlotButtonHandlers() {
    if (!adminFilesContainer) return;
    
    for (let i = 1; i <= 30; i++) {
        const uploadBtn = adminFilesContainer.querySelector(`.slot-upload-btn[data-slot="${i}"]`);
        const viewBtn = adminFilesContainer.querySelector(`.slot-view-btn[data-slot="${i}"]`);
        const downloadBtn = adminFilesContainer.querySelector(`.slot-download-btn[data-slot="${i}"]`);
        const deleteBtn = adminFilesContainer.querySelector(`.slot-delete-btn[data-slot="${i}"]`);
        const fileInput = adminFilesContainer.querySelector(`input[name="material_${i}"]`);
        
        // Upload button - upload file for this slot
        if (uploadBtn && !uploadBtn._materialHandlerAttached) {
            uploadBtn._materialHandlerAttached = true;
            uploadBtn.onclick = async (e) => {
                e.preventDefault();
                if (!fileInput || !fileInput.files.length) {
                    UI.notify(`Please select a file for Material ${i}`, false);
                    return;
                }
                
                const selectedCourse = document.getElementById('m-course-select').value;
                if (!selectedCourse) {
                    UI.notify('Please select a course first', false);
                    return;
                }
                
                const programme = document.getElementById('m-programme').value;
                const level = document.getElementById('m-level').value;
                const semester = document.getElementById('m-semester').value;
                const filename = fileInput.files[0].name;
                const filesize = fileInput.files[0].size;
                
                console.log(`📤 Uploading material for slot ${i}: ${filename}`);
                console.log(`   Parameters: programme='${programme}', level='${level}', semester='${semester}', course='${selectedCourse}'`);
                
                try {
                    const formData = new FormData();
                    formData.append('file', fileInput.files[0]);
                    formData.append('programme', programme);
                    formData.append('level', level);
                    formData.append('course', selectedCourse);
                    formData.append('title', filename);
                    if (semester) formData.append('semester', semester);
                    
                    uploadBtn.disabled = true;
                    uploadBtn.textContent = '⏳ Uploading...';
                    
                    const result = await API.post('/api/admin/materials', formData, true);
                    if (result.success) {
                        UI.notify(`Material ${i} uploaded successfully`);
                        fileInput.value = '';
                        
                        // Show filename in label immediately
                        const label = adminFilesContainer.querySelector(`.slot-label-${i}`);
                        if (label) {
                            const ext = filename.split('.').pop().toLowerCase();
                            let icon = '';
                            if (ext === 'pdf') icon = '📄';
                            else if (ext === 'ppt' || ext === 'pptx') icon = '📊';
                            else if (ext === 'doc' || ext === 'docx') icon = '📝';
                            else icon = '📁';
                            let sizeText = '';
                            if (typeof filesize === 'number' && !isNaN(filesize)) {
                                sizeText = ` <span style="color:#888;font-size:13px;">(${(filesize / (1024 * 1024)).toFixed(2)} MB)</span>`;
                            }
                            label.innerHTML = `<strong style="color:#28a745;display:flex;align-items:center;gap:6px;">${icon} ${filename}${sizeText}</strong>`;
                        }
                        
                        // Reload materials to update button states
                        uploadBtn.textContent = '⏳ Updating...';
                        await new Promise(resolve => setTimeout(resolve, 800));
                        await loadAdminMaterials(programme, level, semester, selectedCourse);
                        console.log(`✓ Materials reloaded for slot ${i}`);
                        
                    } else {
                        UI.notify(`Upload failed: ${result.message || 'Unknown error'}`, false);
                        uploadBtn.disabled = false;
                        uploadBtn.textContent = '📤 Upload';
                    }
                } catch (error) {
                    UI.notify(`Upload error: ${error.message}`, false);
                    uploadBtn.disabled = false;
                    uploadBtn.textContent = '📤 Upload';
                }
            };
        }
        
        // View button
        if (viewBtn && !viewBtn._materialHandlerAttached) {
            viewBtn._materialHandlerAttached = true;
            viewBtn.onclick = async (e) => {
                e.preventDefault();
                if (!adminSlotMaterials[i]) {
                    UI.notify(`No material in slot ${i}`, false);
                    return;
                }
                try {
                    await viewPDFInlineAdmin(adminSlotMaterials[i].storage_path, adminSlotMaterials[i].material_name || adminSlotMaterials[i].filename || 'Document');
                } catch (error) {
                    UI.notify('Error viewing material: ' + error.message, false);
                }
            };
        }
        
        // Download button
        if (downloadBtn && !downloadBtn._materialHandlerAttached) {
            downloadBtn._materialHandlerAttached = true;
            downloadBtn.onclick = async (e) => {
                e.preventDefault();
                if (!adminSlotMaterials[i]) {
                    UI.notify(`No material in slot ${i}`, false);
                    return;
                }
                
                try {
                    const response = await fetch('/api/student/materials/view', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ storage_path: adminSlotMaterials[i].storage_path })
                    });
                    const data = await response.json();
                    const signedUrl = data.signedURL || data.signed_url;
                    if (data.success && signedUrl) {
                        const link = document.createElement('a');
                        link.href = signedUrl;
                        link.download = adminSlotMaterials[i].filename || 'download';
                        document.body.appendChild(link);
                        link.click();
                        document.body.removeChild(link);
                    } else {
                        UI.notify('Failed to get signed URL: ' + (data.message || 'Unknown error'), false);
                    }
                } catch (error) {
                    UI.notify('Error downloading material: ' + error.message, false);
                }
            };
        }
        
        // Delete button
        if (deleteBtn && !deleteBtn._materialHandlerAttached) {
            deleteBtn._materialHandlerAttached = true;
            deleteBtn.onclick = async (e) => {
                e.preventDefault();
                if (!adminSlotMaterials[i]) {
                    UI.notify(`No material in slot ${i}`, false);
                    return;
                }
                
                const material = adminSlotMaterials[i];
                UI.showConfirmPopup({
                    message: `Delete material <b>${material.filename || material.material_name || 'file'}</b>? This cannot be undone.`,
                    confirmText: 'Delete',
                    cancelText: 'Cancel',
                    onConfirm: async () => {
                        try {
                            deleteBtn.disabled = true;
                            deleteBtn.textContent = '⏳ Deleting...';
                            const response = await API.delete('/api/admin/materials', {
                                storage_path: material.storage_path
                            });
                            if (response.success) {
                                UI.notify(`Material ${material.filename || material.material_name || i} deleted successfully`);
                                closePDFViewer();
                                setTimeout(async () => {
                                    const programme = document.getElementById('m-programme').value;
                                    const level = document.getElementById('m-level').value;
                                    const semester = document.getElementById('m-semester').value;
                                    const course = document.getElementById('m-course-select').value;
                                    await loadAdminMaterials(programme, level, semester, course);
                                }, 500);
                            } else {
                                UI.notify('Delete failed: ' + (response.message || 'Unknown error'), false);
                                deleteBtn.disabled = false;
                                deleteBtn.textContent = '🗑️ Delete';
                            }
                        } catch (error) {
                            UI.notify('Delete error: ' + error.message, false);
                            deleteBtn.disabled = false;
                            deleteBtn.textContent = '🗑️ Delete';
                        }
                    }
                });
            };
        }
    }
}

/**
 * Material Management Logic (Per-Slot)
 */
function initMaterialsManagement() {
    adminFilesContainer = document.getElementById('m-files-container');
    
    if (!adminFilesContainer) {
        console.log('Files container not available');
        return;
    }
    
    console.log('✓ Materials management (per-slot) initialized');
    
    // Attach button handlers for per-slot operations
    attachAdminSlotButtonHandlers();
}

// PDF.js-based inline viewer for admin (mirroring student.html)
async function viewPDFInlineAdmin(storagePath, filename) {
    try {
        const API_BASE = window.location.origin;
        // Get signed URL
        const response = await fetch(`${API_BASE}/api/student/materials/view`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ storage_path: storagePath })
        });
        if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
        const data = await response.json();
        if (!data.success) {
            alert(`Error: ${data.message || 'Unable to generate view URL'}`);
            return;
        }
        const signedUrl = data.signedURL || data.signed_url;
        // Show modal
        const modal = document.getElementById('pdfViewerModal');
        document.getElementById('pdfFileName').textContent = filename;
        document.getElementById('pdfLoadingSpinner').classList.add('active');
        modal.classList.add('active');
        // Use PDF.js to render
        if (typeof pdfjsLib !== 'undefined') {
            pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
            const loadingTask = pdfjsLib.getDocument({ url: signedUrl, withCredentials: false });
            loadingTask.promise.then(function(pdf) {
                window._adminPdfDoc = pdf;
                renderAllPagesAdmin();
                document.getElementById('pdfLoadingSpinner').classList.remove('active');
            }, function(reason) {
                alert(`Failed to load PDF: ${reason.message || reason}`);
                document.getElementById('pdfLoadingSpinner').classList.remove('active');
                closePDFViewer();
            });
        } else {
            // fallback: open in new tab
            window.open(signedUrl, '_blank');
        }
    } catch (error) {
        alert(`Failed to view PDF: ${error.message}`);
        document.getElementById('pdfLoadingSpinner').classList.remove('active');
        closePDFViewer();
    }
}

// Render all pages for admin PDF viewer
function renderAllPagesAdmin() {
    const pdf = window._adminPdfDoc;
    const container = document.getElementById('pdfPagesContainer');
    container.innerHTML = '';
    if (!pdf) return;
    for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
        pdf.getPage(pageNum).then(function(page) {
            const viewport = page.getViewport({ scale: 1.2 });
            const canvas = document.createElement('canvas');
            canvas.width = viewport.width;
            canvas.height = viewport.height;
            const context = canvas.getContext('2d');
            page.render({ canvasContext: context, viewport: viewport });
            container.appendChild(canvas);
        });
    }
}