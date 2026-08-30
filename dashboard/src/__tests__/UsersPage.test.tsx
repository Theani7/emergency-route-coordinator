import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import UsersPage from '../pages/UsersPage';
import { usersApi } from '../services/api';

describe('UsersPage', () => {
  const mockUsers = [
    {
      id: 1,
      name: 'Admin User',
      email: 'admin@test.com',
      role: 'admin',
      approval_status: 'approved',
    },
    {
      id: 2,
      name: 'Pending Driver',
      email: 'driver@test.com',
      role: 'driver',
      approval_status: 'pending',
      vehicle_number: 'BA-2-CHA-1111',
    },
    {
      id: 3,
      name: 'Rejected Officer',
      email: 'officer@test.com',
      role: 'officer',
      approval_status: 'rejected',
      assigned_zone: 'Zone A',
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders users list with approval status badges and pending badge count', async () => {
    vi.spyOn(usersApi, 'list').mockResolvedValueOnce({ data: mockUsers } as any);

    render(<UsersPage />);

    expect(screen.getByText('Users')).toBeInTheDocument();

    await waitFor(() => {
      expect(screen.getByText('Admin User')).toBeInTheDocument();
      expect(screen.getByText('Pending Driver')).toBeInTheDocument();
      expect(screen.getByText('Rejected Officer')).toBeInTheDocument();
      expect(screen.getByText('Approved')).toBeInTheDocument();
      expect(screen.getByText('Pending')).toBeInTheDocument();
      expect(screen.getByText('Rejected')).toBeInTheDocument();
    });
  });

  it('filters users when clicking Pending Approvals tab', async () => {
    vi.spyOn(usersApi, 'list').mockResolvedValue({ data: mockUsers } as any);

    render(<UsersPage />);

    await waitFor(() => {
      expect(screen.getByText('Pending Driver')).toBeInTheDocument();
    });

    const pendingTab = screen.getByRole('button', { name: /Pending Approvals/i });
    fireEvent.click(pendingTab);

    expect(screen.getByText('Pending Driver')).toBeInTheDocument();
    expect(screen.queryByText('Admin User')).not.toBeInTheDocument();
    expect(screen.queryByText('Rejected Officer')).not.toBeInTheDocument();
  });

  it('approves a pending user when clicking Approve button', async () => {
    vi.spyOn(usersApi, 'list')
      .mockResolvedValueOnce({ data: mockUsers } as any)
      .mockResolvedValueOnce({
        data: [
          mockUsers[0],
          { ...mockUsers[1], approval_status: 'approved' },
          mockUsers[2],
        ],
      } as any);

    const approveSpy = vi.spyOn(usersApi, 'approveUser').mockResolvedValueOnce({ data: {} } as any);

    render(<UsersPage />);

    await waitFor(() => {
      expect(screen.getByText('Pending Driver')).toBeInTheDocument();
    });

    const approveBtn = screen.getByRole('button', { name: /Approve Pending Driver/i });
    fireEvent.click(approveBtn);

    await waitFor(() => {
      expect(approveSpy).toHaveBeenCalledWith(2);
      expect(screen.getByText(/approved successfully/i)).toBeInTheDocument();
    });
  });

  it('rejects a pending user when clicking Reject button', async () => {
    vi.spyOn(window, 'confirm').mockReturnValue(true);
    vi.spyOn(usersApi, 'list')
      .mockResolvedValueOnce({ data: mockUsers } as any)
      .mockResolvedValueOnce({
        data: [
          mockUsers[0],
          { ...mockUsers[1], approval_status: 'rejected' },
          mockUsers[2],
        ],
      } as any);

    const rejectSpy = vi.spyOn(usersApi, 'rejectUser').mockResolvedValueOnce({ data: {} } as any);

    render(<UsersPage />);

    await waitFor(() => {
      expect(screen.getByText('Pending Driver')).toBeInTheDocument();
    });

    const rejectBtn = screen.getByRole('button', { name: /Reject Pending Driver/i });
    fireEvent.click(rejectBtn);

    await waitFor(() => {
      expect(rejectSpy).toHaveBeenCalledWith(2);
      expect(screen.getByText(/registration rejected/i)).toBeInTheDocument();
    });
  });
});
