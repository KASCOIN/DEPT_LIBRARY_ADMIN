/**
 * API Helper Functions with Supabase JWT Authentication
 */
const API = {
    baseURL: window.location.origin,

    /**
     * Get admin JWT token from localStorage
     * Checks for Supabase JWT first (new system), then falls back to old token
     */
    getToken() {
        // New Supabase-based token (priority)
        const jwtToken = localStorage.getItem('admin_jwt');
        if (jwtToken) {
            return jwtToken;
        }
        
        // Legacy token (for backward compatibility)
        return localStorage.getItem('admin_token') || '';
    },

    /**
     * Get default headers with auth token
     * Enforces JWT token in all admin requests
     */
    getHeaders(includeAuth = true) {
        const headers = {};
        if (includeAuth) {
            const token = this.getToken();
            if (token) {
                headers['Authorization'] = `Bearer ${token}`;
            }
        }
        return headers;
    },

    async post(endpoint, data, isFormData = false) {
        const headers = this.getHeaders(true);
        if (!isFormData) {
            headers['Content-Type'] = 'application/json';
        }

        const response = await fetch(`${this.baseURL}${endpoint}`, {
            method: 'POST',
            headers,
            body: isFormData ? data : JSON.stringify(data)
        });

        if (response.status === 401 || response.status === 403) {
            // Unauthorized or Forbidden - clear tokens and redirect
            localStorage.removeItem('admin_jwt');
            localStorage.removeItem('admin_token');
            localStorage.removeItem('admin_email');
            localStorage.removeItem('admin_user_id');
            window.location.href = '/admin-login';
            throw new Error('Session expired or access denied. Please login again.');
        }

        if (!response.ok) {
            console.error(`API Error ${response.status}:`, await response.text());
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        return await response.json();
    },

    async get(endpoint, includeAuth = true) {
        const headers = this.getHeaders(includeAuth);

        const response = await fetch(`${this.baseURL}${endpoint}`, {
            headers
        });

        if (response.status === 401 || response.status === 403) {
            // Unauthorized or Forbidden - clear tokens and redirect
            localStorage.removeItem('admin_jwt');
            localStorage.removeItem('admin_token');
            localStorage.removeItem('admin_email');
            localStorage.removeItem('admin_user_id');
            window.location.href = '/admin-login';
            throw new Error('Session expired or access denied. Please login again.');
        }

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        return await response.json();
    },

    async delete(endpoint, data) {
        const headers = this.getHeaders(true);
        headers['Content-Type'] = 'application/json';

        const response = await fetch(`${this.baseURL}${endpoint}`, {
            method: 'DELETE',
            headers,
            body: JSON.stringify(data)
        });

        if (response.status === 401) {
            // Token expired or invalid
            localStorage.removeItem('admin_token');
            window.location.href = '/login.html';
            throw new Error('Session expired. Please login again.');
        }

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        return await response.json();
    }
};