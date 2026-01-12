/**
 * Master Admin Controller
 */
document.addEventListener('DOMContentLoaded', () => {
    // 1. Initialize Navigation
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', (e) => {
            document.querySelectorAll('.nav-item').forEach(i => i.classList.remove('active'));
            item.classList.add('active');
            UI.showSection(item.dataset.section);
        });
    });

    // 2. Handle URL parameters for direct programme/level access
    const params = new URLSearchParams(window.location.search);
    const urlProgramme = params.get('programme');
    const urlLevel = params.get('level');
    const urlSection = params.get('section') || 'dashboard';
    
    if (urlProgramme || urlLevel) {
        // Auto-select section if programme/level specified
        document.querySelectorAll('.nav-item').forEach(item => {
            if (item.dataset.section === 'courses') {
                item.classList.add('active');
            } else {
                item.classList.remove('active');
            }
        });
        UI.showSection('courses');
    } else if (urlSection) {
        document.querySelectorAll('.nav-item').forEach(item => {
            if (item.dataset.section === urlSection) {
                item.classList.add('active');
            } else {
                item.classList.remove('active');
            }
        });
        UI.showSection(urlSection);
    }

    // 3. Initialize Form Handlers
    initNewsForm();        // located in news.js
    initViewNews();        // located in news.js
    initMaterialsForm();   // located in materials.js
    initMaterialsManagement(); // located in materials.js
    initTimetableForm();   // located in timetable.js
    initCoursesForm();     // located in courses.js
    initCoursesManagement(); // located in courses.js
    if (typeof initDashboard === 'function') initDashboard();
    
    // 4. Apply URL parameters to form selectors after initialization
    if (urlProgramme) {
        const progSelect = document.getElementById('c-programme');
        if (progSelect) {
            progSelect.value = urlProgramme;
            progSelect.dispatchEvent(new Event('change'));
        }
    }
    if (urlLevel) {
        const levelSelect = document.getElementById('c-level');
        if (levelSelect) {
            levelSelect.value = urlLevel;
            levelSelect.dispatchEvent(new Event('change'));
        }
    }
});
