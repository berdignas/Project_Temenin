import React, { useState, useEffect } from 'react';
import { 
  Wallet, PlusCircle, ArrowUpRight, DollarSign, TrendingUp, ShieldCheck, 
  CheckCircle2, AlertTriangle, Clock, Eye, AlertOctagon, XCircle, RefreshCw, 
  ArrowDownRight, Building2, User, FileText, Check, ShieldAlert, Sparkles, Trash2
} from 'lucide-react';
import { StatCard } from '../components/StatCard';
import { Modal } from '../components/Modal';
import { adminApi } from '../services/api';

export const Finance = () => {
  const [activeTab, setActiveTab] = useState('DP'); // 'DP' | 'PELUNASAN' | 'WITHDRAWAL' | 'TOPUP'
  const [transactions, setTransactions] = useState([]);
  const [users, setUsers] = useState([]);
  const [selectedTrx, setSelectedTrx] = useState(null);
  const [selectedUserId, setSelectedUserId] = useState('');
  const [topUpAmount, setTopUpAmount] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [slaFilter, setSlaFilter] = useState('ALL');
  const [searchQuery, setSearchQuery] = useState('');
  const [adminNotes, setAdminNotes] = useState('');
  const [message, setMessage] = useState(null);
  const [loading, setLoading] = useState(true);

  const loadData = async () => {
    setLoading(true);
    try {
      const [uData, tData] = await Promise.all([
        adminApi.getUsers(),
        adminApi.getTransactions()
      ]);
      setUsers(uData);
      setTransactions(tData);
    } catch (err) {
      console.error("Error loading finance data:", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const getSlaInfo = (deadlineStr, createdStr) => {
    // Layanan maksimal 1 x 24 jam kerja dari waktu transaksi
    let deadline = deadlineStr ? new Date(deadlineStr).getTime() : null;
    if (!deadline && createdStr) {
      deadline = new Date(createdStr).getTime() + (24 * 3600 * 1000);
    }
    if (!deadline) {
      deadline = Date.now() + (24 * 3600 * 1000);
    }

    const now = Date.now();
    const diffMs = deadline - now;
    const diffHours = diffMs / (1000 * 3600);

    if (diffMs <= 0) {
      return { 
        label: 'Lewat SLA (24 Jam)', 
        shortLabel: 'LEWAT SLA', 
        status: 'CRITICAL', 
        color: 'rose', 
        hours: 0,
        badgeClass: 'bg-rose-500/20 text-rose-400 border-rose-500/40 animate-pulse'
      };
    } else if (diffHours < 4) {
      return { 
        label: `${Math.floor(diffHours)}j ${Math.floor((diffHours % 1) * 60)}m (KRITIS)`, 
        shortLabel: `${Math.floor(diffHours)}j Kritis`, 
        status: 'CRITICAL', 
        color: 'rose', 
        hours: diffHours,
        badgeClass: 'bg-rose-500/20 text-rose-400 border-rose-500/40 animate-pulse'
      };
    } else if (diffHours < 12) {
      return { 
        label: `${Math.floor(diffHours)}j ${Math.floor((diffHours % 1) * 60)}m (Peringatan)`, 
        shortLabel: `${Math.floor(diffHours)}j Warning`, 
        status: 'WARNING', 
        color: 'amber', 
        hours: diffHours,
        badgeClass: 'bg-amber-500/20 text-amber-400 border-amber-500/30'
      };
    } else {
      return { 
        label: `${Math.floor(diffHours)}j ${Math.floor((diffHours % 1) * 60)}m (Aman)`, 
        shortLabel: `${Math.floor(diffHours)}j Aman`, 
        status: 'NORMAL', 
        color: 'emerald', 
        hours: diffHours,
        badgeClass: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
      };
    }
  };

  const handleApproveEscrow = async (trxId) => {
    const res = await adminApi.approveTransaction(trxId, adminNotes);
    setMessage({ type: 'success', text: res.message });
    setSelectedTrx(null);
    setAdminNotes('');
    loadData();
    setTimeout(() => setMessage(null), 5000);
  };

  const handleExecuteForfeit = async (trxId) => {
    if (!window.confirm("Konfirmasi Eksekusi DP Hangus? Dana 50% akan ditransfer ke Driver sebagai kompensasi dan 50% ke Sistem.")) return;
    const res = await adminApi.executeDpForfeit(trxId, adminNotes);
    setMessage({ type: 'warning', text: res.message });
    setSelectedTrx(null);
    setAdminNotes('');
    loadData();
    setTimeout(() => setMessage(null), 6000);
  };

  const handleSettlePelunasan = async (trxId) => {
    const res = await adminApi.settlePelunasanSplit(trxId, adminNotes);
    setMessage({ type: 'success', text: res.message });
    setSelectedTrx(null);
    setAdminNotes('');
    loadData();
    setTimeout(() => setMessage(null), 5000);
  };

  const handleDisbursePayout = async (trxId) => {
    const res = await adminApi.disbursePayout(trxId, adminNotes);
    setMessage({ type: 'success', text: res.message });
    setSelectedTrx(null);
    setAdminNotes('');
    loadData();
    setTimeout(() => setMessage(null), 5000);
  };

  const handleRejectTransaction = async (trxId) => {
    if (!window.confirm("Apakah Anda yakin ingin menolak transaksi ini? Jika transaksi penarikan saldo, dana akan otomatis dikembalikan ke dompet driver.")) return;
    const res = await adminApi.rejectTransaction(trxId, adminNotes);
    setMessage({ type: 'warning', text: res.message });
    setSelectedTrx(null);
    setAdminNotes('');
    loadData();
    setTimeout(() => setMessage(null), 5000);
  };

  const handleDeleteTransaction = async (trxId) => {
    const confirmPrompt = window.prompt(
      `PERINGATAN KRITIS: Anda akan menghapus permanen riwayat transaksi ini (ID: ${trxId}).\n\nKetik kata "HAPUS" untuk mengonfirmasi penghapusan:`
    );
    if (!confirmPrompt || confirmPrompt.trim().toUpperCase() !== 'HAPUS') {
      if (confirmPrompt !== null) {
        alert('Penghapusan dibatalkan: Kata kunci konfirmasi tidak cocok.');
      }
      return;
    }

    try {
      const res = await adminApi.deleteTransaction(trxId);
      setMessage({ type: 'warning', text: res.message });
      setSelectedTrx(null);
      setAdminNotes('');
      loadData();
      setTimeout(() => setMessage(null), 5000);
    } catch (err) {
      alert('Gagal menghapus transaksi: ' + (err.response?.data?.message || err.message));
    }
  };

  const handleTopUpSubmit = async (e) => {
    e.preventDefault();
    if (!selectedUserId || !topUpAmount) return;
    const res = await adminApi.topUpBalance(selectedUserId, topUpAmount);
    setMessage({ type: 'success', text: res.message });
    setTopUpAmount('');
    setSelectedUserId('');
    loadData();
    setTimeout(() => setMessage(null), 5000);
  };

  // Filtered List
  const filteredTransactions = transactions.filter(trx => {
    if (activeTab === 'DP' && trx.type !== 'DP') return false;
    if (activeTab === 'PELUNASAN' && trx.type !== 'PELUNASAN') return false;
    if (activeTab === 'WITHDRAWAL' && trx.type !== 'WITHDRAWAL') return false;
    if (activeTab === 'TOPUP' && trx.type !== 'TOPUP') return false;
    
    if (statusFilter !== 'ALL') {
      if (statusFilter === 'APPROVED_ESCROW') {
        if (trx.status !== 'HELD_IN_ESCROW' && trx.status !== 'APPROVED' && trx.status !== 'PAID') return false;
      } else if (trx.status !== statusFilter) {
        return false;
      }
    }

    const sla = getSlaInfo(trx.sla_deadline, trx.created_at);
    if (slaFilter === 'CRITICAL' && sla.status !== 'CRITICAL') return false;
    if (slaFilter === 'WARNING' && sla.status !== 'WARNING') return false;
    if (slaFilter === 'NORMAL' && sla.status !== 'NORMAL') return false;

    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      const matchName = trx.user_name?.toLowerCase().includes(q) || trx.driver_name?.toLowerCase().includes(q);
      const matchId = trx.id?.toLowerCase().includes(q) || trx.booking_id?.toLowerCase().includes(q);
      return matchName || matchId;
    }
    return true;
  });

  // Calculate Metrics
  const escrowTotal = transactions
    .filter(t => t.status === 'HELD_IN_ESCROW')
    .reduce((acc, t) => acc + (t.amount || 0), 0);

  const pendingCount = transactions.filter(t => t.status === 'PENDING').length;
  
  const criticalSlaCount = transactions.filter(t => {
    const sla = getSlaInfo(t.sla_deadline, t.created_at);
    return t.status === 'PENDING' && sla.status === 'CRITICAL';
  }).length;

  const totalPayouts = transactions
    .filter(t => t.type === 'WITHDRAWAL' && t.status === 'DISBURSED')
    .reduce((acc, t) => acc + (t.amount || 0), 0);

  return (
    <div className="space-y-8">
      {/* Alert Notification */}
      {message && (
        <div className={`p-4 border rounded-2xl text-sm font-bold flex items-center gap-3 animate-in fade-in ${
          message.type === 'warning' 
            ? 'bg-amber-500/10 border-amber-500/30 text-amber-400' 
            : 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400'
        }`}>
          {message.type === 'warning' ? <AlertTriangle className="w-5 h-5 flex-shrink-0" /> : <CheckCircle2 className="w-5 h-5 flex-shrink-0" />}
          <span>{message.text}</span>
        </div>
      )}

      {/* Header Title & Subtitle */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-2xl font-extrabold text-white tracking-tight">Manajemen Pembayaran & Finance CMS</h2>
            <span className="px-2.5 py-0.5 bg-indigo-500/20 text-indigo-400 text-xs font-bold rounded-full border border-indigo-500/30">
              SLA 24h Active
            </span>
          </div>
          <p className="text-sm text-slate-400 mt-1">
            Pengelolaan Escrow Vault, Konfirmasi DP, Pelunasan, Eksekusi DP Hangus (50-50 Split), dan Penarikan Driver.
          </p>
        </div>
        <button 
          onClick={loadData}
          className="px-3.5 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-xl text-xs font-bold border border-slate-700 flex items-center gap-2 transition-all w-fit"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          <span>Refresh Data</span>
        </button>
      </div>

      {/* Financial Metrics Summary Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Dana di Escrow Vault"
          value={`Rp ${escrowTotal.toLocaleString('id-ID')}`}
          icon={ShieldCheck}
          trend="up"
          trendValue="Locked"
          color="indigo"
        />
        <StatCard
          title="Menunggu Konfirmasi"
          value={`${pendingCount} Transaksi`}
          icon={Clock}
          trend={pendingCount > 0 ? "warning" : "up"}
          trendValue="SLA < 24h"
          color="amber"
        />
        <StatCard
          title="SLA Kritis (< 4 Jam)"
          value={`${criticalSlaCount} Perlu Tindakan`}
          icon={AlertOctagon}
          trend={criticalSlaCount > 0 ? "down" : "up"}
          trendValue={criticalSlaCount > 0 ? "URGENT" : "Safe"}
          color="rose"
        />
        <StatCard
          title="Total Penarikan Driver"
          value={`Rp ${totalPayouts.toLocaleString('id-ID')}`}
          icon={Wallet}
          trend="up"
          trendValue="Disbursed"
          color="emerald"
        />
      </div>

      {/* Main Operating Navigation Tabs */}
      <div className="bg-slate-900/60 p-1.5 rounded-2xl border border-slate-800 flex flex-wrap gap-1">
        <button
          onClick={() => setActiveTab('DP')}
          className={`flex-1 min-w-[140px] py-2.5 px-4 rounded-xl text-xs font-extrabold flex items-center justify-center gap-2 transition-all ${
            activeTab === 'DP' 
              ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-600/20' 
              : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
          }`}
        >
          <ShieldCheck className="w-4 h-4" />
          <span>1. DP & Escrow</span>
          <span className="ml-1 px-1.5 py-0.5 bg-white/20 text-white rounded-full text-[10px]">
            {transactions.filter(t => t.type === 'DP' && t.status === 'PENDING').length}
          </span>
        </button>

        <button
          onClick={() => setActiveTab('PELUNASAN')}
          className={`flex-1 min-w-[140px] py-2.5 px-4 rounded-xl text-xs font-extrabold flex items-center justify-center gap-2 transition-all ${
            activeTab === 'PELUNASAN' 
              ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-600/20' 
              : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
          }`}
        >
          <TrendingUp className="w-4 h-4" />
          <span>2. Pelunasan & Split</span>
          <span className="ml-1 px-1.5 py-0.5 bg-white/20 text-white rounded-full text-[10px]">
            {transactions.filter(t => t.type === 'PELUNASAN' && t.status === 'PENDING').length}
          </span>
        </button>

        <button
          onClick={() => setActiveTab('WITHDRAWAL')}
          className={`flex-1 min-w-[140px] py-2.5 px-4 rounded-xl text-xs font-extrabold flex items-center justify-center gap-2 transition-all ${
            activeTab === 'WITHDRAWAL' 
              ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-600/20' 
              : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
          }`}
        >
          <Wallet className="w-4 h-4" />
          <span>3. Penarikan Driver</span>
          <span className="ml-1 px-1.5 py-0.5 bg-white/20 text-white rounded-full text-[10px]">
            {transactions.filter(t => t.type === 'WITHDRAWAL' && t.status === 'PENDING').length}
          </span>
        </button>

        <button
          onClick={() => setActiveTab('TOPUP')}
          className={`flex-1 min-w-[140px] py-2.5 px-4 rounded-xl text-xs font-extrabold flex items-center justify-center gap-2 transition-all ${
            activeTab === 'TOPUP' 
              ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-600/20' 
              : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
          }`}
        >
          <PlusCircle className="w-4 h-4" />
          <span>4. Top-Up Saldo</span>
          <span className="ml-1 px-1.5 py-0.5 bg-white/20 text-white rounded-full text-[10px]">
            {transactions.filter(t => t.type === 'TOPUP' && t.status === 'PENDING').length}
          </span>
        </button>
      </div>

      {/* FORM TOP-UP MANUAL E-WALLET (HANYA DITAMPILKAN PADA TAB TOPUP) */}
      {activeTab === 'TOPUP' && (
        <div className="bg-gradient-to-r from-indigo-950/60 via-slate-900 to-slate-900 border border-indigo-500/30 rounded-2xl p-6 shadow-xl backdrop-blur-md">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-indigo-500/20 text-indigo-400 flex items-center justify-center border border-indigo-500/30">
              <PlusCircle className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-extrabold text-white text-base">Form Top-Up Manual E-Wallet</h3>
              <p className="text-xs text-slate-400">Pilih akun tujuan untuk menambah saldo secara instan</p>
            </div>
          </div>

          <form onSubmit={handleTopUpSubmit} className="grid grid-cols-1 md:grid-cols-3 gap-4 text-xs">
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
                <span>Proses Top-Up Instan</span>
              </button>
            </div>
          </form>
        </div>
      )}

      {/* TRANSACTIONS QUEUE DATA TABLE (UNTUK SEMUA TAB: DP, PELUNASAN, WITHDRAWAL, TOPUP) */}
      <div className="space-y-4">
        {/* Controls & Search Filter Bar */}
        <div className="flex flex-col md:flex-row gap-3 items-stretch md:items-center justify-between">
          <div className="flex flex-wrap items-center gap-2">
            <input
              type="text"
              value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Cari Nama Client, Driver, TRX ID..."
                className="px-3.5 py-2 bg-slate-800 border border-slate-700 rounded-xl text-xs text-white focus:outline-none focus:border-indigo-500 w-full sm:w-64"
              />

              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-xs text-slate-300 focus:outline-none focus:border-indigo-500"
              >
                <option value="ALL">Semua Status</option>
                <option value="PENDING">🟡 PENDING (Menunggu Persetujuan)</option>
                <option value="APPROVED_ESCROW">🟢 DISETUJUI / ESCROW AKTIF</option>
                <option value="HELD_IN_ESCROW">🔒 HELD IN ESCROW (Terkunci)</option>
                <option value="APPROVED">✅ APPROVED (Selesai)</option>
                <option value="FORFEITED">🔴 FORFEITED (DP Hangus)</option>
                <option value="DISBURSED">💸 DISBURSED (Pencairan Selesai)</option>
              </select>

              <select
                value={slaFilter}
                onChange={(e) => setSlaFilter(e.target.value)}
                className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-xs text-slate-300 focus:outline-none focus:border-indigo-500"
              >
                <option value="ALL">Semua Urgensi Waktu (1x24 Jam Kerja)</option>
                <option value="CRITICAL">🔴 Kritis (&lt; 4 Jam / Lewat SLA)</option>
                <option value="WARNING">🟡 Peringatan (4 - 12 Jam)</option>
                <option value="NORMAL">🟢 Aman (&gt; 12 Jam)</option>
              </select>
            </div>

            <span className="text-xs text-slate-400 self-center">
              Menampilkan <b className="text-white">{filteredTransactions.length}</b> transaksi
            </span>
          </div>

          {/* Transactions Queue Data Table */}
          <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl overflow-hidden backdrop-blur-md">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="border-b border-slate-800 text-slate-400 uppercase tracking-wider font-semibold bg-slate-900/60">
                    <th className="py-3.5 px-4">Trx ID & Waktu</th>
                    <th className="py-3.5 px-4">Tipe & Status Booking</th>
                    <th className="py-3.5 px-4">Pengguna / Driver</th>
                    <th className="py-3.5 px-4">Nominal & Gateway</th>
                    <th className="py-3.5 px-4">OCR Matcher</th>
                    <th className="py-3.5 px-4">Urgensi Waktu (1x24h SLA)</th>
                    <th className="py-3.5 px-4 text-right">Aksi Admin</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60 text-slate-300">
                  {filteredTransactions.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="py-12 text-center text-slate-500">
                        Tidak ada transaksi ditemukan di kategori ini.
                      </td>
                    </tr>
                  ) : (
                    filteredTransactions.map((trx) => {
                      const isCancelled = trx.booking_status === 'CANCELLED_BY_CLIENT';
                      const sla = getSlaInfo(trx.sla_deadline, trx.created_at);

                      return (
                        <tr key={trx.id} className="hover:bg-slate-800/40 transition-colors">
                          {/* TRX ID */}
                          <td className="py-3.5 px-4">
                            <div className="font-mono font-bold text-white">{trx.id}</div>
                            <div className="text-[10px] text-slate-500 font-mono">
                              {new Date(trx.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })} WIB • {new Date(trx.created_at).toLocaleDateString('id-ID')}
                            </div>
                          </td>

                          {/* Tipe & Status */}
                          <td className="py-3.5 px-4">
                            <div className="flex items-center gap-1.5">
                              <span className={`px-2 py-0.5 rounded font-extrabold text-[10px] ${
                                trx.type === 'DP' ? 'bg-indigo-500/20 text-indigo-400 border border-indigo-500/30' :
                                trx.type === 'PELUNASAN' ? 'bg-purple-500/20 text-purple-400 border border-purple-500/30' :
                                'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                              }`}>
                                {trx.type}
                              </span>

                              {/* Booking Cancelled Badge */}
                              {isCancelled && (
                                <span className="px-1.5 py-0.5 bg-rose-500/20 text-rose-400 text-[10px] font-bold rounded border border-rose-500/30">
                                  Batal Tiba-Tiba
                                </span>
                              )}
                            </div>

                            <div className="mt-1.5">
                              {trx.status === 'HELD_IN_ESCROW' ? (
                                <span className="inline-flex items-center gap-1 text-[10px] font-extrabold px-2 py-0.5 rounded-full bg-emerald-500/15 text-emerald-400 border border-emerald-500/30">
                                  <ShieldCheck className="w-3 h-3 text-emerald-400" />
                                  <span>Disetujui (Escrow Aktif)</span>
                                </span>
                              ) : trx.status === 'APPROVED' || trx.status === 'PAID' ? (
                                <span className="inline-flex items-center gap-1 text-[10px] font-extrabold px-2 py-0.5 rounded-full bg-emerald-500/15 text-emerald-400 border border-emerald-500/30">
                                  <CheckCircle2 className="w-3 h-3 text-emerald-400" />
                                  <span>Disetujui / Lunas</span>
                                </span>
                              ) : trx.status === 'PENDING' ? (
                                <span className="inline-flex items-center gap-1 text-[10px] font-extrabold px-2 py-0.5 rounded-full bg-amber-500/15 text-amber-400 border border-amber-500/30">
                                  <span className="w-1.5 h-1.5 rounded-full bg-amber-400 animate-ping"></span>
                                  <span>Menunggu Persetujuan</span>
                                </span>
                              ) : trx.status === 'FORFEITED' ? (
                                <span className="inline-flex items-center gap-1 text-[10px] font-extrabold px-2 py-0.5 rounded-full bg-rose-500/15 text-rose-400 border border-rose-500/30">
                                  <AlertOctagon className="w-3 h-3 text-rose-400" />
                                  <span>DP Hangus</span>
                                </span>
                              ) : (
                                <span className="inline-block text-[10px] font-bold text-slate-400">
                                  ● {trx.status}
                                </span>
                              )}
                            </div>
                          </td>

                          {/* Users */}
                          <td className="py-3.5 px-4">
                            <div className="font-bold text-white">{trx.user_name}</div>
                            {trx.driver_name && (
                              <div className="text-[10px] text-slate-400 flex items-center gap-1 mt-0.5">
                                <span>Driver:</span>
                                <span className="text-indigo-400 font-semibold">{trx.driver_name}</span>
                              </div>
                            )}
                          </td>

                          {/* Nominal */}
                          <td className="py-3.5 px-4 font-mono">
                            <div className="font-extrabold text-white text-sm">
                              Rp {trx.amount?.toLocaleString('id-ID')}
                            </div>
                            <div className="text-[10px] text-slate-400">
                              {trx.bank_name || 'Bank BCA'}
                            </div>
                            {trx.unique_code > 0 && (
                              <div className="text-[10px] text-amber-400">
                                +Kode Unik: {trx.unique_code}
                              </div>
                            )}
                          </td>

                          {/* OCR Match */}
                          <td className="py-3.5 px-4">
                            {trx.bank_name?.includes('QRIS') ? (
                              <span className="px-2 py-0.5 bg-indigo-500/20 text-indigo-300 font-mono font-bold text-[10px] rounded border border-indigo-500/30">
                                ⚡ QRIS Xendit
                              </span>
                            ) : trx.ocr_match_score ? (
                              <div className="flex items-center gap-1">
                                <Sparkles className={`w-3.5 h-3.5 ${trx.ocr_match_score >= 95 ? 'text-emerald-400' : 'text-amber-400'}`} />
                                <span className={`font-mono font-bold text-xs ${trx.ocr_match_score >= 95 ? 'text-emerald-400' : 'text-amber-400'}`}>
                                  {trx.ocr_match_score}% Match
                                </span>
                              </div>
                            ) : (
                              <span className="text-slate-500 text-[10px]">Manual Transfer</span>
                            )}
                          </td>

                          {/* SLA Deadline (1 x 24 Jam Kerja) */}
                          <td className="py-3.5 px-4">
                            {trx.status === 'PENDING' ? (
                              <div className="space-y-1">
                                <span className={`px-2.5 py-1 rounded-lg text-[10px] font-bold flex items-center gap-1.5 w-fit border ${sla.badgeClass}`}>
                                  <span className={`w-2 h-2 rounded-full ${
                                    sla.color === 'emerald' ? 'bg-emerald-400' :
                                    sla.color === 'amber' ? 'bg-amber-400' : 'bg-rose-400 animate-ping'
                                  }`} />
                                  <Clock className="w-3 h-3" />
                                  <span>{sla.label}</span>
                                </span>
                                <span className="text-[9px] text-slate-400 block font-medium">Maks. 1x24 jam kerja</span>
                              </div>
                            ) : (
                              <div className="space-y-0.5">
                                <span className="px-2 py-0.5 rounded-md text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 flex items-center gap-1 w-fit">
                                  <Check className="w-3 h-3" />
                                  Selesai Terverifikasi
                                </span>
                                <span className="text-slate-500 text-[9px] block font-mono">
                                  {trx.processed_at ? new Date(trx.processed_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }) + ' WIB' : 'Tepat Waktu'}
                                </span>
                              </div>
                            )}
                          </td>

                          {/* Actions */}
                          <td className="py-3.5 px-4 text-right">
                            <div className="flex items-center justify-end gap-1.5">
                              {/* Quick Approve Button for PENDING transactions */}
                              {trx.status === 'PENDING' && !isCancelled && (
                                <button
                                  onClick={() => handleApproveEscrow(trx.id)}
                                  className="px-2.5 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg text-[11px] shadow-sm shadow-emerald-600/20 flex items-center gap-1 transition-all"
                                  title={trx.type === 'TOPUP' ? 'Setujui Top-Up dan kreditkan saldo ke pengguna' : trx.type === 'WITHDRAWAL' ? 'Konfirmasi pencairan saldo driver' : 'Setujui dan masukkan ke Escrow Vault'}
                                >
                                  <Check className="w-3.5 h-3.5" />
                                  <span>{trx.type === 'TOPUP' ? 'Setujui Top-Up' : trx.type === 'WITHDRAWAL' ? 'Cairkan' : 'Setujui'}</span>
                                </button>
                              )}

                              {/* If DP and cancelled abruptly */}
                              {trx.type === 'DP' && isCancelled && trx.status === 'PENDING' && (
                                <button
                                  onClick={() => handleExecuteForfeit(trx.id)}
                                  className="px-2.5 py-1.5 bg-rose-600 hover:bg-rose-500 text-white font-extrabold rounded-lg text-[11px] shadow-sm shadow-rose-600/20 flex items-center gap-1 transition-all"
                                >
                                  <AlertOctagon className="w-3.5 h-3.5" />
                                  <span>Eksekusi Hangus</span>
                                </button>
                              )}

                              {/* Inspect & Verify Modal Trigger */}
                              <button
                                onClick={() => setSelectedTrx(trx)}
                                className={`px-2.5 py-1.5 text-white font-bold rounded-lg text-[11px] shadow-sm flex items-center gap-1 transition-all ${
                                  trx.status === 'PENDING' 
                                    ? 'bg-indigo-600 hover:bg-indigo-500 shadow-indigo-600/20' 
                                    : 'bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700'
                                }`}
                              >
                                <Eye className="w-3.5 h-3.5 text-indigo-400" />
                                <span>{trx.status === 'PENDING' ? 'Periksa' : 'Detail'}</span>
                              </button>
                            </div>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>

      {/* USER WALLETS DIRECTORY (HANYA DITAMPILKAN PADA TAB TOPUP) */}
      {activeTab === 'TOPUP' && (
        <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl overflow-hidden backdrop-blur-md">
          <div className="p-4 border-b border-slate-800 flex justify-between items-center">
            <div>
              <h3 className="font-extrabold text-white text-base">Direktori Saldo E-Wallet Pengguna</h3>
              <p className="text-xs text-slate-400">Daftar saldo aktif seluruh akun klien dan mitra pengemudi</p>
            </div>
            <span className="text-xs text-slate-400 font-semibold">{users.length} Akun Aktif</span>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-slate-800 text-slate-400 uppercase tracking-wider font-semibold bg-slate-900/50">
                  <th className="py-3 px-4">Nama Pengguna</th>
                  <th className="py-3 px-4">Role</th>
                  <th className="py-3 px-4">Kontak</th>
                  <th className="py-3 px-4">Saldo Active</th>
                  <th className="py-3 px-4">Loyalty Points</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 text-slate-300">
                {users.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="py-8 text-center text-slate-500">Belum ada akun pengguna.</td>
                  </tr>
                ) : (
                  users.map((u) => (
                    <tr key={u.id} className="hover:bg-slate-800/40 transition-colors">
                      <td className="py-3.5 px-4 font-bold text-white">{u.full_name}</td>
                      <td className="py-3.5 px-4 uppercase font-semibold text-indigo-400">{u.role}</td>
                      <td className="py-3.5 px-4 font-mono text-slate-400">{u.phone || u.email || '-'}</td>
                      <td className="py-3.5 px-4 font-mono font-bold text-emerald-400">
                        Rp {parseFloat(u.balance || 0).toLocaleString('id-ID')}
                      </td>
                      <td className="py-3.5 px-4 font-semibold text-amber-400">{u.points || 0} Pts</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* DUAL-VIEW VERIFICATION MODAL (OCR SMART MATCHER SIMULATOR) */}
      {selectedTrx && (
        <Modal 
          isOpen={!!selectedTrx} 
          onClose={() => setSelectedTrx(null)}
          title={`Verifikasi Transaksi ${selectedTrx.type} (${selectedTrx.id})`}
        >
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 text-xs text-slate-300">
            {/* LEFT SIDE: Proof Receipt Viewer */}
            <div className="space-y-3 bg-slate-900/80 p-4 rounded-xl border border-slate-800">
              <div className="flex items-center justify-between">
                <span className="font-extrabold text-white text-xs flex items-center gap-1.5">
                  <FileText className="w-4 h-4 text-indigo-400" />
                  Bukti Resi Transfer Customer
                </span>
                {selectedTrx.ocr_match_score && (
                  <span className="px-2 py-0.5 bg-emerald-500/20 text-emerald-400 font-mono font-bold text-[10px] rounded border border-emerald-500/30">
                    ✨ OCR Match: {selectedTrx.ocr_match_score}%
                  </span>
                )}
              </div>

              {selectedTrx.proof_url ? (
                <div className="relative rounded-xl overflow-hidden border border-slate-700 bg-black aspect-video flex items-center justify-center">
                  <img 
                    src={selectedTrx.proof_url} 
                    alt="Proof of Payment" 
                    className="w-full h-full object-cover"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent p-3 flex flex-col justify-end">
                    <span className="text-[10px] font-mono text-emerald-400 font-bold">
                      OCR Detected: Rp {selectedTrx.total_payable?.toLocaleString('id-ID')} ({selectedTrx.bank_name})
                    </span>
                  </div>
                </div>
              ) : (
                <div className="p-8 border border-dashed border-slate-700 rounded-xl text-center text-slate-500">
                  Tidak ada bukti transfer di-upload (Penarikan Dana / Auto Midtrans Gateway)
                </div>
              )}

              <div className="bg-slate-800/80 p-3 rounded-lg space-y-1.5 font-mono text-[11px]">
                <div className="flex justify-between">
                  <span className="text-slate-400">Pengirim (Rekening):</span>
                  <span className="text-white font-bold">{selectedTrx.account_name || selectedTrx.user_name}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-400">Bank & No Rekening:</span>
                  <span className="text-indigo-400 font-bold">{selectedTrx.bank_name} - {selectedTrx.account_number}</span>
                </div>
              </div>
            </div>

            {/* RIGHT SIDE: Target System Data & Admin Actions */}
            <div className="space-y-4 flex flex-col justify-between">
              <div className="space-y-3">
                <h4 className="font-extrabold text-white text-xs border-b border-slate-800 pb-2">
                  Target Data Sistem & Rule Split
                </h4>

                <div className="grid grid-cols-2 gap-2 text-[11px]">
                  <div className="bg-slate-800/50 p-2.5 rounded-lg border border-slate-700/50">
                    <span className="text-slate-400 block text-[10px]">Tipe Transaksi</span>
                    <span className="font-bold text-white">{selectedTrx.type}</span>
                  </div>

                  <div className="bg-slate-800/50 p-2.5 rounded-lg border border-slate-700/50">
                    <span className="text-slate-400 block text-[10px]">Total Wajib Bayar</span>
                    <span className="font-extrabold text-emerald-400 font-mono">
                      Rp {selectedTrx.total_payable?.toLocaleString('id-ID')}
                    </span>
                  </div>
                </div>

                {/* SPECIAL WARNING FOR CANCELLED DP */}
                {selectedTrx.booking_status === 'CANCELLED_BY_CLIENT' && (
                  <div className="p-3 bg-rose-500/10 border border-rose-500/30 rounded-xl space-y-1 text-rose-300">
                    <div className="flex items-center gap-1.5 font-bold text-xs text-rose-400">
                      <AlertOctagon className="w-4 h-4" />
                      <span>Aturan Pembatalan Se-pihak (DP Hangus)</span>
                    </div>
                    <p className="text-[11px] leading-relaxed">
                      Pesanan ini dibatalkan sepihak oleh Customer. Uang DP <b>hangus</b> dan tidak di-refund. 
                      Eksekusi tombol di bawah untuk mendistribusikan <b>50% Kompensasi Driver (Rp {(selectedTrx.amount * 0.5).toLocaleString('id-ID')})</b> dan <b>50% Kas Sistem (Rp {(selectedTrx.amount * 0.5).toLocaleString('id-ID')})</b>.
                    </p>
                  </div>
                )}

                {/* Admin Notes Field */}
                <div>
                  <label className="block text-slate-400 font-semibold mb-1 text-[11px]">Catatan Admin / Audit Trail</label>
                  <textarea
                    rows={2}
                    value={adminNotes}
                    onChange={(e) => setAdminNotes(e.target.value)}
                    placeholder="Masukkan catatan verifikasi atau alasan penolakan..."
                    className="w-full p-2.5 bg-slate-900 border border-slate-700 rounded-xl text-white text-xs focus:outline-none focus:border-indigo-500"
                  />
                </div>
              </div>

              {/* ACTION BUTTONS ACCORDING TO TRANSACTION TYPE & STATUS */}
              <div className="pt-4 border-t border-slate-800 flex flex-col gap-2">
                {selectedTrx.status === 'HELD_IN_ESCROW' ? (
                  <div className="p-3.5 bg-emerald-500/10 border border-emerald-500/30 rounded-xl space-y-2 text-emerald-300">
                    <div className="flex items-center gap-2 font-bold text-xs text-emerald-400">
                      <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
                      <span>TRANSAKSI TELAH DISETUJUI (DANA TERKUNCI DI ESCROW)</span>
                    </div>
                    <p className="text-[11px] leading-relaxed text-slate-300">
                      Pembayaran DP sebesar <b>Rp {selectedTrx.amount?.toLocaleString('id-ID')}</b> telah berstatus sah dan terkunci aman di Escrow Vault. Status pesanan telah aktif dan pengemudi dapat menjalankan order.
                    </p>
                    <div className="text-[10px] text-emerald-400 font-mono flex items-center gap-1.5 pt-1 border-t border-emerald-500/20">
                      <ShieldCheck className="w-3.5 h-3.5" />
                      <span>Metode: {selectedTrx.bank_name || 'Transfer'} • Terverifikasi Otomatis/Admin</span>
                    </div>
                  </div>
                ) : selectedTrx.type === 'TOPUP' && (selectedTrx.status === 'APPROVED' || selectedTrx.status === 'PAID') ? (
                  <div className="p-3.5 bg-emerald-500/10 border border-emerald-500/30 rounded-xl space-y-2 text-emerald-300">
                    <div className="flex items-center gap-2 font-bold text-xs text-emerald-400">
                      <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
                      <span>TOP-UP TELAH DISETUJUI & SALDO DIKREDITKAN</span>
                    </div>
                    <p className="text-[11px] leading-relaxed text-slate-300">
                      Top-Up saldo sebesar <b>Rp {selectedTrx.amount?.toLocaleString('id-ID')}</b> telah disetujui. Saldo akun pengguna <b>{selectedTrx.user_name || 'Pengguna'}</b> telah berhasil ditambah.
                    </p>
                    <div className="text-[10px] text-emerald-400 font-mono flex items-center gap-1.5 pt-1 border-t border-emerald-500/20">
                      <ShieldCheck className="w-3.5 h-3.5" />
                      <span>Metode: {selectedTrx.bank_name || 'Transfer Manual'} • Terverifikasi Admin</span>
                    </div>
                  </div>
                ) : selectedTrx.type === 'WITHDRAWAL' && selectedTrx.status === 'DISBURSED' ? (
                  <div className="p-3.5 bg-emerald-500/10 border border-emerald-500/30 rounded-xl space-y-2 text-emerald-300">
                    <div className="flex items-center gap-2 font-bold text-xs text-emerald-400">
                      <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
                      <span>PENARIKAN DANA TELAH DITRANSFER (DISBURSED)</span>
                    </div>
                    <p className="text-[11px] leading-relaxed text-slate-300">
                      Dana penarikan sebesar <b>Rp {selectedTrx.amount?.toLocaleString('id-ID')}</b> telah ditransfer ke rekening pengemudi <b>{selectedTrx.account_name || selectedTrx.user_name}</b> ({selectedTrx.bank_name} - {selectedTrx.account_number}).
                    </p>
                  </div>
                ) : selectedTrx.type === 'DP' && selectedTrx.booking_status === 'CANCELLED_BY_CLIENT' ? (
                  <button
                    onClick={() => handleExecuteForfeit(selectedTrx.id)}
                    className="w-full py-3 bg-rose-600 hover:bg-rose-500 text-white font-extrabold rounded-xl shadow-lg shadow-rose-600/20 flex items-center justify-center gap-2 transition-all"
                  >
                    <AlertOctagon className="w-4 h-4" />
                    <span>Eksekusi DP Hangus (50% Driver / 50% System)</span>
                  </button>
                ) : selectedTrx.type === 'DP' && selectedTrx.status === 'PENDING' ? (
                  <button
                    onClick={() => handleApproveEscrow(selectedTrx.id)}
                    className="w-full py-3 bg-emerald-600 hover:bg-emerald-500 text-white font-extrabold rounded-xl shadow-lg shadow-emerald-600/20 flex items-center justify-center gap-2 transition-all"
                  >
                    <CheckCircle2 className="w-4 h-4" />
                    <span>Setujui Pembayaran DP (Masuk ke Escrow Vault)</span>
                  </button>
                ) : selectedTrx.type === 'PELUNASAN' && selectedTrx.status === 'PENDING' ? (
                  <button
                    onClick={() => handleSettlePelunasan(selectedTrx.id)}
                    className="w-full py-3 bg-purple-600 hover:bg-purple-500 text-white font-extrabold rounded-xl shadow-lg shadow-purple-600/20 flex items-center justify-center gap-2 transition-all"
                  >
                    <TrendingUp className="w-4 h-4" />
                    <span>Setujui Pelunasan & Bagi Hasil 90% ke Driver</span>
                  </button>
                ) : selectedTrx.type === 'TOPUP' && selectedTrx.status === 'PENDING' ? (
                  <button
                    onClick={() => handleApproveEscrow(selectedTrx.id)}
                    className="w-full py-3 bg-emerald-600 hover:bg-emerald-500 text-white font-extrabold rounded-xl shadow-lg shadow-emerald-600/20 flex items-center justify-center gap-2 transition-all"
                  >
                    <CheckCircle2 className="w-4 h-4" />
                    <span>Setujui Top-Up & Tambahkan ke Saldo Pengguna (Rp {selectedTrx.amount?.toLocaleString('id-ID')})</span>
                  </button>
                ) : selectedTrx.type === 'WITHDRAWAL' && selectedTrx.status === 'PENDING' ? (
                  <button
                    onClick={() => handleDisbursePayout(selectedTrx.id)}
                    className="w-full py-3 bg-emerald-600 hover:bg-emerald-500 text-white font-extrabold rounded-xl shadow-lg shadow-emerald-600/20 flex items-center justify-center gap-2 transition-all"
                  >
                    <CheckCircle2 className="w-4 h-4" />
                    <span>Konfirmasi Transfer Penarikan Driver</span>
                  </button>
                ) : (
                  <div className="p-3 bg-slate-800/80 border border-slate-700 rounded-xl text-center text-xs text-slate-300 font-semibold">
                    ✅ Transaksi ini sudah berstatus: <b className="text-white uppercase">{selectedTrx.status}</b>
                  </div>
                )}

                {selectedTrx.status === 'PENDING' && (
                  <button
                    onClick={() => handleRejectTransaction(selectedTrx.id)}
                    className="w-full py-2.5 bg-rose-600/20 hover:bg-rose-600 text-rose-300 hover:text-white border border-rose-500/30 font-bold rounded-xl text-xs flex items-center justify-center gap-2 transition-all"
                  >
                    <XCircle className="w-4 h-4" />
                    <span>Tolak Transaksi {selectedTrx.type === 'WITHDRAWAL' ? '(Batalkan & Refund Saldo Driver)' : selectedTrx.type === 'TOPUP' ? '(Tolak Bukti Transfer Top-Up)' : ''}</span>
                  </button>
                )}

                <button
                  type="button"
                  onClick={() => handleDeleteTransaction(selectedTrx.id)}
                  className="w-full py-2 bg-slate-900/80 hover:bg-rose-950/60 text-rose-400 hover:text-rose-200 border border-rose-900/40 font-bold rounded-xl text-xs flex items-center justify-center gap-1.5 transition-all"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                  <span>Hapus Riwayat Transaksi Ini Secara Permanen</span>
                </button>

                <button
                  onClick={() => setSelectedTrx(null)}
                  className="w-full py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 font-bold rounded-xl text-xs transition-all"
                >
                  Tutup
                </button>
              </div>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
};
