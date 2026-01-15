/**
 * Timetable Form Logic
 * 
 * - Loads timetable data from Supabase based on programme/level/semester selection
 * - Displays slots for each day (empty if nothing in Supabase)
 * - Allows editing and uploading
 * - No localStorage - data only in memory for current session
 */

// Global state for timetable
let timetableState = {
    currentData: {},
    initialized: false
};

function initTimetableForm() {
    const form = document.getElementById('form-timetable');
    if (!form) return;

    const daySelect = document.getElementById('tt-day-select');
    const entriesContainer = document.getElementById('tt-entries');
    const progSelect = document.getElementById('tt-programme');
    const levelSelect = document.getElementById('tt-level');

    const DAYS = ["Monday","Tuesday","Wednesday","Thursday","Friday"];

    // Use global state for current editing session
    let currentData = timetableState.currentData;

    function makeRow(dayIndex, slotIndex, value={code:'',title:'',time:'08:00',duration:'1',venue:'',lecturer:''}){
        const row = document.createElement('div');
        row.className = 'tt-row';
        row.innerHTML = `
            <input data-slot="${slotIndex}" class="tt-code" placeholder="Course code" value="${value.code}">
            <input data-slot="${slotIndex}" class="tt-title" placeholder="Course title" value="${value.title}">
            <input data-slot="${slotIndex}" class="tt-time" type="time" placeholder="Time" value="${value.time || '08:00'}">
            <select data-slot="${slotIndex}" class="tt-duration">
                <option value="0.5" ${value.duration === '0.5' ? 'selected' : ''}>30 min</option>
                <option value="1" ${value.duration === '1' || !value.duration ? 'selected' : ''}>1 hour</option>
                <option value="1.5" ${value.duration === '1.5' ? 'selected' : ''}>1.5 hours</option>
                <option value="2" ${value.duration === '2' ? 'selected' : ''}>2 hours</option>
                <option value="2.5" ${value.duration === '2.5' ? 'selected' : ''}>2.5 hours</option>
                <option value="3" ${value.duration === '3' ? 'selected' : ''}>3 hours</option>
            </select>
            <input data-slot="${slotIndex}" class="tt-venue" placeholder="Venue" value="${value.venue}">
            <input data-slot="${slotIndex}" class="tt-lecturer" placeholder="Lecturer name" value="${value.lecturer}">
        `;
        return row;
    }

    function renderDay(day){
        entriesContainer.innerHTML = '';
        // Get data from memory for this day, or empty slots if nothing loaded
        let dayData = (currentData[day] && Array.isArray(currentData[day])) 
            ? currentData[day] 
            : [];
        
        // Check if this is the first load (no data in currentData for any day yet)
        const hasAnyData = Object.values(currentData).some(daySlots => 
            Array.isArray(daySlots) && daySlots.length > 0
        );
        
        // If no schedule data was loaded and we have no entries, show message but still render slots for input
        if (!hasAnyData && dayData.length === 0) {
            const msgDiv = document.createElement('div');
            msgDiv.style.padding = '20px';
            msgDiv.style.textAlign = 'center';
            msgDiv.style.color = '#666';
            msgDiv.style.fontSize = '14px';
            msgDiv.innerHTML = '<i class="fas fa-calendar-times" style="font-size: 24px; margin-right: 10px; color: #ccc;"></i> No schedule for this day';
            entriesContainer.appendChild(msgDiv);
            // continue to render slots so users can add entries
        }
        
        // Ensure we always have at least 5 slots, but don't exceed 6 slots total
        const desiredCount = Math.min(6, Math.max(5, dayData.length + 1));
        while (dayData.length < desiredCount) {
            dayData.push({code:'',title:'',time:'08:00',duration:'1',venue:'',lecturer:''});
        }
        
        dayData.forEach((slot,i)=> {
            const row = makeRow(DAYS.indexOf(day), i, slot);
            entriesContainer.appendChild(row);
        });
    }

    function getCurrentEdits(){
        const day = daySelect.value;
        const rows = Array.from(entriesContainer.querySelectorAll('.tt-row'));
        // Filter out header row(s) - only keep rows that contain an input for course code
        const dataRows = rows.filter(r => r.querySelector('.tt-code'));
        const slots = dataRows.map(r=>{
            const codeEl = r.querySelector('.tt-code');
            const titleEl = r.querySelector('.tt-title');
            const timeEl = r.querySelector('.tt-time');
            const durationEl = r.querySelector('.tt-duration');
            const venueEl = r.querySelector('.tt-venue');
            const lecturerEl = r.querySelector('.tt-lecturer');
            return {
                code: codeEl ? codeEl.value.trim() : '',
                title: titleEl ? titleEl.value.trim() : '',
                time: timeEl ? timeEl.value || '08:00' : '08:00',
                duration: durationEl ? durationEl.value : '1',
                venue: venueEl ? venueEl.value.trim() : '',
                lecturer: lecturerEl ? lecturerEl.value.trim() : ''
            };
        });
        return { day, slots };
    }

    // Delete all timetable slots for a specific day from Supabase
    async function deleteDay() {
        const day = daySelect.value;
        const prog = progSelect.value;
        const lvl = levelSelect.value;
        
        UI.showConfirmPopup({
            message: `Delete all timetable entries for <b>${day}</b>? This cannot be undone.`,
            confirmText: 'Delete',
            cancelText: 'Cancel',
            onConfirm: async () => {
                try {
                    const response = await fetch('/api/admin/timetable/day', {
                        method: 'DELETE',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            programme: prog,
                            level: lvl,
                            day: day
                        })
                    });
                    
                    if (response.ok) {
                        const result = await response.json();
                        UI.notify(`${result.message || 'Day timetable deleted successfully'}`);
                        // Clear from memory and re-render with empty slots
                        currentData[day] = [];
                        renderDay(day);
                    } else {
                        const error = await response.json();
                        UI.notify(`Delete failed: ${error.message || 'Unknown error'}`, false);
                    }
                } catch (error) {
                    UI.notify(`Delete error: ${error.message}`, false);
                }
            }
        });
    }

    // Load timetable from Supabase for selected day/prog/level
    async function loadFromSupabase() {
        try {
            const prog = progSelect.value;
            const lvl = levelSelect.value;
            const day = daySelect.value;
            
            const url = `/api/admin/timetable?programme=${encodeURIComponent(prog)}&level=${encodeURIComponent(lvl)}`;
            console.log('Loading timetable from:', url);
            const response = await fetch(url);
            
            if (!response.ok) {
                console.log('No timetable data in Supabase for this selection');
                // Clear memory - renderDay will create empty slots
                currentData = {};
                DAYS.forEach(d => {
                    currentData[d] = [];
                });
                renderDay(day);
                return;
            }
            
            const data = await response.json();
            console.log('Loaded timetable from Supabase:', data);
            
            // Store the loaded data in memory (no localStorage)
            currentData = {};
            DAYS.forEach(d => {
                if (data[d] && Array.isArray(data[d]) && data[d].length > 0) {
                    // Map database format to form format
                    currentData[d] = data[d].map(slot => ({
                        code: slot.course_code || '',
                        title: slot.course_title || '',
                        time: slot.time || '08:00',
                        duration: String(slot.duration || '1'),
                        venue: slot.venue || '',
                        lecturer: slot.lecturer || ''
                    }));
                } else {
                    // Store empty array - renderDay will pad it to 5 slots
                    currentData[d] = [];
                }
            });
            
            console.log('Timetable loaded from Supabase');
            
            // Render the current day with loaded data
            renderDay(day);
        } catch (error) {
            console.log('Could not load from Supabase:', error.message);
            // Clear - renderDay will create empty slots
            currentData = {};
            DAYS.forEach(d => {
                currentData[d] = [];
            });
            renderDay(daySelect.value);
        }
    }

    daySelect.addEventListener('change', ()=> {
        // Save current edits to memory before switching day
        const { day, slots } = getCurrentEdits();
        currentData[day] = slots;
        
        // Render the newly selected day
        renderDay(daySelect.value);
    });
    
    // Load button handler - explicitly load from Supabase
    const loadBtn = document.getElementById('tt-load-btn');
    if (loadBtn) {
        loadBtn.addEventListener('click', async (e) => {
            e.preventDefault();
            // Save current edits before loading new data
            const { day, slots } = getCurrentEdits();
            currentData[day] = slots;
            
            // Load from Supabase
            await loadFromSupabase();
        });
    }
    
    progSelect.addEventListener('change', () => {
        // Save current edits but don't auto-load - require user to click Load button
        const { day, slots } = getCurrentEdits();
        currentData[day] = slots;
    });
    
    levelSelect.addEventListener('change', () => {
        // Save current edits but don't auto-load - require user to click Load button
        const { day, slots } = getCurrentEdits();
        currentData[day] = slots;
    });

    // Delete day button handler
    const deleteDayBtn = document.getElementById('tt-delete-day-btn');
    if (deleteDayBtn) {
        // Remove old listeners by cloning
        const newDeleteBtn = deleteDayBtn.cloneNode(true);
        deleteDayBtn.parentNode.replaceChild(newDeleteBtn, deleteDayBtn);
        
        // Attach new listener
        const freshDeleteBtn = document.getElementById('tt-delete-day-btn');
        freshDeleteBtn.addEventListener('click', async (e) => {
            e.preventDefault();
            e.stopPropagation();
            await deleteDay();
        });
    }

    // Form submission
    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        
        // Save current day's edits
        const { day, slots } = getCurrentEdits();
        currentData[day] = slots;
        
        // Prepare payload (include current day so backend deletes/replaces only that day)
        const payload = {
            programme: progSelect.value,
            level: levelSelect.value,
            day: day, // current day from getCurrentEdits
            timetable: currentData
        };
        
        console.log('Uploading timetable:', payload);
        
        try {
            const response = await fetch('/api/admin/timetable', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            
            if (response.ok) {
                UI.notify('Timetable uploaded successfully');
                // Refresh from server to reflect saved data and re-render the current day
                await loadFromSupabase();
                renderDay(day);
            } else {
                const error = await response.json();
                UI.notify(`Upload failed: ${error.message || 'Unknown error'}`, false);
            }
        } catch (error) {
            UI.notify(`Upload error: ${error.message}`, false);
        }
    });

    // Initialize with empty arrays - renderDay will create 5 empty slots
    DAYS.forEach(d => {
        currentData[d] = [];
    });
    renderDay(daySelect.value);
}
document.addEventListener('DOMContentLoaded', () => {
    initTimetableForm();
});