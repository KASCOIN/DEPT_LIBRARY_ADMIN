/**
 * Supabase Admin Authentication Manager
 * Handles secure admin authentication and role-based access control
 */

const AdminAuthManager = {
    /**
     * Initialize Supabase client
     */
    initSupabase() {
        const { createClient } = window.supabase;
        const url = localStorage.getItem('supabase_url') || 'https://yecpwijvbiurqysxazva.supabase.co';
        const key = localStorage.getItem('supabase_key') || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InllY3B3aWp2Yml1cnF5c2F6dmEiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTY5NjI4ODkwMiwiZXhwIjoxNzAxNDcyOTAyfQ.iI82oOvH3x6yOcr6Ry6Z5BqWPe8v3tZrQ4S9KcIzqpc';
        return createClient(url, key);
    },

    /**
     * Check if user is authenticated as admin
     */
    async checkAdminAuth() {
        try {
            const supabase = this.initSupabase();
            
            // Get current session
            const { data: { session } } = await supabase.auth.getSession();
            
            if (!session) {
                // No session, redirect to login
                this.redirectToLogin();
                return false;
            }

            const accessToken = session.access_token;

            // Verify admin role on backend
            const response = await fetch(`${window.location.origin}/api/admin/verify-role`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${accessToken}`
                },
                body: JSON.stringify({ token: accessToken })
            });

            const result = await response.json();

            if (!response.ok || !result.is_admin) {
                // Not an admin, redirect to login
                console.warn('User is not an admin:', result.error || 'Access denied');
                localStorage.removeItem('admin_jwt');
                this.redirectToLogin();
                return false;
            }

            // Admin verified, store credentials
            localStorage.setItem('admin_jwt', accessToken);
            localStorage.setItem('admin_email', session.user.email);
            localStorage.setItem('admin_user_id', session.user.id);
            
            return true;
        } catch (error) {
            console.error('Auth check failed:', error);
            this.redirectToLogin();
            return false;
        }
    },

    /**
     * Redirect to admin login
     */
    redirectToLogin() {
        window.location.href = '/admin-login';
    },

    /**
     * Get current admin token
     */
    getAdminToken() {
        return localStorage.getItem('admin_jwt');
    },

    /**
     * Handle logout
     */
    async logout() {
        try {
            const supabase = this.initSupabase();
            await supabase.auth.signOut();
            localStorage.removeItem('admin_jwt');
            localStorage.removeItem('admin_email');
            localStorage.removeItem('admin_user_id');
            this.redirectToLogin();
        } catch (error) {
            console.error('Logout error:', error);
            this.redirectToLogin();
        }
    },

    /**
     * Display username in header
     */
    displayUsername() {
        const email = localStorage.getItem('admin_email');
        if (email) {
            const usernameDisplay = document.getElementById('username-display');
            if (usernameDisplay) {
                usernameDisplay.textContent = email.split('@')[0];
            }
        }
    }
};

// Check authentication on page load
document.addEventListener('DOMContentLoaded', async () => {
    const isAuthenticated = await AdminAuthManager.checkAdminAuth();
    if (isAuthenticated) {
        AdminAuthManager.displayUsername();
        
        // Set up logout button
        const logoutBtn = document.getElementById('logout-btn');
        if (logoutBtn) {
            logoutBtn.addEventListener('click', () => AdminAuthManager.logout());
        }
    }
});
