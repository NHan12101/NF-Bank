// API Helper for NF-Bank Frontend

const API_BASE = '/api/v1';

export function getAccessToken() {
  if (typeof window !== 'undefined') {
    return localStorage.getItem('access_token');
  }
  return null;
}

export function setAccessToken(token) {
  if (typeof window !== 'undefined') {
    if (token) {
      localStorage.setItem('access_token', token);
    } else {
      localStorage.removeItem('access_token');
    }
  }
}

export function getUser() {
  if (typeof window !== 'undefined') {
    const userStr = localStorage.getItem('user');
    try {
      return userStr ? JSON.parse(userStr) : null;
    } catch (e) {
      return null;
    }
  }
  return null;
}

export function setUser(user) {
  if (typeof window !== 'undefined') {
    if (user) {
      localStorage.setItem('user', JSON.stringify(user));
    } else {
      localStorage.removeItem('user');
    }
  }
}

export function clearSession() {
  setAccessToken(null);
  setUser(null);
}

// Custom fetch wrapper with auto token refresh
export async function apiFetch(endpoint, options = {}) {
  const url = `${API_BASE}${endpoint}`;
  const token = getAccessToken();

  const headers = {
    'Content-Type': 'application/json',
    ...options.headers,
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const fetchOptions = {
    ...options,
    headers,
  };

  let response = await fetch(url, fetchOptions);

  // If unauthorized, attempt to refresh token
  if (response.status === 401 && endpoint !== '/auth/login' && endpoint !== '/auth/confirm-login' && endpoint !== '/auth/refresh') {
    try {
      const refreshResponse = await fetch(`${API_BASE}/auth/refresh`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (refreshResponse.ok) {
        const refreshData = await refreshResponse.json();
        // The API returns access token in refreshData.data
        const newToken = refreshData.data?.access_token || refreshData.access_token;
        if (newToken) {
          setAccessToken(newToken);
          
          // Retry the original request
          headers['Authorization'] = `Bearer ${newToken}`;
          response = await fetch(url, fetchOptions);
        } else {
          clearSession();
          if (typeof window !== 'undefined') {
            window.location.href = '/login';
          }
        }
      } else {
        clearSession();
        if (typeof window !== 'undefined') {
          window.location.href = '/login';
        }
      }
    } catch (err) {
      clearSession();
      if (typeof window !== 'undefined') {
        window.location.href = '/login';
      }
    }
  }

  return response;
}
