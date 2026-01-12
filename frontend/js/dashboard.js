// Dashboard logic: fetch and display recent uploads
function initDashboard(){
    const prog = document.getElementById('dash-programme');
    const lvl = document.getElementById('dash-level');

    async function loadAll(){
        const programme = prog.value === 'all' ? null : (prog.value === 'met' ? 'Meteorology' : 'Geography');
        const level = lvl.value === 'all' ? null : lvl.value;

        // helper to fetch and filter
        async function fetchAndFilter(endpoint){
            try {
                const data = await API.get(endpoint);
                return data.filter(item=>{
                    if (programme && String(item.programme).toLowerCase() !== programme.toLowerCase()) return false;
                    if (level && String(item.level) !== String(level)) return false;
                    return true;
                });
            } catch (error) {
                console.error(`Error fetching from ${endpoint}:`, error);
                return [];
            }
        }

        // Special handling for timetable which requires parameters
        async function fetchTimetables(){
            try {
                if (programme && level) {
                    // If both are selected, fetch specific timetable
                    const data = await API.get(`/api/timetable?programme=${encodeURIComponent(programme)}&level=${encodeURIComponent(level)}`);
                    return Array.isArray(data) ? data : [data];
                } else {
                    // If filtering is not specific, return empty (timetable requires parameters)
                    return [];
                }
            } catch (error) {
                console.error('Error fetching timetables:', error);
                return [];
            }
        }

        const [news, timetables, materials] = await Promise.all([
            fetchAndFilter('/api/news'),
            fetchTimetables(),
            fetchAndFilter('/api/materials')
        ]);

        const renderList = (elid, items, mapper)=>{
            const ul = document.getElementById(elid);
            ul.innerHTML='';
            items.slice(0,10).forEach(it=>{
                const li = document.createElement('li');
                li.textContent = mapper(it);
                ul.appendChild(li);
            });
        };

        renderList('dash-news', news, it => `${it.timestamp || ''} — ${it.title || it.body || ''}`);
        renderList('dash-timetable', timetables, it => `${it.timestamp || ''} — ${it.programme || ''} ${it.level || ''}`);
        renderList('dash-materials', materials, it => `${it.timestamp || ''} — ${it.title || it.filename || ''}`);
    }

    prog.addEventListener('change', loadAll);
    lvl.addEventListener('change', loadAll);
    loadAll();
}
