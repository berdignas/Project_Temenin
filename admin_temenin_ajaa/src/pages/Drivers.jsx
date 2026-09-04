import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Search, Car, Star, CheckCircle, Clock, XCircle, Edit3, UserCheck, ShieldAlert } from 'lucide-react';
import { Badge } from '../components/Badge';
import { Modal } from '../components/Modal';
import { adminApi } from '../services/api';

export const Drivers = () => {
  const [drivers, setDrivers] = useState([]);
  const [statusFilter, setStatusFilter] = useState('');
  const [loading, setLoading] = useState(true);
  const [selectedDriver, setSelectedDriver] = useState(null);
  const [message, setMessage] = useState('');

  const fetchDrivers = async () => {
    setLoading(true);
    const data = await adminApi.getDrivers(statusFilter);
    setDrivers(data);
    setLoading(false);
  };

  useEffect(() => {
    fetchDrivers();
  }, [statusFilter]);

  const handleUpdateDriver = async (e) => {
    e.preventDefault();
    if (!selectedDriver) return;
    const res = await adminApi.updateDriver(selectedDriver.id, selectedDriver);
    setMessage(res.message);
    setSelectedDriver(null);
    fetchDrivers();
    setTimeout(() => setMessage(''), 3000);
  };

  return (
    <div className="space-y-6">
      {/* Alert */}
      {message && (
        <div className="p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-2xl text-sm font-semibold text-emerald-400 animate-in fade-in">
          {message}
        </div>
      )}

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-extrabold text-white tracking-tight">Manajemen Driver / Mitra</h2>
          <p className="text-sm text-slate-400">Pengelolaan mitra pengemudi dan pendamping perjalanan</p>
        </div>

        <div className="flex items-center gap-3">
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="px-3 py-2.5 bg-slate-800 border border-slate-700 rounded-xl text-xs text-white focus:outline-none focus:border-indigo-500"
          >
            <option value="">Semua Status Mitra</option>
            <option value="approved">Approved (Disetujui)</option>
            <option value="pending">Pending (Menunggu Verifikasi)</option>
            <option value="rejected">Rejected (Ditolak)</option>
          </select>
          <Link
            to="/driver-approvals"
            className="px-4 py-2.5 bg-amber-600 hover:bg-amber-500 text-white font-bold text-xs rounded-xl flex items-center gap-2 transition-all shadow-lg shadow-amber-600/20"
          >
            <UserCheck className="w-4 h-4" />
            <span>Antrean Pendaftaran</span>
          </Link>
        </div>
      </div>

      {/* Driver Grid Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {loading ? (
          <div className="col-span-full py-12 text-center text-slate-500 font-semibold">
            Memuat data driver...
          </div>
        ) : drivers.length === 0 ? (
          <div className="col-span-full py-12 text-center text-slate-500 font-semibold">
            Tidak ada driver ditemukan.
          </div>
        ) : (
          drivers.map((driver) => (
            <div
              key={driver.id}
              className="bg-slate-800/40 border border-slate-700/50 rounded-2xl p-5 backdrop-blur-md hover:border-slate-600 transition-all flex flex-col justify-between space-y-4"
            >
              <div className="space-y-3">
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-center gap-3">
                    <div className="w-11 h-11 rounded-full bg-gradient-to-tr from-indigo-600 to-blue-600 text-white font-bold text-base flex items-center justify-center border border-indigo-400/30 shadow-md">
                      {driver.users?.full_name?.charAt(0) || 'D'}
                    </div>
                    <div>
                      <h3 className="font-extrabold text-white text-sm">{driver.users?.full_name || 'Driver'}</h3>
                      <p className="text-xs text-slate-400">{driver.users?.phone || '-'}</p>
                    </div>
                  </div>

                  {driver.status === 'approved' && <Badge variant="success">Approved</Badge>}
                  {driver.status === 'pending' && <Badge variant="warning">Pending</Badge>}
                  {driver.status === 'rejected' && <Badge variant="danger">Rejected</Badge>}
                </div>

                <div className="p-3 bg-slate-900/60 rounded-xl border border-slate-800 space-y-1.5 text-xs">
                  <div className="flex justify-between text-slate-300">
                    <span className="text-slate-500">Kendaraan:</span>
                    <span className="font-semibold text-white">{driver.vehicle_name}</span>
                  </div>
                  <div className="flex justify-between text-slate-300">
                    <span className="text-slate-500">Nomor Plat:</span>
                    <span className="font-mono font-bold text-indigo-400">{driver.plate_number}</span>
                  </div>
                  <div className="flex justify-between text-slate-300">
                    <span className="text-slate-500">Tarif per Jam:</span>
                    <span className="font-bold text-emerald-400">
                      Rp {parseFloat(driver.price_per_hour || 50000).toLocaleString('id-ID')}/jam
                    </span>
                  </div>
                </div>

                <div className="flex items-center justify-between text-xs pt-1">
                  <div className="flex items-center gap-1 text-amber-400 font-bold">
                    <Star className="w-3.5 h-3.5 fill-amber-400" />
                    <span>{driver.rating || 5.0}</span>
                    <span className="text-slate-500 font-normal">({driver.total_rides || 0} trip)</span>
                  </div>

                  <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                    driver.is_available ? 'bg-emerald-500/10 text-emerald-400' : 'bg-slate-700/50 text-slate-400'
                  }`}>
                    {driver.is_available ? 'Online (Tersedia)' : 'Offline'}
                  </span>
                </div>
              </div>

              <div className="pt-3 border-t border-slate-800 flex items-center justify-between">
                <span className="text-[10px] font-mono text-slate-500">EXP: {driver.experience_years || 0} Tahun</span>
                <button
                  onClick={() => setSelectedDriver(driver)}
                  className="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 border border-slate-700 text-xs font-semibold text-slate-200 rounded-lg flex items-center gap-1.5 transition-colors"
                >
                  <Edit3 className="w-3.5 h-3.5 text-indigo-400" />
                  <span>Edit Driver</span>
                </button>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Edit Driver Modal */}
      <Modal
        isOpen={!!selectedDriver}
        onClose={() => setSelectedDriver(null)}
        title="Edit Data Mitra Driver"
      >
        {selectedDriver && (
          <form onSubmit={handleUpdateDriver} className="space-y-4 text-xs">
            <div>
              <label className="block text-slate-400 mb-1 font-semibold">Nama / Tipe Kendaraan</label>
              <input
                type="text"
                value={selectedDriver.vehicle_name || ''}
                onChange={(e) => setSelectedDriver({ ...selectedDriver, vehicle_name: e.target.value })}
                className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-white font-semibold focus:outline-none focus:border-indigo-500"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-slate-400 mb-1 font-semibold">Nomor Plat Polisi</label>
                <input
                  type="text"
                  value={selectedDriver.plate_number || ''}
                  onChange={(e) => setSelectedDriver({ ...selectedDriver, plate_number: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-white font-mono focus:outline-none focus:border-indigo-500"
                />
              </div>
              <div>
                <label className="block text-slate-400 mb-1 font-semibold">Tarif Per Jam (Rp)</label>
                <input
                  type="number"
                  value={selectedDriver.price_per_hour || 50000}
                  onChange={(e) => setSelectedDriver({ ...selectedDriver, price_per_hour: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-white font-mono focus:outline-none focus:border-indigo-500"
                />
              </div>
            </div>

            <div>
              <label className="block text-slate-400 mb-1 font-semibold">Kategori Kendaraan</label>
              <input
                type="text"
                value={selectedDriver.vehicle_type || ''}
                onChange={(e) => setSelectedDriver({ ...selectedDriver, vehicle_type: e.target.value })}
                className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-white focus:outline-none focus:border-indigo-500"
              />
            </div>

            <div className="flex items-center gap-3 pt-2">
              <label className="flex items-center gap-2 cursor-pointer text-slate-300 font-semibold">
                <input
                  type="checkbox"
                  checked={!!selectedDriver.is_available}
                  onChange={(e) => setSelectedDriver({ ...selectedDriver, is_available: e.target.checked })}
                  className="w-4 h-4 rounded text-indigo-600 bg-slate-800 border-slate-700"
                />
                <span>Status Siap Beroperasi (Online)</span>
              </label>
            </div>

            <div className="pt-4 flex justify-end gap-3 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setSelectedDriver(null)}
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
        )}
      </Modal>
    </div>
  );
};
