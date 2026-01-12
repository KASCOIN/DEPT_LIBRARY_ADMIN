/**
 * News Form Logic
 */
function initNewsForm() {
    const form = document.getElementById('form-news');
    if (!form) return;

    const nProgramme = document.getElementById('n-programme');
    const nLevelField = document.getElementById('n-level-field');
    const nLevel = document.getElementById('n-level');

    // Hide level dropdown when "All" is selected in programme
    nProgramme.addEventListener('change', () => {
        if (nProgramme.value === 'All') {
            nLevelField.style.display = 'none';
            nLevel.value = 'All';
        } else {
            nLevelField.style.display = 'block';
        }
    });

    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const formData = new FormData(form);
        const data = {
            programme: formData.get('programme'),
            level: formData.get('level'),
            title: formData.get('title'),
            body: formData.get('body')
        };

        try {
            const result = await API.post('/api/admin/news', data);
            if (result.success) {
                UI.notify("News posted successfully");
                form.reset();
            } else {
                UI.notify("Failed to post news: " + (result.message || "Unknown error"), false);
            }
        } catch (error) {
            UI.notify("Upload failed: " + error.message, false);
        }
    });
}

/**
 * View News Logic
 */
function initViewNews() {
    const viewNewsProgramme = document.getElementById('view-news-programme');
    const viewNewsLevelField = document.getElementById('view-news-level-field');
    const viewNewsLevel = document.getElementById('view-news-level');
    const newsLoadBtn = document.getElementById('news-load-btn');
    const newsList = document.getElementById('news-list');

    if (!viewNewsProgramme) return;

    // Hide level dropdown when "All" is selected in programme
    viewNewsProgramme.addEventListener('change', () => {
        if (viewNewsProgramme.value === 'All') {
            viewNewsLevelField.style.display = 'none';
            viewNewsLevel.value = 'All';
        } else {
            viewNewsLevelField.style.display = 'block';
        }
    });

    // Load news button
    newsLoadBtn.addEventListener('click', async () => {
        let programme = viewNewsProgramme.value;
        let level = viewNewsLevel.value;

        if (!programme) {
            UI.notify('Please select a programme', false);
            return;
        }

        // If programme is "All", level should also be "All"
        if (programme === 'All') {
            level = 'All';
        }

        if (!level) {
            UI.notify('Please select a level', false);
            return;
        }

        try {
            newsLoadBtn.disabled = true;
            newsLoadBtn.textContent = '⏳ Loading...';

            const url = `/api/news?programme=${encodeURIComponent(programme)}&level=${encodeURIComponent(level)}`;
            console.log('Loading news from:', url);
            const response = await fetch(url);

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const newsData = await response.json();
            console.log('News data received:', newsData);

            if (!newsData || newsData.length === 0) {
                newsList.innerHTML = '<p style="text-align: center; color: #999;">No news found</p>';
            } else {
                newsList.innerHTML = newsData.map(news => `
                    <div style="padding: 12px; border: 1px solid #ddd; border-radius: 6px; margin-bottom: 10px; background: #f9f9f9;">
                        <div style="display: flex; justify-content: space-between; align-items: start;">
                            <div style="flex: 1;">
                                <h4 style="margin: 0 0 8px 0; color: #333;">${news.title || 'Untitled'}</h4>
                                <p style="margin: 0 0 8px 0; color: #666; font-size: 14px;">${news.content || news.body || '-'}</p>
                                <small style="color: #999;">
                                    <strong>Programme:</strong> ${news.programme || 'N/A'} | 
                                    <strong>Level:</strong> ${news.level || 'N/A'} |
                                    ${news.created_at ? new Date(news.created_at).toLocaleDateString() : 'N/A'}
                                </small>
                            </div>
                            <button class="news-delete-btn" data-news-id="${news.id}" style="background: #dc3545; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer; margin-left: 10px;">🗑️ Delete</button>
                        </div>
                    </div>
                `).join('');

                // Attach delete handlers
                newsList.querySelectorAll('.news-delete-btn').forEach(btn => {
                    btn.addEventListener('click', async (e) => {
                        e.preventDefault();
                        const newsId = btn.dataset.newsId;
                        if (!newsId) {
                            UI.notify('News ID missing', false);
                            return;
                        }

                        if (!confirm('Are you sure you want to delete this news?')) {
                            return;
                        }

                        try {
                            btn.disabled = true;
                            btn.textContent = '⏳ Deleting...';

                            // Use direct DELETE request to delete from Supabase
                            const deleteResponse = await fetch('/api/news', {
                                method: 'DELETE',
                                headers: {
                                    'Content-Type': 'application/json'
                                },
                                body: JSON.stringify({ id: newsId })
                            });

                            if (deleteResponse.ok) {
                                const result = await deleteResponse.json();
                                if (result.success) {
                                    UI.notify('News deleted successfully');
                                    // Reload news list
                                    newsLoadBtn.click();
                                } else {
                                    UI.notify('Delete failed: ' + (result.message || 'Unknown error'), false);
                                    btn.disabled = false;
                                    btn.textContent = '🗑️ Delete';
                                }
                            } else {
                                const errorData = await deleteResponse.json();
                                UI.notify('Delete failed: ' + (errorData.message || `HTTP ${deleteResponse.status}`), false);
                                btn.disabled = false;
                                btn.textContent = '🗑️ Delete';
                            }
                        } catch (error) {
                            console.error('Delete error:', error);
                            UI.notify('Delete error: ' + error.message, false);
                            btn.disabled = false;
                            btn.textContent = '🗑️ Delete';
                        }
                    });
                });
            }

            newsLoadBtn.disabled = false;
            newsLoadBtn.textContent = 'Load News';
        } catch (error) {
            console.error('Error loading news:', error);
            newsList.innerHTML = `<p style="text-align: center; color: #d32f2f;">Error: ${error.message}</p>`;
            newsLoadBtn.disabled = false;
            newsLoadBtn.textContent = 'Load News';
        }
    });
}