/**
 * Student PDF Viewer Module
 * Provides secure PDF viewing functionality using Supabase signed URLs
 * 
 * Features:
 * - View PDFs inline using iframe
 * - Open PDFs in new tab
 * - Handle errors gracefully
 * - Mobile-friendly
 * - No PDF files stored locally
 */

const StudentPDFViewer = (() => {
    const API_BASE = window.location.origin;
    
    /**
     * Get a signed URL for viewing a PDF material
     * @param {string} storagePath - The storage path of the PDF file
     * @returns {Promise<Object>} - { signed_url, expires_in, success, error }
     */
    async function getViewUrl(storagePath) {
        try {
            const response = await fetch(`${API_BASE}/api/student/materials/view`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    storage_path: storagePath
                })
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data = await response.json();
            
            if (!data.success) {
                console.error('[StudentPDFViewer] Backend error details:', data);
                return {
                    success: false,
                    error: data.error || 'unknown_error',
                    message: data.message || 'Failed to generate view URL'
                };
            }

            // Support both signed_url (snake_case) and signedURL (camelCase) from backend
            return {
                success: true,
                signed_url: data.signed_url || data.signedURL,
                expires_in: data.expires_in,
                message: data.message
            };

        } catch (error) {
            console.error('Error getting view URL:', error);
            return {
                success: false,
                error: 'fetch_error',
                message: `Failed to get view URL: ${error.message}`
            };
        }
    }

    /**
     * View PDF in a new tab
     * @param {string} storagePath - The storage path of the PDF file
     * @param {string} filename - Optional filename for display
     */
    async function viewInNewTab(storagePath, filename = 'document.pdf') {
        console.log(`[StudentPDFViewer] Opening PDF in new tab: ${filename}`);
        
        try {
            const result = await getViewUrl(storagePath);
            
            if (!result.success) {
                alert(`Unable to view PDF: ${result.message}`);
                return;
            }

            // Open PDF in new tab
            window.open(result.signed_url, '_blank');
            console.log(`[StudentPDFViewer] PDF opened: ${filename}`);

        } catch (error) {
            console.error('[StudentPDFViewer] Error:', error);
            alert('An unexpected error occurred while opening the PDF.');
        }
    }

    /**
     * View PDF inline using iframe
     * Requires a modal or container with specific structure
     * 
     * Expected HTML structure:
     * <div id="pdfViewerModal" class="pdf-modal">
     *   <div class="pdf-modal-content">
     *     <div class="pdf-modal-header">
     *       <h3 id="pdfFileName">Document</h3>
     *       <button onclick="StudentPDFViewer.closePdfViewer()">✕</button>
     *     </div>
     *     <div class="pdf-modal-body">
     *       <iframe id="pdfViewerIframe"></iframe>
     *     </div>
     *   </div>
     * </div>
     * 
     * @param {string} storagePath - The storage path of the PDF file
     * @param {string} filename - Optional filename for display
     */
    async function viewInline(storagePath, filename = 'document.pdf') {
        console.log(`[StudentPDFViewer] Loading PDF inline: ${filename}`);
        
        try {
            // Get or create modal
            let modal = document.getElementById('pdfViewerModal');
            if (!modal) {
                console.warn('[StudentPDFViewer] Modal container not found. Creating one...');
                modal = createModalContainer();
            }

            const iframe = document.getElementById('pdfViewerIframe');
            const titleElement = document.getElementById('pdfFileName');
            
            if (!iframe) {
                alert('PDF viewer container not properly configured.');
                return;
            }

            // Update title
            if (titleElement) {
                titleElement.textContent = filename;
            }

            // Show loading state
            showLoadingState(true);
            iframe.style.display = 'none';

            // Get signed URL
            const result = await getViewUrl(storagePath);
            
            if (!result.success) {
                showLoadingState(false);
                alert(`Unable to view PDF: ${result.message}`);
                return;
            }

            // Set up iframe
            iframe.onload = () => {
                console.log(`[StudentPDFViewer] PDF loaded: ${filename}`);
                showLoadingState(false);
                iframe.style.display = 'block';
            };

            iframe.onerror = () => {
                console.error(`[StudentPDFViewer] Failed to load PDF: ${filename}`);
                showLoadingState(false);
                alert('Failed to load PDF. Please try opening in a new tab instead.');
            };

            iframe.src = result.signed_url;

            // Display modal
            modal.style.display = 'flex';
            console.log(`[StudentPDFViewer] PDF viewer opened: ${filename}`);

        } catch (error) {
            console.error('[StudentPDFViewer] Error:', error);
            showLoadingState(false);
            alert('An unexpected error occurred while loading the PDF.');
        }
    }

    /**
     * Close the PDF viewer modal
     */
    function closePdfViewer() {
        const modal = document.getElementById('pdfViewerModal');
        const iframe = document.getElementById('pdfViewerIframe');
        
        if (modal) {
            modal.style.display = 'none';
        }
        if (iframe) {
            iframe.src = '';
        }
        
        showLoadingState(false);
        console.log('[StudentPDFViewer] PDF viewer closed');
    }

    /**
     * Show or hide loading state
     * @param {boolean} show - Whether to show the loading indicator
     */
    function showLoadingState(show) {
        let spinner = document.getElementById('pdfLoadingSpinner');
        
        if (show && !spinner) {
            // Create spinner if it doesn't exist
            const modal = document.getElementById('pdfViewerModal');
            if (modal) {
                spinner = document.createElement('div');
                spinner.id = 'pdfLoadingSpinner';
                spinner.className = 'pdf-loading-spinner';
                spinner.innerHTML = '<div class="spinner"></div><p>Loading PDF...</p>';
                modal.appendChild(spinner);
            }
        }
        
        if (spinner) {
            spinner.style.display = show ? 'flex' : 'none';
        }
    }

    /**
     * Create PDF viewer modal container if it doesn't exist
     * Used as fallback for pages without modal structure
     */
    function createModalContainer() {
        const modal = document.createElement('div');
        modal.id = 'pdfViewerModal';
        modal.className = 'pdf-modal';
        modal.style.cssText = `
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.7);
            z-index: 10000;
            align-items: center;
            justify-content: center;
        `;

        const content = document.createElement('div');
        content.className = 'pdf-modal-content';
        content.style.cssText = `
            background: white;
            border-radius: 12px;
            width: 90%;
            max-width: 1000px;
            height: 90vh;
            display: flex;
            flex-direction: column;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        `;

        const header = document.createElement('div');
        header.className = 'pdf-modal-header';
        header.style.cssText = `
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 15px 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-radius: 12px 12px 0 0;
            min-height: 50px;
        `;

        const title = document.createElement('h3');
        title.id = 'pdfFileName';
        title.textContent = 'Document';
        title.style.cssText = 'margin: 0; flex: 1; overflow: hidden; text-overflow: ellipsis;';

        const closeBtn = document.createElement('button');
        closeBtn.textContent = '✕';
        closeBtn.onclick = closePdfViewer;
        closeBtn.style.cssText = `
            background: none;
            border: none;
            color: white;
            font-size: 24px;
            cursor: pointer;
            padding: 0 10px;
        `;

        header.appendChild(title);
        header.appendChild(closeBtn);

        const body = document.createElement('div');
        body.className = 'pdf-modal-body';
        body.style.cssText = `
            flex: 1;
            overflow: hidden;
            display: flex;
            align-items: center;
            justify-content: center;
            background: #f5f5f5;
        `;

        const iframe = document.createElement('iframe');
        iframe.id = 'pdfViewerIframe';
        iframe.style.cssText = `
            width: 100%;
            height: 100%;
            border: none;
            display: none;
        `;

        body.appendChild(iframe);
        content.appendChild(header);
        content.appendChild(body);
        modal.appendChild(content);

        document.body.appendChild(modal);

        // Close on background click
        modal.onclick = (e) => {
            if (e.target === modal) {
                closePdfViewer();
            }
        };

        return modal;
    }

    // Handle Escape key to close viewer
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            const modal = document.getElementById('pdfViewerModal');
            if (modal && modal.style.display === 'flex') {
                closePdfViewer();
            }
        }
    });

    // Public API
    return {
        viewInNewTab,
        viewInline,
        closePdfViewer,
        getViewUrl
    };
})();

// Export for use in HTML
window.StudentPDFViewer = StudentPDFViewer;
