import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { 
  Users, 
  Car, 
  UserCheck, 
  CalendarCheck, 
  Wallet, 
  ArrowUpRight, 
  CheckCircle2, 
  XCircle,
  Eye,
  Clock
} from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';
import { StatCard } from '../components/StatCard';
import { Badge } from '../components/Badge';
import { Modal } from '../components/Modal';
import { adminApi } from '../services/api';

const chartData = [
  { day: 'Sen', order: 12, revenue: 540000 },
  { day: 'Sel', order: 19, revenue: 820000 },
  { day: 'Rab', order: 15, revenue: 680000 },
  { day: 'Kam', order: 25, revenue: 1150000 },
  { day: 'Jum', order: 32, revenue: 1450000 },
  { day: 'Sab', order: 45, revenue: 2100000 },
  { day: 'Min', order: 38, revenue: 1800000 },
];

export const Dashboard = () => {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [selectedDriver, setSelectedDriver] = useState(null);
  const [actionMessage, setActionMessage] = useState('');

  const loadData = async () => {
    setLoading(true);
    const data = await adminApi.getStats();
    setStats(data);
    setLoading(false);
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleVerify = async (driverId, status) => {
    const res = await adminApi.verifyDriver(driverId, status);
    setActionMessage(res.message);
    setSelectedDriver(null);
    loadData();
    setTimeout(() => setActionMessage(''), 3000);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 text-slate-400 font-semibold">
        Memuat data dashboard admin...
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Toast Alert */}
      {actionMessage && (
        <div className="p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-2xl text-sm font-semibold text-emerald-400 flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5" />
          <span>{actionMessage}</span>
        </div>
      )}

      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-extrabold text-white tracking-tight">Dashboard Ringkasan</h2>
          <p className="text-sm text-slate-400">Pantau dan kelola seluruh aktivitas ekosistem Temenin Ajaa</p>
        </div>
        <div className="flex items-center gap-3">
          <Link
            to="/driver-approvals"
            className="px-4 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs rounded-xl shadow-lg shadow-indigo-600/20 flex items-center gap-2 transition-all"
          >
            <UserCheck className="w-4 h-4" />
            <span>Persetujuan Mitra ({stats?.pendingDrivers || 0})</span>
          </Link>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
        <StatCard
          title="Total Client"
          value={stats?.totalUsers || 0}
          icon={Users}
          trend="up"
          trendValue="+12%"
          color="sky"
        />
        <StatCard
          title="Mitra Driver"
          value={stats?.totalDrivers || 0}
          icon={Car}
          trend="up"
          trendValue="+8%"
          color="indigo"
        />
        <StatCard
          title="Pending Verifikasi"
          value={stats?.pendingDrivers || 0}
          icon={UserCheck}
          trend="up"
          trendValue="Perlu Tindakan"
          color="amber"
        />
        <StatCard
          title="Pesanan Aktif"
          value={stats?.activeBookings || 0}
          icon={CalendarCheck}
          trend="up"
          trendValue="+15%"
          color="purple"
        />
        <StatCard
          title="Total Omset"
          value={`Rp ${((stats?.totalRevenue || 0) / 1000).toLocaleString('id-ID')}rb`}
          icon={Wallet}
          trend="up"
          trendValue="+24%"
          color="emerald"
        />
      </div>

      {/* Analytics Chart & Quick Stats */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Revenue Trend Chart */}
        <div className="lg:col-span-2 bg-slate-800/40 border border-slate-700/50 rounded-2xl p-6 backdrop-blur-md">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="font-extrabold text-white text-base">Tren Transaksi & Omset Mingguan</h3>
              <p className="text-xs text-slate-400">Total akumulasi dari pesanan selesai</p>
            </div>
            <span className="text-xs font-semibold px-3 py-1 bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 rounded-full">
              Minggu Ini
            </span>
          </div>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData}>
                <defs>
                  <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#6366f1" stopOpacity={0.4}/>
                    <stop offset="95%" stopColor="#6366f1" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <XAxis dataKey="day" stroke="#64748b" fontSize={12} tickLine={false} />
                <YAxis stroke="#64748b" fontSize={12} tickLine={false} />
                <Tooltip
                  contentStyle={{ backgroundColor: '#0f172a', borderColor: '#334155', borderRadius: '12px', color: '#fff' }}
                  formatter={(val) => `Rp ${val.toLocaleString('id-ID')}`}
                />
                <Area type="monotone" dataKey="revenue" stroke="#6366f1" strokeWidth={3} fillOpacity={1} fill="url(#colorRevenue)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* System Distribution Summary */}
        <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl p-6 backdrop-blur-md flex flex-col justify-between space-y-4">
          <div>
            <h3 className="font-extrabold text-white text-base mb-1">Status Ekosistem</h3>
            <p className="text-xs text-slate-400">Ringkasan status mitra dan pesanan</p>
          </div>

          <div className="space-y-4">
            <div className="p-4 bg-slate-900/60 rounded-xl border border-slate-800">
              <div className="flex justify-between items-center text-xs font-semibold mb-2">
                <span className="text-slate-400">Mitra Driver Approved</span>
                <span className="text-emerald-400">{stats?.approvedDrivers || 0} Driver</span>
              </div>
              <div className="w-full h-2 bg-slate-800 rounded-full overflow-hidden">
                <div className="h-full bg-emerald-500" style={{ width: `${stats?.totalDrivers ? ((stats.approvedDrivers/stats.totalDrivers)*100) : 0}%` }}></div>
              </div>
            </div>

            <div className="p-4 bg-slate-900/60 rounded-xl border border-slate-800">
              <div className="flex justify-between items-center text-xs font-semibold mb-2">
                <span className="text-slate-400">Persetujuan Pending</span>
                <span className="text-amber-400">{stats?.pendingDrivers || 0} Pengajuan</span>
              </div>
              <div className="w-full h-2 bg-slate-800 rounded-full overflow-hidden">
                <div className="h-full bg-amber-500" style={{ width: `${stats?.totalDrivers ? ((stats.pendingDrivers/stats.totalDrivers)*100) : 0}%` }}></div>
              </div>
            </div>

            <div className="p-4 bg-slate-900/60 rounded-xl border border-slate-800">
              <div className="flex justify-between items-center text-xs font-semibold mb-2">
                <span className="text-slate-400">Tingkat Penyelesaian Order</span>
                <span className="text-indigo-400">94.8%</span>
              </div>
              <div className="w-full h-2 bg-slate-800 rounded-full overflow-hidden">
                <div className="h-full bg-indigo-500" style={{ width: '94.8%' }}></div>
              </div>
            </div>
          </div>

          <Link
            to="/finance"
            className="w-full py-2.5 bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold rounded-xl flex items-center justify-center gap-2 border border-slate-700 transition-colors"
          >
            <span>Buka Laporan Keuangan</span>
            <ArrowUpRight className="w-3.5 h-3.5" />
          </Link>
        </div>
      </div>

      {/* Pending Driver Approvals Grid */}
      {stats?.pendingDriverList && stats.pendingDriverList.length > 0 && (
        <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl p-6 backdrop-blur-md">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-amber-400 animate-ping"></div>
              <h3 className="font-extrabold text-white text-base">Permohonan Mitra Driver Baru ({stats.pendingDriverList.length})</h3>
            </div>
            <Link to="/driver-approvals" className="text-xs font-bold text-indigo-400 hover:underline">
              Lihat Semua
            </Link>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {stats.pendingDriverList.map((driver) => (
              <div key={driver.id} className="p-4 bg-slate-900/80 border border-slate-800 rounded-xl flex items-center justify-between gap-4 hover:border-slate-700 transition-colors">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-amber-500/20 text-amber-400 flex items-center justify-center font-bold">
                    {driver.users?.full_name?.charAt(0) || 'D'}
                  </div>
                  <div>
                    <h4 className="font-bold text-sm text-white">{driver.users?.full_name}</h4>
                    <p className="text-xs text-slate-400">{driver.vehicle_type} • Plat: {driver.plate_number}</p>
                    <span className="text-[10px] text-amber-400 font-medium">SIM: {driver.driver_license_number}</span>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setSelectedDriver(driver)}
                    className="p-2 text-slate-300 bg-slate-800 hover:bg-slate-700 rounded-lg border border-slate-700 text-xs font-semibold flex items-center gap-1"
                    title="Periksa Berkas"
                  >
                    <Eye className="w-3.5 h-3.5" />
                  </button>
                  <button
                    onClick={() => handleVerify(driver.id, 'approved')}
                    className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs rounded-lg flex items-center gap-1"
                  >
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    <span>Setujui</span>
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Recent Bookings Table */}
      <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl p-6 backdrop-blur-md">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-extrabold text-white text-base">Aktivitas Pemesanan Terbaru</h3>
          <Link to="/bookings" className="text-xs font-bold text-indigo-400 hover:underline">
            Lihat Semua Pesanan
          </Link>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-800 text-slate-400 uppercase tracking-wider font-semibold">
                <th className="pb-3 px-3">Booking ID</th>
                <th className="pb-3 px-3">Client</th>
                <th className="pb-3 px-3">Driver</th>
                <th className="pb-3 px-3">Lokasi Penjemputan</th>
                <th className="pb-3 px-3">Total Harga</th>
                <th className="pb-3 px-3">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 text-slate-300">
              {stats?.recentBookings?.map((booking) => (
                <tr key={booking.id} className="hover:bg-slate-800/30 transition-colors">
                  <td className="py-3.5 px-3 font-mono font-bold text-indigo-400">{booking.id}</td>
                  <td className="py-3.5 px-3 font-semibold text-white">{booking.users?.full_name || 'Client'}</td>
                  <td className="py-3.5 px-3">{booking.drivers?.users?.full_name || <span className="text-slate-500 italic">Mencari driver</span>}</td>
                  <td className="py-3.5 px-3 max-w-xs truncate text-slate-400">{booking.pickup_location}</td>
                  <td className="py-3.5 px-3 font-bold text-white">
                    Rp {parseFloat(booking.total_price || 0).toLocaleString('id-ID')}
                  </td>
                  <td className="py-3.5 px-3">
                    {booking.status === 'completed' && <Badge variant="success">Selesai</Badge>}
                    {booking.status === 'ongoing' && <Badge variant="indigo">Berjalan</Badge>}
                    {booking.status === 'pending' && <Badge variant="warning">Mencari</Badge>}
                    {booking.status === 'cancelled' && <Badge variant="danger">Batal</Badge>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Driver Detail Modal */}
      <Modal
        isOpen={!!selectedDriver}
        onClose={() => setSelectedDriver(null)}
        title="Pemeriksaan Berkas Pendaftaran Driver"
      >
        {selectedDriver && (
          <div className="space-y-4 text-xs">
            <div className="p-4 bg-slate-950 rounded-xl border border-slate-800 flex items-center gap-4">
              <div className="w-12 h-12 rounded-full bg-indigo-500/20 text-indigo-400 font-bold text-lg flex items-center justify-center border border-indigo-500/30">
                {selectedDriver.users?.full_name?.charAt(0)}
              </div>
              <div>
                <h4 className="font-extrabold text-sm text-white">{selectedDriver.users?.full_name}</h4>
                <p className="text-slate-400">{selectedDriver.users?.phone} • {selectedDriver.users?.email}</p>
                <Badge variant="warning" size="sm">Menunggu Persetujuan</Badge>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-700/60">
                <span className="text-slate-400 block mb-1">Jenis & Nama Kendaraan</span>
                <span className="font-bold text-white">{selectedDriver.vehicle_name} ({selectedDriver.vehicle_type})</span>
              </div>
              <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-700/60">
                <span className="text-slate-400 block mb-1">Nomor Plat Polisi</span>
                <span className="font-bold text-emerald-400 font-mono">{selectedDriver.plate_number}</span>
              </div>
              <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-700/60">
                <span className="text-slate-400 block mb-1">Nomor KTP</span>
                <span className="font-bold text-white font-mono">{selectedDriver.id_card_number}</span>
              </div>
              <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-700/60">
                <span className="text-slate-400 block mb-1">Nomor SIM</span>
                <span className="font-bold text-white font-mono">{selectedDriver.driver_license_number}</span>
              </div>
            </div>

            <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-700/60">
              <span className="text-slate-400 block mb-1">Nomor STNK / Dokumen Pendukung</span>
              <span className="font-bold text-indigo-300 font-mono">{selectedDriver.vehicle_stnk}</span>
            </div>

            <div className="pt-4 flex items-center justify-end gap-3 border-t border-slate-800">
              <button
                onClick={() => handleVerify(selectedDriver.id, 'rejected')}
                className="px-4 py-2 bg-rose-600/20 text-rose-400 border border-rose-500/30 hover:bg-rose-600/30 font-bold rounded-xl flex items-center gap-1.5"
              >
                <XCircle className="w-4 h-4" />
                <span>Tolak Pendaftaran</span>
              </button>
              <button
                onClick={() => handleVerify(selectedDriver.id, 'approved')}
                className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-xl flex items-center gap-1.5 shadow-lg shadow-emerald-600/20"
              >
                <CheckCircle2 className="w-4 h-4" />
                <span>Setujui Sebagai Mitra</span>
              </button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};
