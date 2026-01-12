/**
 * Admin Authentication Handler
 * Manages login/logout and session verification
 */

const AdminAuth = {
    /**
     * Check if user is authenticated on page load
     */
    async checkAuth() {
        const token = localStorage.getItem('admin_token');
        
        if (!token) {
            // No token, redirect to login
            this.redirectToLogin();
            return false;
        }
        
        try {
            // Verify token is still valid
            const response = await fetch(`${window.location.origin}/api/admin/auth/verify`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });
            
            if (!response.ok || response.status === 401) {
                // Token invalid or expired
                localStorage.removeItem('admin_token');
                this.redirectToLogin();
                return false;
            }
            
            const data = await response.json();
            
            if (data.authenticated) {
                // Display username
                this.displayUsername(data.username);
                return true;
            } else {
                localStorage.removeItem('admin_token');
                this.redirectToLogin();
                return false;
            }
        } catch (error) {
            console.error('Auth check failed:', error);
            localStorage.removeItem('admin_token');
            this.redirectToLogin();
            return false;
        }
    },

    /**
     * Display username in the header
     */
    displayUsername(username) {
        const usernameDisplay = document.getElementById('username-display');
        if (usernameDisplay) {
            usernameDisplay.textContent = username;
        }
    },

    /**
     * Handle logout
     */
    async logout() {
        const token = localStorage.getItem('admin_token');
        
        try {
            // Call logout endpoint
            const response = await fetch(`${window.location.origin}/api/admin/auth/logout`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });
            
            if (response.ok) {
                console.log('Logout successful');
            }
        } catch (error) {
            console.error('Logout error:', error);
        } finally {
            // Clear token and redirect regardless of response
            localStorage.removeItem('admin_token');
            this.redirectToLogin();
        }
    },

    /**
     * Redirect to login page
     */
    redirectToLogin() {
        window.location.href = '/login.html';
    }
};

/**
 * Initialize authentication on page load
 */
document.addEventListener('DOMContentLoaded', async () => {
    // Check authentication first
    const isAuthenticated = await AdminAuth.checkAuth();
    
    if (!isAuthenticated) {
        return;  // Will be redirected to login
    }
    
    // Set up logout button
    const logoutBtn = document.getElementById('logout-btn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', (e) => {
            e.preventDefault();
            if (confirm('Are you sure you want to logout?')) {
                AdminAuth.logout();
            }
        });
    }
});
