/**
 * Material Upload Logic
 */

// ============================================================
// GLOBAL UI LOCK - Prevents recursive UI refresh loops
// ============================================================
const uiLock = {
    _lockCount: 0,
    
    isLocked() {
        return this._lockCount > 0;
    },
    
    lock() {
        this._lockCount++;
        console.log(`[UI Lock] Locked (count: ${this._lockCount})`);
    },
    
    unlock() {
        if (this._lockCount > 0) {
            this._lockCount--;
            console.log(`[UI Lock] Unlocked (count: ${this._lockCount})`);
        }
    },
    
    // Execute function with lock held - prevents nested operations
    async withLock(fn) {
        this.lock();
        try {
            return await fn();
        } finally {
            this.unlock();
        }
    }
};

// ============================================================
// CHUNKED BASE64 CONVERSION - Handles large files safely
// ============================================================
function bufferToBase64(buffer) {
    const uint8Array = new Uint8Array(buffer);
    const chunkSize = 32768; // 32KB chunks to prevent stack overflow
    let binaryString = '';

    // Convert to binary string in chunks
    for (let i = 0; i < uint8Array.length; i += chunkSize) {
        const chunk = uint8Array.subarray(i, Math.min(i + chunkSize, uint8Array.length));
        binaryString += String.fromCharCode(...chunk);
    }

    // Convert binary string to base64
    return btoa(binaryString);
}

// ============================================================
// LOAD ADMIN MATERIALS QUEUE - Debounces and queues all calls
// ============================================================
const loadAdminMaterialsQueue = {
    _queue: [],
    _isProcessing: false,
    _lastCallTime: 0,
    _debounceDelay: 100, // ms
    
    // Add a call to the queue
    enqueue(programme, level, course) {
        this._queue.push({ programme, level, course, timestamp: Date.now() });
        this._processQueue();
    },
    
    // Process queue sequentially with debouncing
    async _processQueue() {
        if (this._isProcessing) return;
        
        this._isProcessing = true;
        
        while (this._queue.length > 0) {
            // Debounce: wait between calls
            const now = Date.now();
            const timeSinceLastCall = now - this._lastCallTime;
            if (timeSinceLastCall < this._debounceDelay) {
                await new Promise(resolve => setTimeout(resolve, this._debounceDelay - timeSinceLastCall));
            }
            
            // Get next item
            const item = this._queue.shift();
            this._lastCallTime = Date.now();
            
            // Skip if UI is locked (don't process during another operation)
            if (uiLock.isLocked()) {
                console.log('[Materials Queue] Skipping - UI is locked');
                continue;
            }
            
            try {
                await loadAdminMaterials(item.programme, item.level, item.course);
            } catch (error) {
                console.error('[Materials Queue] Error processing call:', error);
            }
        }
        
        this._isProcessing = false;
    },
    
    // Clear pending calls
    clear() {
        const count = this._queue.length;
        this._queue = [];
        console.log(`[Materials Queue] Cleared ${count} pending calls`);
    },
    
    get queueLength() {
        return this._queue.length;
    }
};

// ============================================================
// EVENT HANDLER ATTACHMENT FLAG - Ensures handlers attached once
// ============================================================
let _slotButtonHandlersAttached = false;

// Use SUPABASE_URL and SUPABASE_ANON_KEY from admin-config.js (already loaded)
// Note: supabaseClient is already created in admin-config.js

function initMaterialsForm() {
    const form = document.getElementById('form-materials');
    const programmeSelect = document.getElementById('m-programme');
    const levelSelect = document.getElementById('m-level');
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

    // Initialize file upload fields (only creates DOM once)
    let _fileFieldsInitialized = false;
    function initializeFileFields() {
        if (_fileFieldsInitialized) {
            // Already initialized - just reset to empty state without destroying DOM
            console.log('[File Fields] Already initialized, resetting slot states');
            resetSlotUI();
            return;
        }
        
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
        
        _fileFieldsInitialized = true;
        
        // Hide files container until course is selected
        filesContainer.style.display = 'none';
        
        console.log('[File Fields] Initialized DOM once');
    }
    
    // Reset all slots to empty state without destroying DOM
    function resetSlotUI() {
        for (let i = 1; i <= 30; i++) {
            const label = filesContainer.querySelector(`.slot-label-${i}`);
            const uploadBtn = filesContainer.querySelector(`.slot-upload-btn[data-slot="${i}"]`);
            const viewBtn = filesContainer.querySelector(`.slot-view-btn[data-slot="${i}"]`);
            const downloadBtn = filesContainer.querySelector(`.slot-download-btn[data-slot="${i}"]`);
            const deleteBtn = filesContainer.querySelector(`.slot-delete-btn[data-slot="${i}"]`);
            const fileInput = filesContainer.querySelector(`input[name="material_${i}"]`);
            const statusSpan = filesContainer.querySelector(`.slot-status-${i}`);
            
            if (label) label.innerHTML = `<strong>Material ${i}</strong>`;
            if (uploadBtn) {
                uploadBtn.disabled = false;
                uploadBtn.style.opacity = '1';
                uploadBtn.style.cursor = 'pointer';
                uploadBtn.textContent = '📤 Upload';
            }
            if (fileInput) fileInput.disabled = false;
            if (viewBtn) {
                viewBtn.disabled = true;
                viewBtn.style.opacity = '0.5';
                viewBtn.style.cursor = 'not-allowed';
            }
            if (downloadBtn) {
                downloadBtn.disabled = true;
                downloadBtn.style.opacity = '0.5';
                downloadBtn.style.cursor = 'not-allowed';
            }
            if (deleteBtn) {
                deleteBtn.disabled = true;
                deleteBtn.style.opacity = '0.5';
                deleteBtn.style.cursor = 'not-allowed';
            }
            if (statusSpan) statusSpan.textContent = 'Empty';
        }
    }

// Load courses based on programme and level
    async function loadCourses() {
        try {
            const prog = programmeSelect.value;
            const lvl = levelSelect.value;
            
            console.log(`Fetching courses for ${prog} Level ${lvl}...`);
            
            if (fetchStatus) {
                fetchStatus.textContent = '⏳ Loading...';
                fetchStatus.style.color = '#666';
            }
            
            // Clear course dropdown and form data
            courseSelect.innerHTML = '<option value="">-- Select a Course --</option>';
            courseSelect.value = '';
            courseTitleDisplay.style.display = 'none';
            
            // Validate selections
            if (!prog || !lvl) {
                if (fetchStatus) {
                    fetchStatus.textContent = 'Please select programme and level';
                    fetchStatus.style.color = '#dc3545';
                }
                return;
            }
            
            // Use query parameters to fetch only courses for the selected programme/level
            const url = `/api/admin/courses?programme=${encodeURIComponent(prog)}&level=${encodeURIComponent(lvl)}`;
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

    // Handle course selection with debouncing via queue
    let courseSelectTimeout = null;
    courseSelect.addEventListener('change', (e) => {
        // Clear any pending timeout
        if (courseSelectTimeout) {
            clearTimeout(courseSelectTimeout);
        }

        // Debounce the course selection to prevent rapid successive calls
        courseSelectTimeout = setTimeout(() => {
            // Check if we should ignore this change event (e.g., during form reset)
            if (courseSelect._ignoreChangeEvent) {
                console.log('Ignoring course change event (form reset in progress)');
                return;
            }

            if (e.target.value) {
                const selectedOption = e.target.options[e.target.selectedIndex];
                courseTitleSpan.textContent = selectedOption.dataset.title;
                courseTitleDisplay.style.display = 'block';
                filesContainer.style.display = 'block'; // Show files container when course selected

                // Load existing materials for this course from Supabase (via queue)
                const programme = programmeSelect.value;
                const level = levelSelect.value;
                const courseCode = e.target.value;

                console.log(`📂 Course selected: ${courseCode}. Loading materials via queue...`);
                loadAdminMaterialsQueue.enqueue(programme, level, courseCode);
            } else {
                courseTitleDisplay.style.display = 'none';
                filesContainer.style.display = 'none'; // Hide files container when no course selected
            }
        }, 100); // Small debounce delay
    });

    // Handle programme and level changes
    programmeSelect.addEventListener('change', () => {
        loadCourses();
    });
    levelSelect.addEventListener('change', () => {
        loadCourses();
    });

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

        const fileInputs = form.querySelectorAll('.material-file');
        const filesSelected = Array.from(fileInputs).filter(input => input.files.length > 0);

        if (filesSelected.length === 0) {
            UI.notify("Please select at least one file to upload", false);
            return;
        }

        // Use UI lock to prevent recursive calls during batch upload
        await uiLock.withLock(async () => {
            try {
                // Upload each selected file
                for (const fileInput of filesSelected) {
                    // Convert file to base64 using chunked function
                    const fileBuffer = await fileInput.files[0].arrayBuffer();
                    const fileBase64 = bufferToBase64(fileBuffer);

                    const uploadData = {
                        file_base64: fileBase64,
                        filename: fileInput.files[0].name,
                        programme: programme,
                        level: level,
                        course: selectedCourse,
                        title: fileInput.files[0].name
                    };

                    const result = await API.post('/api/admin/materials', uploadData, false);
                    if (!result.success) {
                        UI.notify("Upload failed for " + fileInput.files[0].name + ": " + (result.message || "Unknown error"), false);
                        return;
                    }
                }

                UI.notify(`Successfully uploaded ${filesSelected.length} file(s) to course ${selectedCourse}`);

                // Reset form without recreating DOM (just clear file inputs and reset slot states)
                form.reset();
                courseTitleDisplay.style.display = 'none';
                resetSlotUI(); // Use resetSlotUI instead of initializeFileFields

                // Queue materials reload after batch upload (lock will prevent immediate processing)
                setTimeout(() => {
                    loadAdminMaterialsQueue.enqueue(programme, level, selectedCourse);
                }, 500);
            } catch (error) {
                UI.notify("Upload failed: " + error.message, false);
            }
        });
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
async function loadAdminMaterials(filterProgramme = null, filterLevel = null, filterCourse = null) {
    if (!adminFilesContainer) {
        console.warn('Admin files container not available');
        return;
    }

    // Create a unique call signature to prevent duplicate concurrent calls with same parameters
    const callSignature = `${filterProgramme || 'null'}-${filterLevel || 'null'}-${filterCourse || 'null'}`;

    // Prevent concurrent calls with the same parameters to avoid recursion
    if (loadAdminMaterials._activeCalls && loadAdminMaterials._activeCalls.has(callSignature)) {
        console.warn(`loadAdminMaterials already in progress for same parameters: ${callSignature}, skipping`);
        return;
    }

    // Initialize the active calls set if it doesn't exist
    if (!loadAdminMaterials._activeCalls) {
        loadAdminMaterials._activeCalls = new Set();
    }

    // Add this call to active calls
    loadAdminMaterials._activeCalls.add(callSignature);

    try {
        // Build query string with filters
        let url = '/api/materials';
        const params = new URLSearchParams();

        console.log(`📥 loadAdminMaterials called with: programme='${filterProgramme}', level='${filterLevel}', course='${filterCourse}'`);

        if (filterProgramme) params.append('programme', filterProgramme);
        if (filterLevel) params.append('level', filterLevel);
        if (filterCourse) params.append('course_code', filterCourse);

        if (params.toString()) {
            url += '?' + params.toString();
        }

        console.log('🔍 Fetching materials from:', url);
        let materials = [];
        let useBackend = true;

        try {
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 5000);
            const response = await fetch(url, {
                signal: controller.signal,
                headers: {
                    'Cache-Control': 'no-cache'
                }
            });
            clearTimeout(timeoutId);

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
    } finally {
        // Always remove this call from active calls
        loadAdminMaterials._activeCalls.delete(callSignature);
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
                const filename = fileInput.files[0].name;
                const filesize = fileInput.files[0].size;
                
                console.log(`📤 Uploading material for slot ${i}: ${filename}`);
                console.log(`   Parameters: programme='${programme}', level='${level}', course='${selectedCourse}'`);
                
                // Use UI lock to prevent recursive calls during upload
                await uiLock.withLock(async () => {
                    try {
                        // Convert file to base64 using chunked function
                        const fileBuffer = await fileInput.files[0].arrayBuffer();
                        const fileBase64 = bufferToBase64(fileBuffer);
                        
                        const uploadData = {
                            file_base64: fileBase64,
                            filename: fileInput.files[0].name,
                            programme: programme,
                            level: level,
                            course: selectedCourse,
                            title: filename
                        };
                        
                        uploadBtn.disabled = true;
                        uploadBtn.textContent = '⏳ Uploading...';
                        
                        const result = await API.post('/api/admin/materials', uploadData, false);
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
                            
                            // Queue materials reload after upload (lock will be released first)
                            uploadBtn.textContent = '⏳ Updating...';
                            setTimeout(() => {
                                loadAdminMaterialsQueue.enqueue(programme, level, selectedCourse);
                                console.log(`✓ Materials reload queued for slot ${i}`);
                            }, 800);
                            
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
                });
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
                        // Use UI lock to prevent recursive calls during delete
                        await uiLock.withLock(async () => {
                            try {
                                deleteBtn.disabled = true;
                                deleteBtn.textContent = '⏳ Deleting...';
                                const response = await API.delete('/api/admin/materials', {
                                    storage_path: material.storage_path
                                });
                                if (response.success) {
                                    UI.notify(`Material ${material.filename || material.material_name || i} deleted successfully`);
                                    closePDFViewer();
                                    
                                    // Queue materials reload after delete (lock will be released first)
                                    setTimeout(() => {
                                        const programme = document.getElementById('m-programme').value;
                                        const level = document.getElementById('m-level').value;
                                        const course = document.getElementById('m-course-select').value;
                                        loadAdminMaterialsQueue.enqueue(programme, level, course);
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
                        });
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
    
    // Attach button handlers only once using global flag
    if (!_slotButtonHandlersAttached) {
        _slotButtonHandlersAttached = true;
        attachAdminSlotButtonHandlers();
        console.log('✓ Slot button handlers attached (once)');
    } else {
        console.log('✓ Slot button handlers already attached, skipping');
    }
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