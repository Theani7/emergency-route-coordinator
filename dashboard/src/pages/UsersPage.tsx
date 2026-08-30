import { useCallback, useEffect, useState } from 'react';
import {
  IconAlertCircle,
  IconCheck,
  IconClock,
  IconEdit,
  IconPlus,
  IconTrash,
  IconUsers,
  IconX,
} from '@tabler/icons-react';
import Card from '../components/Card';
import PageHeader from '../components/PageHeader';
import ErrorBanner from '../components/ErrorBanner';
import { usersApi, User } from '../services/api';

const emptyForm = {
  name: '',
  email: '',
  password: '',
  role: 'driver',
  vehicle_number: '',
  assigned_zone: '',
};

const inputClass =
  'w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm focus:border-emergency focus:outline-none focus:ring-2 focus:ring-emergency/20 dark:border-gray-600 dark:bg-gray-700 dark:focus:border-emergency-light';

const roleMeta: Record<string, { label: string; chip: string; avatar: string }> = {
  admin: {
    label: 'Admin',
    chip: 'bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-300',
    avatar: 'bg-purple-100 text-purple-700 dark:bg-purple-900/40 dark:text-purple-300',
  },
  driver: {
    label: 'Driver',
    chip: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300',
    avatar: 'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300',
  },
  officer: {
    label: 'Officer',
    chip: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300',
    avatar: 'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300',
  },
};

function initials(name?: string) {
  return (name || '?')
    .split(/\s+/)
    .filter(Boolean)
    .map((w) => w[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();
}

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [activeTab, setActiveTab] = useState<'all' | 'pending'>('all');
  const [showModal, setShowModal] = useState(false);
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState('');
  const [loadError, setLoadError] = useState('');
  const [loading, setLoading] = useState(false);
  const [actionLoadingId, setActionLoadingId] = useState<number | null>(null);
  const [notification, setNotification] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  const loadUsers = useCallback(() => {
    setLoadError('');
    usersApi
      .list()
      .then((r) => setUsers(r.data))
      .catch(() => setLoadError('Failed to load users'));
  }, []);

  useEffect(() => {
    loadUsers();
  }, [loadUsers]);

  const pendingCount = users.filter((u) => u.approval_status === 'pending').length;
  const displayedUsers =
    activeTab === 'pending'
      ? users.filter((u) => u.approval_status === 'pending')
      : users;

  const openCreate = () => {
    setEditingUser(null);
    setForm(emptyForm);
    setError('');
    setShowModal(true);
  };

  const openEdit = (u: User) => {
    setEditingUser(u);
    setForm({
      name: u.name,
      email: u.email,
      password: '',
      role: u.role,
      vehicle_number: u.vehicle_number || '',
      assigned_zone: u.assigned_zone || '',
    });
    setError('');
    setShowModal(true);
  };

  const closeModal = () => {
    setShowModal(false);
    setError('');
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      if (editingUser) {
        const payload: any = { name: form.name, email: form.email, role: form.role };
        if (form.password) payload.password = form.password;
        if (form.role === 'driver') payload.vehicle_number = form.vehicle_number;
        if (form.role === 'officer') payload.assigned_zone = form.assigned_zone;
        await usersApi.update(editingUser.id, payload);
      } else {
        if (!form.password) {
          setError('Password is required for new users');
          setLoading(false);
          return;
        }
        const payload: any = {
          name: form.name,
          email: form.email,
          password: form.password,
          role: form.role,
        };
        if (form.role === 'driver') payload.vehicle_number = form.vehicle_number;
        if (form.role === 'officer') payload.assigned_zone = form.assigned_zone;
        await usersApi.create(payload);
      }
      setShowModal(false);
      loadUsers();
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Operation failed');
    }
    setLoading(false);
  };

  const handleDelete = async (u: User) => {
    if (!window.confirm(`Delete user "${u.name}" (${u.email})?`)) return;
    try {
      await usersApi.delete(u.id);
      loadUsers();
    } catch (err: any) {
      alert(err.response?.data?.detail || 'Delete failed');
    }
  };

  const handleApprove = async (u: User) => {
    setActionLoadingId(u.id);
    try {
      await usersApi.approveUser(u.id);
      setNotification({
        type: 'success',
        message: `User "${u.name}" (${u.email}) approved successfully.`,
      });
      loadUsers();
    } catch (err: any) {
      setNotification({
        type: 'error',
        message: err.response?.data?.detail || `Failed to approve user "${u.name}".`,
      });
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleReject = async (u: User) => {
    if (!window.confirm(`Reject registration for "${u.name}" (${u.email})?`)) return;
    setActionLoadingId(u.id);
    try {
      await usersApi.rejectUser(u.id);
      setNotification({
        type: 'success',
        message: `User "${u.name}" (${u.email}) registration rejected.`,
      });
      loadUsers();
    } catch (err: any) {
      setNotification({
        type: 'error',
        message: err.response?.data?.detail || `Failed to reject user "${u.name}".`,
      });
    } finally {
      setActionLoadingId(null);
    }
  };

  const renderRole = (role: string) => {
    const meta = roleMeta[role] || roleMeta.driver;
    return (
      <span className={`inline-flex rounded-full px-3 py-1 text-xs font-medium ${meta.chip}`}>
        {meta.label}
      </span>
    );
  };

  const renderApprovalStatus = (status?: string) => {
    const norm = (status || 'approved').toLowerCase();
    if (norm === 'pending') {
      return (
        <span className="inline-flex items-center gap-1.5 rounded-full bg-amber-50 px-2.5 py-1 text-xs font-medium text-amber-700 dark:bg-amber-900/30 dark:text-amber-300">
          <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-amber-500" />
          Pending
        </span>
      );
    }
    if (norm === 'rejected') {
      return (
        <span className="inline-flex items-center gap-1.5 rounded-full bg-red-50 px-2.5 py-1 text-xs font-medium text-red-700 dark:bg-red-900/30 dark:text-red-300">
          <span className="h-1.5 w-1.5 rounded-full bg-red-500" />
          Rejected
        </span>
      );
    }
    return (
      <span className="inline-flex items-center gap-1.5 rounded-full bg-green-50 px-2.5 py-1 text-xs font-medium text-green-700 dark:bg-green-900/30 dark:text-green-300">
        <span className="h-1.5 w-1.5 rounded-full bg-green-500" />
        Approved
      </span>
    );
  };

  return (
    <div>
      <PageHeader
        title="Users"
        subtitle="Manage admins, drivers and traffic officers"
      >
        <button
          onClick={openCreate}
          className="flex items-center gap-2 rounded-lg bg-emergency px-4 py-2 text-sm font-medium text-white shadow-sm transition-colors hover:bg-emergency-dark"
        >
          <IconPlus className="h-4 w-4" stroke={2} />
          Add User
        </button>
      </PageHeader>

      {loadError && <ErrorBanner message={loadError} onRetry={loadUsers} />}

      {notification && (
        <div
          className={`mb-4 flex items-center justify-between gap-3 rounded-lg border p-4 ${
            notification.type === 'success'
              ? 'border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-800 dark:bg-emerald-900/20 dark:text-emerald-300'
              : 'border-red-200 bg-red-50 text-red-800 dark:border-red-800 dark:bg-red-900/20 dark:text-red-300'
          }`}
        >
          <div className="flex items-center gap-2">
            {notification.type === 'success' ? (
              <IconCheck className="h-5 w-5 shrink-0 text-emerald-600 dark:text-emerald-400" stroke={2} />
            ) : (
              <IconAlertCircle className="h-5 w-5 shrink-0 text-red-600 dark:text-red-400" stroke={2} />
            )}
            <p className="text-sm font-medium">{notification.message}</p>
          </div>
          <button
            onClick={() => setNotification(null)}
            className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
            title="Dismiss"
          >
            <IconX className="h-4 w-4" stroke={2} />
          </button>
        </div>
      )}

      {/* Tabs */}
      <div className="mb-4 flex items-center gap-3 border-b border-gray-200 dark:border-gray-700">
        <button
          type="button"
          onClick={() => setActiveTab('all')}
          className={`inline-flex items-center gap-2 border-b-2 px-4 py-2.5 text-sm font-medium transition-colors ${
            activeTab === 'all'
              ? 'border-emergency text-emergency dark:border-emergency-light dark:text-emergency-light'
              : 'border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200'
          }`}
        >
          <IconUsers className="h-4 w-4" stroke={1.7} />
          <span>All Users</span>
          <span className="rounded-full bg-gray-100 px-2 py-0.5 text-xs text-gray-600 dark:bg-gray-800 dark:text-gray-400">
            {users.length}
          </span>
        </button>
        <button
          type="button"
          onClick={() => setActiveTab('pending')}
          className={`inline-flex items-center gap-2 border-b-2 px-4 py-2.5 text-sm font-medium transition-colors ${
            activeTab === 'pending'
              ? 'border-emergency text-emergency dark:border-emergency-light dark:text-emergency-light'
              : 'border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200'
          }`}
        >
          <IconClock className="h-4 w-4" stroke={1.7} />
          <span>Pending Approvals</span>
          {pendingCount > 0 ? (
            <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-700 dark:bg-amber-900/40 dark:text-amber-300">
              {pendingCount}
            </span>
          ) : (
            <span className="rounded-full bg-gray-100 px-2 py-0.5 text-xs text-gray-500 dark:bg-gray-800 dark:text-gray-400">
              0
            </span>
          )}
        </button>
      </div>

      <Card bodyClassName="p-0">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-gray-50 dark:bg-gray-800/60">
              <tr className="text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400">
                <th className="px-5 py-3.5 font-semibold">ID</th>
                <th className="px-5 py-3.5 font-semibold">User</th>
                <th className="px-5 py-3.5 font-semibold">Email</th>
                <th className="px-5 py-3.5 font-semibold">Role</th>
                <th className="px-5 py-3.5 font-semibold">Status</th>
                <th className="px-5 py-3.5 text-right font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700/60">
              {displayedUsers.map((u) => {
                const meta = roleMeta[u.role] || roleMeta.driver;
                const isPending = u.approval_status === 'pending';
                return (
                  <tr
                    key={u.id}
                    className="transition-colors hover:bg-gray-50/80 dark:hover:bg-gray-800/40"
                  >
                    <td className="px-5 py-4">
                      <span className="font-mono text-xs text-gray-500 dark:text-gray-400">
                        {u.id}
                      </span>
                    </td>
                    <td className="px-5 py-4">
                      <div className="flex items-center gap-3">
                        <span
                          className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-xs font-bold ${meta.avatar}`}
                        >
                          {initials(u.name)}
                        </span>
                        <div>
                          <span className="font-medium">{u.name}</span>
                          {u.vehicle_number && (
                            <span className="block text-xs text-gray-400 dark:text-gray-500">
                              {u.vehicle_number}
                            </span>
                          )}
                          {u.assigned_zone && (
                            <span className="block text-xs text-gray-400 dark:text-gray-500">
                              Zone: {u.assigned_zone}
                            </span>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-4 text-gray-600 dark:text-gray-300">{u.email}</td>
                    <td className="px-5 py-4">{renderRole(u.role)}</td>
                    <td className="px-5 py-4">{renderApprovalStatus(u.approval_status)}</td>
                    <td className="px-5 py-4 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        {isPending && (
                          <>
                            <button
                              type="button"
                              onClick={() => handleApprove(u)}
                              disabled={actionLoadingId === u.id}
                              title="Approve user"
                              aria-label={`Approve ${u.name}`}
                              className="inline-flex items-center gap-1 rounded-lg border border-emerald-300 bg-emerald-50 px-2.5 py-1.5 text-xs font-medium text-emerald-700 transition-colors hover:bg-emerald-100 disabled:opacity-50 dark:border-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-300 dark:hover:bg-emerald-900/50"
                            >
                              <IconCheck className="h-3.5 w-3.5" stroke={2.5} />
                              Approve
                            </button>
                            <button
                              type="button"
                              onClick={() => handleReject(u)}
                              disabled={actionLoadingId === u.id}
                              title="Reject user"
                              aria-label={`Reject ${u.name}`}
                              className="inline-flex items-center gap-1 rounded-lg border border-rose-300 bg-rose-50 px-2.5 py-1.5 text-xs font-medium text-rose-700 transition-colors hover:bg-rose-100 disabled:opacity-50 dark:border-rose-800 dark:bg-rose-900/30 dark:text-rose-300 dark:hover:bg-rose-900/50"
                            >
                              <IconX className="h-3.5 w-3.5" stroke={2.5} />
                              Reject
                            </button>
                          </>
                        )}
                        <button
                          type="button"
                          onClick={() => openEdit(u)}
                          title="Edit user"
                          aria-label={`Edit ${u.name}`}
                          className="inline-flex items-center justify-center rounded-lg border p-1.5 text-gray-500 transition-colors hover:bg-gray-100 hover:text-gray-700 dark:border-gray-600 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200"
                        >
                          <IconEdit className="h-4 w-4" stroke={1.7} />
                        </button>
                        <button
                          type="button"
                          onClick={() => handleDelete(u)}
                          title="Delete user"
                          aria-label={`Delete ${u.name}`}
                          className="inline-flex items-center justify-center rounded-lg border border-red-200 p-1.5 text-red-600 transition-colors hover:bg-red-50 dark:border-red-900/50 dark:text-red-400 dark:hover:bg-red-900/30"
                        >
                          <IconTrash className="h-4 w-4" stroke={1.7} />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        {!loadError && displayedUsers.length === 0 && (
          <div className="p-12 text-center">
            <span className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-gray-50 dark:bg-gray-700/60">
              {activeTab === 'pending' ? (
                <IconClock className="h-7 w-7 text-gray-300 dark:text-gray-600" stroke={1.5} />
              ) : (
                <IconUsers className="h-7 w-7 text-gray-300 dark:text-gray-600" stroke={1.5} />
              )}
            </span>
            <p className="mt-4 text-sm font-medium text-gray-600 dark:text-gray-300">
              {activeTab === 'pending' ? 'No pending approvals' : 'No users found'}
            </p>
            <p className="mt-1 text-sm text-gray-400 dark:text-gray-500">
              {activeTab === 'pending'
                ? 'All account registrations have been processed'
                : 'Create your first user with the Add User button'}
            </p>
          </div>
        )}
      </Card>

      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-2xl border bg-white p-6 shadow-2xl dark:border-gray-700 dark:bg-gray-800">
            <div className="mb-5 flex items-start justify-between gap-3">
              <div className="flex items-center gap-3">
                <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-emergency/10 text-emergency">
                  <IconUsers className="h-5 w-5" stroke={1.7} />
                </span>
                <div>
                  <h2 className="text-lg font-bold tracking-tight">
                    {editingUser ? 'Edit User' : 'Create User'}
                  </h2>
                  <p className="text-xs text-gray-500 dark:text-gray-400">
                    {editingUser ? 'Update account details' : 'Add a new account to the system'}
                  </p>
                </div>
              </div>
              <button
                onClick={closeModal}
                title="Close"
                className="rounded-lg border p-1.5 text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-600 dark:border-gray-600 dark:hover:bg-gray-700"
              >
                <IconX className="h-4 w-4" stroke={1.7} />
              </button>
            </div>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="mb-1 block text-sm font-medium">Name</label>
                <input
                  type="text"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  className={inputClass}
                  required
                  minLength={2}
                />
              </div>
              <div>
                <label className="mb-1 block text-sm font-medium">Email</label>
                <input
                  type="email"
                  value={form.email}
                  onChange={(e) => setForm({ ...form, email: e.target.value })}
                  className={inputClass}
                  required
                />
              </div>
              <div>
                <label className="mb-1 block text-sm font-medium">
                  Password {editingUser && '(leave blank to keep current)'}
                </label>
                <input
                  type="password"
                  value={form.password}
                  onChange={(e) => setForm({ ...form, password: e.target.value })}
                  className={inputClass}
                  {...(!editingUser ? { required: true, minLength: 8 } : { minLength: 8 })}
                />
              </div>
              <div>
                <label className="mb-1 block text-sm font-medium">Role</label>
                <select
                  value={form.role}
                  onChange={(e) => setForm({ ...form, role: e.target.value })}
                  className={inputClass}
                >
                  <option value="driver">Driver</option>
                  <option value="officer">Traffic Officer</option>
                  <option value="admin">Admin</option>
                </select>
              </div>
              {form.role === 'driver' && (
                <div>
                  <label className="mb-1 block text-sm font-medium">Vehicle Number</label>
                  <input
                    type="text"
                    value={form.vehicle_number}
                    onChange={(e) => setForm({ ...form, vehicle_number: e.target.value })}
                    className={inputClass}
                    required={!editingUser}
                  />
                </div>
              )}
              {form.role === 'officer' && (
                <div>
                  <label className="mb-1 block text-sm font-medium">Assigned Zone</label>
                  <input
                    type="text"
                    value={form.assigned_zone}
                    onChange={(e) => setForm({ ...form, assigned_zone: e.target.value })}
                    className={inputClass}
                    placeholder="e.g. Zone A - Thamel"
                  />
                </div>
              )}
              {error && (
                <p className="rounded-lg bg-red-50 p-3 text-sm text-red-600 dark:bg-red-900/30 dark:text-red-300">
                  {error}
                </p>
              )}
              <div className="flex justify-end gap-3 pt-1">
                <button
                  type="button"
                  onClick={closeModal}
                  className="rounded-lg border px-4 py-2 text-sm font-medium transition-colors hover:bg-gray-100 dark:border-gray-600 dark:hover:bg-gray-700"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="rounded-lg bg-emergency px-4 py-2 text-sm font-medium text-white shadow-sm transition-colors hover:bg-emergency-dark disabled:opacity-50"
                >
                  {loading ? 'Saving...' : editingUser ? 'Update' : 'Create'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}