import React, { useState, useEffect } from 'react';
import { CheckCircle2, XCircle, ShieldAlert, FileText, UserCheck, RefreshCw } from 'lucide-react';
import { Badge } from '../components/Badge';
import { Modal } from '../components/Modal';
import { adminApi } from '../services/api';

export const DriverApprovals = () => {
  const [pendingDrivers, setPendingDrivers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedDriver, setSelectedDriver] = useState(null);
  const [message, setMessage] = useState('');

  const fetchPending = async () => {
    setLoading(true);
    const data = await adminApi.getDrivers('pending');
    setPendingDrivers(data);
    setLoading(false);
  };

  useEffect(() => {
    fetchPending();
  }, []);

  const handleVerify = async (driverId, status) => {
    const res = await adminApi.verifyDriver(driverId, status);
    setMessage(res.message);
    setSelectedDriver(null);
    fetchPending();
    setTimeout(() => setMessage(''), 3000);
  };

  return (
    <div className="space-y-6">
      {/* Toast Alert */}
      {message && (
        <div className="p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-2xl text-sm font-semibold text-emerald-400 flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5" />
          <span>{message}</span>
        </div>
      )}

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-2xl font-extrabold text-white tracking-tight">Persetujuan Pendaftaran Mitra Driver</h2>
            <span className="px-2.5 py-0.5 text-xs font-bold bg-amber-500 text-slate-950 rounded-full">
              {pendingDrivers.length} Pengajuan
            </span>
          </div>
          <p className="text-sm text-slate-400">Verifikasi dokumen SIM, STNK, dan KTP pendaftar baru sebelum aktif beroperasi</p>
        </div>

        <button
          onClick={fetchPending}
          className="px-4 py-2.5 bg-slate-800 border border-slate-700 rounded-xl text-slate-300 hover:text-white font-semibold text-xs flex items-center gap-2"
        >
          <RefreshCw className="w-4 h-4" />
          <span>Muat Ulang</span>
        </button>
      </div>

      {/* Queue List */}
      {loading ? (
        <div className="py-12 text-center text-slate-500 font-semibold">
          Memuat permohonan mitra driver...
        </div>
      ) : pendingDrivers.length === 0 ? (
        <div className="bg-slate-800/30 border border-slate-700/50 rounded-2xl p-12 text-center space-y-3">
          <div className="w-16 h-16 rounded-2xl bg-emerald-500/10 text-emerald-400 mx-auto flex items-center justify-center border border-emerald-500/20">
            <UserCheck className="w-8 h-8" />
          </div>
          <h3 className="text-lg font-bold text-white">Tidak Ada Permohonan Pending</h3>
          <p className="text-xs text-slate-400 max-w-sm mx-auto">
            Seluruh pendaftaran mitra driver telah selesai diverifikasi oleh tim admin.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {pendingDrivers.map((driver) => (
            <div
              key={driver.id}
              className="bg-slate-800/40 border border-slate-700/50 rounded-2xl p-5 backdrop-blur-md hover:border-amber-500/40 transition-all space-y-4"
            >
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-full bg-amber-500/20 text-amber-400 font-extrabold text-lg flex items-center justify-center border border-amber-500/30">
                    {driver.users?.full_name?.charAt(0) || 'D'}
                  </div>
                  <div>
                    <h3 className="font-extrabold text-white text-base">{driver.users?.full_name || 'Calon Driver'}</h3>
                    <p className="text-xs text-slate-400">{driver.users?.phone || '-'} • {driver.users?.email || '-'}</p>
                    <span className="text-[10px] text-slate-500">
                      Tanggal Daftar: {new Date(driver.created_at).toLocaleDateString('id-ID')}
                    </span>
                  </div>
                </div>
                <Badge variant="warning">Pending</Badge>
              </div>

              {/* Document Overview */}
              <div className="p-3.5 bg-slate-900/80 rounded-xl border border-slate-800 space-y-2 text-xs">
                <div className="flex justify-between items-center">
                  <span className="text-slate-400">Kendaraan:</span>
                  <span className="font-bold text-white">{driver.vehicle_name} ({driver.vehicle_type})</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-slate-400">Nomor Plat Polisi:</span>
                  <span className="font-mono font-bold text-emerald-400">{driver.plate_number}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-slate-400">Nomor KTP:</span>
                  <span className="font-mono text-slate-300">{driver.id_card_number}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-slate-400">Nomor SIM:</span>
                  <span className="font-mono text-slate-300">{driver.driver_license_number}</span>
                </div>
              </div>

              {/* Actions */}
              <div className="flex items-center justify-between pt-2">
                <button
                  onClick={() => setSelectedDriver(driver)}
                  className="px-3.5 py-2 bg-slate-800 hover:bg-slate-700 border border-slate-700 text-xs font-semibold text-slate-300 rounded-xl flex items-center gap-1.5 transition-colors"
                >
                  <FileText className="w-3.5 h-3.5 text-indigo-400" />
                  <span>Detail Berkas</span>
                </button>

                <div className="flex items-center gap-2">
                  <button
                    onClick={() => handleVerify(driver.id, 'rejected')}
                    className="px-3 py-2 bg-rose-600/20 hover:bg-rose-600/30 text-rose-400 border border-rose-500/30 font-bold text-xs rounded-xl flex items-center gap-1 transition-colors"
                  >
                    <XCircle className="w-3.5 h-3.5" />
                    <span>Tolak</span>
                  </button>
                  <button
                    onClick={() => handleVerify(driver.id, 'approved')}
                    className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs rounded-xl flex items-center gap-1.5 shadow-lg shadow-emerald-600/20 transition-all"
                  >
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    <span>Setujui Driver</span>
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modal Review */}
      <Modal
        isOpen={!!selectedDriver}
        onClose={() => setSelectedDriver(null)}
        title="Detail Berkas & Identitas Pendaftar"
      >
        {selectedDriver && (
          <div className="space-y-4 text-xs">
            <div className="p-4 bg-slate-950 rounded-xl border border-slate-800 flex items-center justify-between">
              <div>
                <h4 className="font-extrabold text-sm text-white">{selectedDriver.users?.full_name}</h4>
                <p className="text-slate-400">{selectedDriver.users?.phone}</p>
              </div>
              <Badge variant="warning">Status: Pending</Badge>
            </div>

            <div className="space-y-3">
              <h5 className="font-bold text-slate-300 uppercase tracking-wider text-[10px]">Pemeriksaan Dokumen Legal</h5>
              <div className="grid grid-cols-2 gap-3">
                <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-700/60">
                  <span className="text-slate-400 block mb-1">Nomor Induk Kependudukan (KTP)</span>
                  <span className="font-mono font-bold text-white text-sm">{selectedDriver.id_card_number}</span>
                </div>
                <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-700/60">
                  <span className="text-slate-400 block mb-1">Nomor Surat Izin Mengemudi (SIM)</span>
                  <span className="font-mono font-bold text-white text-sm">{selectedDriver.driver_license_number}</span>
                </div>
              </div>

              <div className="p-3 bg-slate-800/60 rounded-xl border border-slate-700/60">
                <span className="text-slate-400 block mb-1">Nomor Dokumen STNK / Registrasi Kendaraan</span>
                <span className="font-mono font-bold text-indigo-300 text-sm">{selectedDriver.vehicle_stnk}</span>
              </div>
            </div>

            <div className="pt-4 flex items-center justify-end gap-3 border-t border-slate-800">
              <button
                onClick={() => handleVerify(selectedDriver.id, 'rejected')}
                className="px-4 py-2.5 bg-rose-600/20 text-rose-400 border border-rose-500/30 hover:bg-rose-600/30 font-bold rounded-xl flex items-center gap-1.5"
              >
                <XCircle className="w-4 h-4" />
                <span>Tolak Permohonan</span>
              </button>
              <button
                onClick={() => handleVerify(selectedDriver.id, 'approved')}
                className="px-5 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-xl flex items-center gap-1.5 shadow-lg shadow-emerald-600/20"
              >
                <CheckCircle2 className="w-4 h-4" />
                <span>Setujui & Aktifkan Mitra</span>
              </button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};
