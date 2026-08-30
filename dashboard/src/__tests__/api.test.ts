import { describe, it, expect, vi, beforeEach } from 'vitest';
import api, { authApi, analyticsApi, usersApi } from '../services/api';

describe('Dashboard API Service', () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.clearAllMocks();
  });

  it('authApi.login sends credentials as JSON object', async () => {
    const postSpy = vi.spyOn(api, 'post').mockResolvedValueOnce({ data: { access_token: 'xyz', role: 'admin' } } as any);
    
    await authApi.login('admin@test.com', 'AdminPass123!');

    expect(postSpy).toHaveBeenCalledWith('/api/v1/auth/login', {
      email: 'admin@test.com',
      password: 'AdminPass123!',
    });
  });

  it('analyticsApi methods target expected endpoints', async () => {
    const getSpy = vi.spyOn(api, 'get').mockResolvedValue({ data: {} } as any);

    await analyticsApi.summary();
    expect(getSpy).toHaveBeenCalledWith('/api/v1/analytics/summary');

    await analyticsApi.ambulances();
    expect(getSpy).toHaveBeenCalledWith('/api/v1/analytics/ambulances');

    await analyticsApi.trend();
    expect(getSpy).toHaveBeenCalledWith('/api/v1/analytics/trend');

    await analyticsApi.heatmap();
    expect(getSpy).toHaveBeenCalledWith('/api/v1/analytics/heatmap');
  });

  it('usersApi methods target correct CRUD paths', async () => {
    const getSpy = vi.spyOn(api, 'get').mockResolvedValue({ data: [] } as any);
    const postSpy = vi.spyOn(api, 'post').mockResolvedValue({ data: {} } as any);
    const putSpy = vi.spyOn(api, 'put').mockResolvedValue({ data: {} } as any);
    const delSpy = vi.spyOn(api, 'delete').mockResolvedValue({ data: {} } as any);

    await usersApi.list();
    expect(getSpy).toHaveBeenCalledWith('/api/v1/users/', { params: {} });

    await usersApi.getUsers('pending');
    expect(getSpy).toHaveBeenCalledWith('/api/v1/users/', { params: { approval_status: 'pending' } });

    await usersApi.create({ name: 'Test', email: 'test@example.com', role: 'driver' });
    expect(postSpy).toHaveBeenCalledWith('/api/v1/users/', { name: 'Test', email: 'test@example.com', role: 'driver' });

    await usersApi.update(5, { name: 'New Name' });
    expect(putSpy).toHaveBeenCalledWith('/api/v1/users/5', { name: 'New Name' });

    await usersApi.approveUser(5);
    expect(postSpy).toHaveBeenCalledWith('/api/v1/users/5/approve');

    await usersApi.rejectUser(5);
    expect(postSpy).toHaveBeenCalledWith('/api/v1/users/5/reject');

    await usersApi.delete(5);
    expect(delSpy).toHaveBeenCalledWith('/api/v1/users/5');
  });
});

