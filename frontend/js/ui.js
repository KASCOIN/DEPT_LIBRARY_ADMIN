/**
 * UI Helper Functions
 */
const UI = {
    showSection(sectionName) {
        // Hide all sections
        document.querySelectorAll('.admin-section').forEach(section => {
            section.classList.add('hidden');
        });

        // Show selected section
        const targetSection = document.getElementById(`section-${sectionName}`);
        if (targetSection) {
            targetSection.classList.remove('hidden');
        }

        // Update page title
        const title = document.getElementById('page-title');
        title.textContent = sectionName.charAt(0).toUpperCase() + sectionName.slice(1);
    },

    notify(message, success = true) {
        const alertBox = document.getElementById('alert-box');
        alertBox.innerHTML = message;
        alertBox.className = `alert ${success ? 'success' : 'error'}`;
        alertBox.classList.remove('hidden');
        setTimeout(() => {
            alertBox.classList.add('hidden');
        }, 3000);
    },

    showConfirmPopup({ message, confirmText = 'OK', cancelText = 'Cancel', onConfirm }) {
        let modal = document.getElementById('confirm-modal');
        if (!modal) {
            modal = document.createElement('div');
            modal.id = 'confirm-modal';
            modal.innerHTML = `
                <div class="modal-backdrop"></div>
                <div class="modal-content">
                    <div class="modal-message"></div>
                    <div class="modal-actions">
                        <button class="modal-confirm-btn btn-primary"></button>
                        <button class="modal-cancel-btn btn-secondary"></button>
                    </div>
                </div>
            `;
            document.body.appendChild(modal);
        }
        modal.querySelector('.modal-message').innerHTML = message;
        modal.querySelector('.modal-confirm-btn').textContent = confirmText;
        modal.querySelector('.modal-cancel-btn').textContent = cancelText;
        modal.classList.add('show');
        // Remove any previous listeners
        const newConfirmBtn = modal.querySelector('.modal-confirm-btn').cloneNode(true);
        const newCancelBtn = modal.querySelector('.modal-cancel-btn').cloneNode(true);
        modal.querySelector('.modal-confirm-btn').replaceWith(newConfirmBtn);
        modal.querySelector('.modal-cancel-btn').replaceWith(newCancelBtn);
        newConfirmBtn.addEventListener('click', () => {
            modal.classList.remove('show');
            if (onConfirm) onConfirm();
        });
        newCancelBtn.addEventListener('click', () => {
            modal.classList.remove('show');
        });
    }
};