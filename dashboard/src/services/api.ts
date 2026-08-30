import axios from 'axios';

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'https://sajiloroute-api.onrender.com';

const api = axios.create({
  baseURL: API_BASE,
  headers: { 'Content-Type': 'application/json' },
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    const status = error.response?.status;
    if ((status === 401 || status === 403) && localStorage.getItem('token')) {
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export interface User {
  id: number;
  name: string;
  email: string;
  role: 'admin' | 'driver' | 'officer' | string;
  approval_status?: 'pending' | 'approved' | 'rejected' | string;
  vehicle_number?: string | null;
  assigned_zone?: string | null;
  created_at?: string;
  approved_at?: string | null;
  approved_by?: number | null;
}

export const authApi = {
  login: (email: string, password: string) =>
    api.post('/api/v1/auth/login', { email, password }),
  me: () => api.get('/api/v1/auth/me'),
};

export const analyticsApi = {
  summary: () => api.get('/api/v1/analytics/summary'),
  ambulances: () => api.get('/api/v1/analytics/ambulances'),
  trend: () => api.get('/api/v1/analytics/trend'),
  heatmap: () => api.get('/api/v1/analytics/heatmap'),
};

export const emergencyApi = {
  active: () => api.get('/api/v1/emergencies/active'),
};

export const gpsApi = {
  liveAll: () => api.get('/api/v1/gps/live/all'),
};

export const usersApi = {
  list: (approvalStatus?: string) =>
    api.get<User[]>('/api/v1/users/', { params: approvalStatus ? { approval_status: approvalStatus } : {} }),
  getUsers: (approvalStatus?: string) =>
    api.get<User[]>('/api/v1/users/', { params: approvalStatus ? { approval_status: approvalStatus } : {} }),
  get: (id: number | string) => api.get<User>(`/api/v1/users/${id}`),
  create: (data: any) => api.post<User>('/api/v1/users/', data),
  update: (id: number | string, data: any) => api.put<User>(`/api/v1/users/${id}`, data),
  delete: (id: number | string) => api.delete(`/api/v1/users/${id}`),
  approve: (id: number | string) => api.post<User>(`/api/v1/users/${id}/approve`),
  approveUser: (id: number | string) => api.post<User>(`/api/v1/users/${id}/approve`),
  reject: (id: number | string) => api.post<User>(`/api/v1/users/${id}/reject`),
  rejectUser: (id: number | string) => api.post<User>(`/api/v1/users/${id}/reject`),
};

export const ambulancesApi = {
  list: () => api.get('/api/v1/ambulances/'),
};

export default api;

