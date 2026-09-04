import React, { useState, useEffect } from 'react';
import { Search, PlusCircle, Edit3, Trash2, CheckCircle, ShieldCheck, Wallet, RefreshCw } from 'lucide-react';
import { Badge } from '../components/Badge';
import { Modal } from '../components/Modal';
import { adminApi } from '../services/api';

export const Clients = () => {
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [selectedUser, setSelectedUser] = useState(null);
  const [topUpAmount, setTopUpAmount] = useState('');
  const [message, setMessage] = useState('');

  const fetchUsers = async () => {
    setLoading(true);
    const data = await adminApi.getUsers(search, 'client');
    setUsers(data);
    setLoading(false);
  };

  useEffect(() => {
    fetchUsers();
  }, [search]);

  const handleUpdateUser = async (e) => {
    e.preventDefault();
    if (!selectedUser) return;
    const res = await adminApi.updateUser(selectedUser.id, selectedUser);
    setMessage(res.message);
    setSelectedUser(null);
    fetchUsers();
    setTimeout(() => setMessage(''), 3000);
  };

  const handleTopUp = async () => {
    if (!selectedUser || !topUpAmount) return;
    const res = await adminApi.topUpBalance(selectedUser.id, topUpAmount);
    setMessage(res.message);
    setTopUpAmount('');
    setSelectedUser(null);
    fetchUsers();
    setTimeout(() => setMessage(''), 3000);
  };

  const handleDelete = async (id) => {
    if (window.confirm('Apakah Anda yakin ingin menghapus akun client ini?')) {
      const res = await adminApi.deleteUser(id);
      setMessage(res.message);
      fetchUsers();
      setTimeout(() => setMessage(''), 3000);
    }
  };

  return (
    <div className="space-y-6">
      {/* Alert */}
      {message && (
        <div className="p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-2xl text-sm font-semibold text-emerald-400 animate-in fade-in">
          {message}
        </div>
      )}

      {/* Header & Search */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-extrabold text-white tracking-tight">Manajemen Client / Pengguna</h2>
          <p className="text-sm text-slate-400">Daftar seluruh client terdaftar dalam aplikasi Temenin Ajaa</p>
        </div>

        <div className="flex items-center gap-3">
          <div className="relative">
            <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Cari nama, HP, email..."
              className="pl-10 pr-4 py-2.5 bg-slate-800 border border-slate-700 rounded-xl text-xs text-white placeholder-slate-400 focus:outline-none focus:border-indigo-500"
            />
          </div>
          <button
            onClick={fetchUsers}
            className="p-2.5 bg-slate-800 border border-slate-700 rounded-xl text-slate-300 hover:text-white"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Users Table */}
      <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl overflow-hidden backdrop-blur-md">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-800 text-slate-400 uppercase tracking-wider font-semibold bg-slate-900/50">
                <th className="py-3.5 px-4">Pengguna</th>
                <th className="py-3.5 px-4">Kontak (HP / Email)</th>
                <th className="py-3.5 px-4">Saldo User</th>
                <th className="py-3.5 px-4">Poin</th>
                <th className="py-3.5 px-4">Verifikasi Akun</th>
                <th className="py-3.5 px-4 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 text-slate-300">
              {loading ? (
                <tr>
                  <td colSpan={6} className="py-8 text-center text-slate-500">
                    Memuat daftar client...
                  </td>
                </tr>
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-8 text-center text-slate-500">
                    Tidak ada client ditemukan.
                  </td>
                </tr>
              ) : (
                users.map((user) => (
                  <tr key={user.id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="py-4 px-4">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-full bg-indigo-500/20 text-indigo-400 font-bold flex items-center justify-center border border-indigo-500/30">
                          {user.full_name?.charAt(0) || 'U'}
                        </div>
                        <div>
                          <p className="font-bold text-white text-sm">{user.full_name}</p>
                          <span className="text-[10px] text-slate-500">ID: {user.id}</span>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-4">
                      <p className="font-medium text-slate-200">{user.phone || '-'}</p>
                      <p className="text-[10px] text-slate-400">{user.email || '-'}</p>
                    </td>
                    <td className="py-4 px-4 font-bold text-emerald-400">
                      Rp {parseFloat(user.balance || 0).toLocaleString('id-ID')}
                    </td>
                    <td className="py-4 px-4 font-semibold text-amber-400">
                      {user.points || 0} Pts
                    </td>
                    <td className="py-4 px-4">
                      {user.is_verified ? (
                        <Badge variant="success">Verified</Badge>
                      ) : (
                        <Badge variant="neutral">Unverified</Badge>
                      )}
                    </td>
                    <td className="py-4 px-4 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <button
                          onClick={() => setSelectedUser(user)}
                          className="p-2 text-indigo-400 hover:bg-indigo-500/10 rounded-lg transition-colors border border-indigo-500/20"
                          title="Edit / Top Up"
                        >
                          <Edit3 className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleDelete(user.id)}
                          className="p-2 text-rose-400 hover:bg-rose-500/10 rounded-lg transition-colors border border-rose-500/20"
                          title="Hapus Account"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal Edit & Top-Up Client */}
      <Modal
        isOpen={!!selectedUser}
        onClose={() => setSelectedUser(null)}
        title="Edit Profil & Top Up Saldo Client"
      >
        {selectedUser && (
          <div className="space-y-6 text-xs">
            {/* Quick Top Up Box */}
            <div className="p-4 bg-indigo-950/40 border border-indigo-800/60 rounded-xl space-y-3">
              <div className="flex items-center justify-between">
                <span className="font-bold text-indigo-300 flex items-center gap-1.5">
                  <Wallet className="w-4 h-4" />
                  Top Up Saldo Manual Admin
                </span>
                <span className="font-mono text-emerald-400 font-bold">
                  Saldo Saat Ini: Rp {parseFloat(selectedUser.balance || 0).toLocaleString('id-ID')}
                </span>
              </div>
              <div className="flex gap-2">
                <input
                  type="number"
                  placeholder="Masukkan nominal top up (cth: 100000)"
                  value={topUpAmount}
                  onChange={(e) => setTopUpAmount(e.target.value)}
                  className="flex-1 px-3 py-2 bg-slate-900 border border-slate-700 rounded-lg text-white font-mono text-xs focus:outline-none focus:border-indigo-500"
                />
                <button
                  type="button"
                  onClick={handleTopUp}
                  className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg transition-colors flex items-center gap-1"
                >
                  <PlusCircle className="w-3.5 h-3.5" />
                  <span>Tambah Saldo</span>
                </button>
              </div>
            </div>

            {/* Edit User Form */}
            <form onSubmit={handleUpdateUser} className="space-y-4">
              <div>
                <label className="block text-slate-400 mb-1 font-semibold">Nama Lengkap</label>
                <input
                  type="text"
                  value={selectedUser.full_name || ''}
                  onChange={(e) => setSelectedUser({ ...selectedUser, full_name: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-white font-semibold focus:outline-none focus:border-indigo-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 mb-1 font-semibold">Nomor HP</label>
                  <input
                    type="text"
                    value={selectedUser.phone || ''}
                    onChange={(e) => setSelectedUser({ ...selectedUser, phone: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-white font-mono focus:outline-none focus:border-indigo-500"
                  />
                </div>
                <div>
                  <label className="block text-slate-400 mb-1 font-semibold">Role Akun</label>
                  <select
                    value={selectedUser.role || 'client'}
                    onChange={(e) => setSelectedUser({ ...selectedUser, role: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-white focus:outline-none focus:border-indigo-500"
                  >
                    <option value="client">Client</option>
                    <option value="driver">Driver</option>
                    <option value="admin">Admin</option>
                  </select>
                </div>
              </div>

              <div className="flex items-center gap-3 pt-2">
                <label className="flex items-center gap-2 cursor-pointer text-slate-300 font-semibold">
                  <input
                    type="checkbox"
                    checked={!!selectedUser.is_verified}
                    onChange={(e) => setSelectedUser({ ...selectedUser, is_verified: e.target.checked })}
                    className="w-4 h-4 rounded text-indigo-600 bg-slate-800 border-slate-700"
                  />
                  <span>Status Verifikasi Centang Hijau</span>
                </label>
              </div>

              <div className="pt-4 flex justify-end gap-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setSelectedUser(null)}
                  className="px-4 py-2 bg-slate-800 text-slate-300 rounded-lg font-semibold"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-lg transition-colors"
                >
                  Simpan Perubahan
                </button>
              </div>
            </form>
          </div>
        )}
      </Modal>
    </div>
  );
};
