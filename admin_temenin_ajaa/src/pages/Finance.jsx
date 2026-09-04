import React, { useState, useEffect } from 'react';
import { Wallet, PlusCircle, ArrowUpRight, DollarSign, TrendingUp, ShieldCheck, CheckCircle2 } from 'lucide-react';
import { StatCard } from '../components/StatCard';
import { adminApi } from '../services/api';

export const Finance = () => {
  const [users, setUsers] = useState([]);
  const [selectedUserId, setSelectedUserId] = useState('');
  const [topUpAmount, setTopUpAmount] = useState('');
  const [stats, setStats] = useState(null);
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(true);

  const loadData = async () => {
    setLoading(true);
    const [uData, sData] = await Promise.all([
      adminApi.getUsers(),
      adminApi.getStats()
    ]);
    setUsers(uData);
    setStats(sData);
    setLoading(false);
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleTopUp = async (e) => {
    e.preventDefault();
    if (!selectedUserId || !topUpAmount) return;
    const res = await adminApi.topUpBalance(selectedUserId, topUpAmount);
    setMessage(res.message);
    setTopUpAmount('');
    setSelectedUserId('');
    loadData();
    setTimeout(() => setMessage(''), 4000);
  };

  return (
    <div className="space-y-8">
      {/* Alert */}
      {message && (
        <div className="p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-2xl text-sm font-semibold text-emerald-400 flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5" />
          <span>{message}</span>
        </div>
      )}

      {/* Header */}
      <div>
        <h2 className="text-2xl font-extrabold text-white tracking-tight">Keuangan & Pengisian Saldo</h2>
        <p className="text-sm text-slate-400">Ringkasan pendapatan platform, saldo pengguna, dan fitur top up instan admin</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <StatCard
          title="Total Omset Transaksi"
          value={`Rp ${(stats?.totalRevenue || 0).toLocaleString('id-ID')}`}
          icon={Wallet}
          trend="up"
          trendValue="+18%"
          color="emerald"
        />
        <StatCard
          title="Estimasi Bagi Hasil Admin (10%)"
          value={`Rp ${((stats?.totalRevenue || 0) * 0.1).toLocaleString('id-ID')}`}
          icon={TrendingUp}
          trend="up"
          trendValue="+18%"
          color="indigo"
        />
        <StatCard
          title="Total Saldo User Beredar"
          value={`Rp ${users.reduce((acc, u) => acc + (parseFloat(u.balance) || 0), 0).toLocaleString('id-ID')}`}
          icon={DollarSign}
          color="purple"
        />
      </div>

      {/* Top Up Manual Box */}
      <div className="bg-gradient-to-r from-indigo-900/40 via-slate-900 to-slate-900 border border-indigo-500/30 rounded-2xl p-6 shadow-xl backdrop-blur-md">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-xl bg-indigo-500/20 text-indigo-400 flex items-center justify-center border border-indigo-500/30">
            <PlusCircle className="w-6 h-6" />
          </div>
          <div>
            <h3 className="font-extrabold text-white text-base">Top-Up Saldo Pengguna / Driver</h3>
            <p className="text-xs text-slate-400">Tambahkan saldo e-wallet secara manual ke akun mana saja</p>
          </div>
        </div>

        <form onSubmit={handleTopUp} className="grid grid-cols-1 md:grid-cols-3 gap-4 text-xs">
          <div>
            <label className="block text-slate-400 font-semibold mb-1">Pilih Pengguna / Driver</label>
            <select
              value={selectedUserId}
              onChange={(e) => setSelectedUserId(e.target.value)}
              required
              className="w-full px-3.5 py-2.5 bg-slate-800 border border-slate-700 rounded-xl text-white focus:outline-none focus:border-indigo-500"
            >
              <option value="">-- Pilih Akun Penerima --</option>
              {users.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.full_name} ({u.role?.toUpperCase()}) - Saldo: Rp {parseFloat(u.balance || 0).toLocaleString('id-ID')}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-slate-400 font-semibold mb-1">Nominal Top Up (Rp)</label>
            <input
              type="number"
              value={topUpAmount}
              onChange={(e) => setTopUpAmount(e.target.value)}
              placeholder="Contoh: 100000"
              required
              min="1000"
              className="w-full px-3.5 py-2.5 bg-slate-800 border border-slate-700 rounded-xl text-white font-mono focus:outline-none focus:border-indigo-500"
            />
          </div>

          <div className="flex items-end">
            <button
              type="submit"
              className="w-full py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-xl shadow-lg shadow-emerald-600/20 flex items-center justify-center gap-2 transition-all"
            >
              <CheckCircle2 className="w-4 h-4" />
              <span>Proses Top-Up Saldo</span>
            </button>
          </div>
        </form>
      </div>

      {/* Saldo List Table */}
      <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl overflow-hidden backdrop-blur-md">
        <div className="p-4 border-b border-slate-800 flex justify-between items-center">
          <h3 className="font-extrabold text-white text-base">Daftar Saldo Pengguna & Mitra</h3>
          <span className="text-xs text-slate-400">{users.length} Akun Terdaftar</span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-800 text-slate-400 uppercase tracking-wider font-semibold bg-slate-900/50">
                <th className="py-3 px-4">Pengguna</th>
                <th className="py-3 px-4">Role</th>
                <th className="py-3 px-4">Nomor HP</th>
                <th className="py-3 px-4">Saldo E-Wallet</th>
                <th className="py-3 px-4">Poin Loyalitas</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 text-slate-300">
              {users.map((u) => (
                <tr key={u.id} className="hover:bg-slate-800/40 transition-colors">
                  <td className="py-3.5 px-4 font-bold text-white">{u.full_name}</td>
                  <td className="py-3.5 px-4 uppercase font-semibold text-indigo-400">{u.role}</td>
                  <td className="py-3.5 px-4 font-mono text-slate-400">{u.phone || '-'}</td>
                  <td className="py-3.5 px-4 font-mono font-bold text-emerald-400">
                    Rp {parseFloat(u.balance || 0).toLocaleString('id-ID')}
                  </td>
                  <td className="py-3.5 px-4 font-semibold text-amber-400">{u.points || 0} Pts</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
