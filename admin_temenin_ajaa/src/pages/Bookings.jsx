import React, { useState, useEffect } from 'react';
import { 
  CalendarCheck, MapPin, Clock, DollarSign, RefreshCw, XCircle, CheckCircle, 
  Plus, Edit2, Trash2, OctagonAlert, ShieldCheck, ArrowRight, CreditCard, Search,
  CheckSquare
} from 'lucide-react';
import { Badge } from '../components/Badge';
import { Modal } from '../components/Modal';
import { adminApi } from '../services/api';

export const Bookings = () => {
  const [bookings, setBookings] = useState([]);
  const [statusFilter, setStatusFilter] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [selectedBooking, setSelectedBooking] = useState(null);
  const [financeModalBooking, setFinanceModalBooking] = useState(null);
  
  // Single delete state
  const [deleteModalBooking, setDeleteModalBooking] = useState(null);
  const [deleteFinanceChecked, setDeleteFinanceChecked] = useState(true);
  const [isDeleting, setIsDeleting] = useState(false);

  // Bulk delete state
  const [selectedBookingIds, setSelectedBookingIds] = useState([]);
  const [isBulkDeleteModalOpen, setIsBulkDeleteModalOpen] = useState(false);
  const [bulkDeleteFinanceChecked, setBulkDeleteFinanceChecked] = useState(true);
  const [isBulkDeleting, setIsBulkDeleting] = useState(false);

  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [message, setMessage] = useState('');

  // Form state for new / edited booking
  const [formData, setFormData] = useState({
    client_name: '',
    driver_name: '',
    pickup_location: '',
    dropoff_location: '',
    total_price: '',
    duration: 60,
    status: 'pending'
  });

  const fetchBookings = async () => {
    setLoading(true);
    try {
      const data = await adminApi.getBookings(statusFilter);
      setBookings(data);
    } catch (err) {
      console.error("Error fetching bookings:", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchBookings();
  }, [statusFilter]);

  const handleUpdateStatus = async (id, status) => {
    const res = await adminApi.updateBookingStatus(id, status);
    setMessage(res.message);
    setSelectedBooking(null);
    fetchBookings();
    setTimeout(() => setMessage(''), 4000);
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    const res = await adminApi.createBooking(formData);
    setMessage(res.message);
    setIsCreateOpen(false);
    setFormData({ 
      client_name: '', 
      driver_name: '', 
      pickup_location: '', 
      dropoff_location: '', 
      total_price: '', 
      duration: 60, 
      status: 'pending' 
    });
    fetchBookings();
    setTimeout(() => setMessage(''), 4000);
  };

  const handleEditOpen = (booking) => {
    setSelectedBooking(booking);
    setFormData({
      client_name: booking.users?.full_name || '',
      driver_name: booking.drivers?.users?.full_name || '',
      pickup_location: booking.pickup_location || '',
      dropoff_location: booking.dropoff_location || '',
      total_price: booking.total_price || '',
      duration: booking.duration || 60,
      status: booking.status || 'pending'
    });
    setIsEditOpen(true);
  };

  const handleEditSubmit = async (e) => {
    e.preventDefault();
    if (!selectedBooking) return;
    const res = await adminApi.updateBooking(selectedBooking.id, formData);
    setMessage(res.message);
    setIsEditOpen(false);
    setSelectedBooking(null);
    fetchBookings();
    setTimeout(() => setMessage(''), 4000);
  };

  // Single Delete Handlers (No more typing 'HAPUS')
  const handleDeleteClick = (booking) => {
    setDeleteModalBooking(booking);
    setDeleteFinanceChecked(true);
  };

  const handleConfirmDelete = async () => {
    if (!deleteModalBooking || isDeleting) return;
    setIsDeleting(true);
    try {
      const res = await adminApi.deleteBooking(deleteModalBooking.id, deleteFinanceChecked);
      setMessage(res.message);
      setSelectedBookingIds(prev => prev.filter(id => id !== deleteModalBooking.id));
      setDeleteModalBooking(null);
      setSelectedBooking(null);
      fetchBookings();
      setTimeout(() => setMessage(''), 5000);
    } catch (err) {
      alert('Gagal menghapus pesanan: ' + (err.response?.data?.message || err.message));
    } finally {
      setIsDeleting(false);
    }
  };

  // Bulk Selection & Deletion Handlers
  const handleToggleSelectAll = (filteredList) => {
    if (selectedBookingIds.length === filteredList.length && filteredList.length > 0) {
      setSelectedBookingIds([]);
    } else {
      setSelectedBookingIds(filteredList.map(b => b.id));
    }
  };

  const handleToggleSelectOne = (id) => {
    setSelectedBookingIds(prev =>
      prev.includes(id) ? prev.filter(item => item !== id) : [...prev, id]
    );
  };

  const handleSelectCancelled = () => {
    const cancelledIds = bookings.filter(b => b.status === 'cancelled').map(b => b.id);
    setSelectedBookingIds(cancelledIds);
  };

  const handleConfirmBulkDelete = async () => {
    if (selectedBookingIds.length === 0 || isBulkDeleting) return;
    setIsBulkDeleting(true);
    try {
      const res = await adminApi.bulkDeleteBookings(selectedBookingIds, bulkDeleteFinanceChecked);
      setMessage(res.message || `${selectedBookingIds.length} pesanan berhasil dihapus.`);
      setSelectedBookingIds([]);
      setIsBulkDeleteModalOpen(false);
      fetchBookings();
      setTimeout(() => setMessage(''), 5000);
    } catch (err) {
      alert('Gagal menghapus pesanan: ' + (err.response?.data?.message || err.message));
    } finally {
      setIsBulkDeleting(false);
    }
  };

  const filteredBookings = bookings.filter(b => {
    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      const matchClient = b.users?.full_name?.toLowerCase().includes(q);
      const matchDriver = b.drivers?.users?.full_name?.toLowerCase().includes(q);
      const matchId = b.id?.toLowerCase().includes(q);
      const matchLoc = b.pickup_location?.toLowerCase().includes(q) || b.dropoff_location?.toLowerCase().includes(q);
      return matchClient || matchDriver || matchId || matchLoc;
    }
    return true;
  });

  return (
    <div className="space-y-6">
      {/* Alert Notification */}
      {message && (
        <div className="p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-2xl text-sm font-semibold text-emerald-400 flex items-center justify-between animate-in fade-in">
          <div className="flex items-center gap-2">
            <CheckCircle className="w-5 h-5" />
            <span>{message}</span>
          </div>
          <span className="text-xs text-slate-400">Sinkronisasi Keuangan Otomatis</span>
        </div>
      )}

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-extrabold text-white tracking-tight">Pemesanan & Order Status</h2>
          <p className="text-sm text-slate-400">Manajemen Alur Pesanan & Keterhubungan Langsung dengan Status Keuangan DP</p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {bookings.filter(b => b.status === 'cancelled').length > 0 && (
            <button
              onClick={handleSelectCancelled}
              className="px-3.5 py-2.5 bg-rose-950/40 hover:bg-rose-900/50 text-rose-300 border border-rose-800/60 rounded-xl text-xs font-bold flex items-center gap-1.5 transition-all shadow-sm"
              title="Tandai semua pesanan yang dibatalkan untuk dibersihkan"
            >
              <Trash2 className="w-4 h-4 text-rose-400" />
              <span>Pilih Yang Batal ({bookings.filter(b => b.status === 'cancelled').length})</span>
            </button>
          )}
          <button
            onClick={() => setIsCreateOpen(true)}
            className="px-4 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-bold flex items-center gap-2 transition-all shadow-lg shadow-indigo-600/20"
          >
            <Plus className="w-4 h-4" />
            <span>+ Buat Pesanan Baru</span>
          </button>
          <button
            onClick={fetchBookings}
            className="p-2.5 bg-slate-800 border border-slate-700 rounded-xl text-slate-300 hover:text-white"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Simplified Status Filter Bar (Kanban Tabs) */}
      <div className="bg-slate-900/60 p-1.5 rounded-2xl border border-slate-800 flex flex-wrap gap-1">
        <button
          onClick={() => setStatusFilter('')}
          className={`flex-1 min-w-[120px] py-2 px-3 rounded-xl text-xs font-bold transition-all ${
            statusFilter === '' ? 'bg-indigo-600 text-white shadow' : 'text-slate-400 hover:text-white'
          }`}
        >
          Semua Pesanan ({bookings.length})
        </button>

        <button
          onClick={() => setStatusFilter('pending')}
          className={`flex-1 min-w-[120px] py-2 px-3 rounded-xl text-xs font-bold transition-all ${
            statusFilter === 'pending' ? 'bg-amber-600 text-white shadow' : 'text-slate-400 hover:text-white'
          }`}
        >
          ⏳ Menunggu DP ({bookings.filter(b => b.status === 'pending').length})
        </button>

        <button
          onClick={() => setStatusFilter('ongoing')}
          className={`flex-1 min-w-[120px] py-2 px-3 rounded-xl text-xs font-bold transition-all ${
            statusFilter === 'ongoing' ? 'bg-indigo-600 text-white shadow' : 'text-slate-400 hover:text-white'
          }`}
        >
          🚀 Berjalan ({bookings.filter(b => b.status === 'ongoing').length})
        </button>

        <button
          onClick={() => setStatusFilter('completed')}
          className={`flex-1 min-w-[120px] py-2 px-3 rounded-xl text-xs font-bold transition-all ${
            statusFilter === 'completed' ? 'bg-emerald-600 text-white shadow' : 'text-slate-400 hover:text-white'
          }`}
        >
          🏁 Selesai ({bookings.filter(b => b.status === 'completed').length})
        </button>

        <button
          onClick={() => setStatusFilter('cancelled')}
          className={`flex-1 min-w-[120px] py-2 px-3 rounded-xl text-xs font-bold transition-all ${
            statusFilter === 'cancelled' ? 'bg-rose-600 text-white shadow' : 'text-slate-400 hover:text-white'
          }`}
        >
          ❌ Dibatalkan ({bookings.filter(b => b.status === 'cancelled').length})
        </button>
      </div>

      {/* Search Input Bar */}
      <div className="flex items-center gap-2 bg-slate-800/80 border border-slate-700 px-3.5 py-2 rounded-xl text-xs">
        <Search className="w-4 h-4 text-slate-400" />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Cari ID Pesanan, Nama Client, Driver, atau Lokasi..."
          className="bg-transparent text-white focus:outline-none w-full"
        />
      </div>

      {/* BULK ACTION BAR (Tampil ketika ada pesanan yang dipilih) */}
      {selectedBookingIds.length > 0 && (
        <div className="p-3.5 bg-gradient-to-r from-rose-950/70 via-indigo-950/60 to-slate-900 border border-rose-500/40 rounded-2xl flex flex-wrap items-center justify-between gap-3 shadow-lg shadow-rose-950/30">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-rose-600/20 text-rose-400 border border-rose-500/30 rounded-xl">
              <CheckSquare className="w-5 h-5" />
            </div>
            <div>
              <p className="text-sm font-bold text-white">
                <span className="text-rose-400 font-extrabold">{selectedBookingIds.length}</span> Pesanan Terpilih
              </p>
              <p className="text-[11px] text-slate-400">
                Pilih aksi massal untuk menghapus atau mengelola pesanan yang ditandai
              </p>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <button
              onClick={() => handleToggleSelectAll(filteredBookings)}
              className="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white rounded-xl text-xs font-semibold border border-slate-700 transition-colors"
            >
              {selectedBookingIds.length === filteredBookings.length ? 'Batalkan Semua' : `Pilih Semua (${filteredBookings.length})`}
            </button>
            <button
              onClick={() => setSelectedBookingIds([])}
              className="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white rounded-xl text-xs font-semibold border border-slate-700 transition-colors"
            >
              Kosongkan Pilihan
            </button>
            <button
              onClick={() => setIsBulkDeleteModalOpen(true)}
              className="px-4 py-2 bg-rose-600 hover:bg-rose-500 text-white rounded-xl text-xs font-bold flex items-center gap-2 shadow-lg shadow-rose-600/30 transition-all active:scale-95"
            >
              <Trash2 className="w-4 h-4" />
              <span>Hapus {selectedBookingIds.length} Terpilih</span>
            </button>
          </div>
        </div>
      )}

      {/* Table Pesanan & Order */}
      <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl overflow-hidden backdrop-blur-md">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-800 text-slate-400 uppercase tracking-wider font-semibold bg-slate-900/60">
                <th className="py-3.5 px-4 w-10 text-center">
                  <input
                    type="checkbox"
                    title="Pilih Semua di Tampilan Ini"
                    checked={filteredBookings.length > 0 && selectedBookingIds.length === filteredBookings.length}
                    onChange={() => handleToggleSelectAll(filteredBookings)}
                    className="rounded border-slate-700 bg-slate-800 text-indigo-600 focus:ring-indigo-500 w-4 h-4 cursor-pointer"
                  />
                </th>
                <th className="py-3.5 px-4">Booking ID</th>
                <th className="py-3.5 px-4">Client Pemesan</th>
                <th className="py-3.5 px-4">Mitra / Driver</th>
                <th className="py-3.5 px-4">Rute Lokasi</th>
                <th className="py-3.5 px-4">Harga & Status DP</th>
                <th className="py-3.5 px-4">Status Pesanan</th>
                <th className="py-3.5 px-4 text-right">Aksi Admin</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 text-slate-300">
              {loading ? (
                <tr>
                  <td colSpan={8} className="py-8 text-center text-slate-500">
                    Memuat daftar pesanan...
                  </td>
                </tr>
              ) : filteredBookings.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-8 text-center text-slate-500">
                    Tidak ada transaksi pemesanan ditemukan.
                  </td>
                </tr>
              ) : (
                filteredBookings.map((b) => {
                  const dpValue = b.dp_amount || (parseFloat(b.total_price || 0) * 0.3);
                  const isSelected = selectedBookingIds.includes(b.id);

                  return (
                    <tr key={b.id} className={`hover:bg-slate-800/40 transition-colors ${isSelected ? 'bg-indigo-950/25 border-l-2 border-l-indigo-500' : ''}`}>
                      {/* Selection Checkbox */}
                      <td className="py-4 px-4 text-center">
                        <input
                          type="checkbox"
                          checked={isSelected}
                          onChange={() => handleToggleSelectOne(b.id)}
                          className="rounded border-slate-700 bg-slate-800 text-indigo-600 focus:ring-indigo-500 w-4 h-4 cursor-pointer"
                        />
                      </td>

                      {/* ID */}
                      <td className="py-4 px-4 font-mono font-bold text-indigo-400">
                        {b.id}
                        <div className="text-[10px] text-slate-500 font-normal mt-0.5">
                          {b.created_at ? new Date(b.created_at).toLocaleDateString('id-ID') : 'Baru'}
                        </div>
                      </td>

                      {/* Client */}
                      <td className="py-4 px-4">
                        <p className="font-bold text-white text-xs">{b.users?.full_name || b.client_name || 'Client'}</p>
                        <p className="text-[10px] text-slate-400">{b.users?.phone || '-'}</p>
                      </td>

                      {/* Driver */}
                      <td className="py-4 px-4">
                        {b.drivers?.users?.full_name || b.driver_name ? (
                          <div>
                            <p className="font-semibold text-slate-200">{b.drivers?.users?.full_name || b.driver_name}</p>
                            <p className="text-[10px] text-slate-400">{b.drivers?.vehicle_type || 'Driver Direct'}</p>
                          </div>
                        ) : (
                          <span className="text-amber-400 italic">Mencari Driver</span>
                        )}
                      </td>

                      {/* Rute */}
                      <td className="py-4 px-4 max-w-xs space-y-1">
                        <div className="flex items-center gap-1.5 text-emerald-400">
                          <MapPin className="w-3.5 h-3.5 shrink-0" />
                          <span className="truncate">{b.pickup_location || 'Jemput'}</span>
                        </div>
                        <div className="flex items-center gap-1.5 text-rose-400">
                          <MapPin className="w-3.5 h-3.5 shrink-0" />
                          <span className="truncate">{b.dropoff_location || 'Tujuan'}</span>
                        </div>
                      </td>

                      {/* Harga & Status DP */}
                      <td className="py-4 px-4 font-mono">
                        <div className="font-bold text-white text-xs">
                          Rp {parseFloat(b.total_price || 0).toLocaleString('id-ID')}
                        </div>
                        <div className="text-[10px] text-indigo-400 font-semibold mt-0.5 flex items-center gap-1">
                          <ShieldCheck className="w-3 h-3 text-indigo-400" />
                          <span>DP 30%: Rp {dpValue.toLocaleString('id-ID')}</span>
                        </div>
                      </td>

                      {/* Status Pesanan */}
                      <td className="py-4 px-4">
                        {b.status === 'completed' && <Badge variant="success">Selesai</Badge>}
                        {b.status === 'ongoing' && <Badge variant="indigo">Berjalan</Badge>}
                        {b.status === 'pending' && <Badge variant="warning">Menunggu DP</Badge>}
                        {b.status === 'cancelled' && <Badge variant="danger">Batal (DP Hangus)</Badge>}
                      </td>

                      {/* Action */}
                      <td className="py-4 px-4 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          {/* Cross-Link Keuangan Button */}
                          <button
                            onClick={() => setFinanceModalBooking(b)}
                            className="px-2.5 py-1.5 bg-indigo-500/20 hover:bg-indigo-500/30 text-indigo-400 border border-indigo-500/30 rounded-lg text-xs font-semibold flex items-center gap-1 transition-all"
                            title="Lihat Rincian Status DP & Keuangan"
                          >
                            <CreditCard className="w-3.5 h-3.5" />
                            <span>Status DP</span>
                          </button>

                          <button
                            onClick={() => setSelectedBooking(b)}
                            className="px-2.5 py-1.5 bg-slate-800 hover:bg-slate-700 border border-slate-700 rounded-lg text-slate-300 font-semibold text-xs transition-colors"
                          >
                            Kontrol
                          </button>

                          <button
                            onClick={() => handleEditOpen(b)}
                            className="p-1.5 bg-slate-800 hover:bg-slate-700 border border-slate-700 rounded-lg text-indigo-400 transition-colors"
                          >
                            <Edit2 className="w-3.5 h-3.5" />
                          </button>

                          <button
                            onClick={() => handleDeleteClick(b)}
                            title="Hapus Pesanan (Ketat)"
                            className="p-1.5 bg-slate-800 hover:bg-rose-950/40 border border-slate-700 text-rose-400 rounded-lg transition-colors"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
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

      {/* MODAL DISPLAY STATUS KEUANGAN & DP UNTUK BOOKING */}
      {financeModalBooking && (
        <Modal
          isOpen={!!financeModalBooking}
          onClose={() => setFinanceModalBooking(null)}
          title={`Status Keuangan & Holding Escrow (${financeModalBooking.id})`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-4 bg-indigo-950/40 border border-indigo-500/30 rounded-xl space-y-2">
              <div className="flex justify-between items-center">
                <span className="font-bold text-white text-sm">{financeModalBooking.users?.full_name || financeModalBooking.client_name || 'Client Pemesan'}</span>
                <span className="font-mono text-indigo-400 font-bold">{financeModalBooking.id}</span>
              </div>
              <p className="text-slate-400 text-[11px]">
                Driver: <strong className="text-white">{financeModalBooking.drivers?.users?.full_name || financeModalBooking.driver_name || 'Mitra Direct'}</strong>
              </p>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="p-3 bg-slate-900 rounded-xl border border-slate-800 space-y-1">
                <span className="text-slate-400 text-[10px] block">Total Harga Pesanan</span>
                <span className="font-extrabold text-white text-sm font-mono">
                  Rp {parseFloat(financeModalBooking.total_price || 0).toLocaleString('id-ID')}
                </span>
              </div>

              <div className="p-3 bg-slate-900 rounded-xl border border-slate-800 space-y-1">
                <span className="text-slate-400 text-[10px] block">Tagihan DP (30%)</span>
                <span className="font-extrabold text-emerald-400 text-sm font-mono">
                  Rp {(financeModalBooking.dp_amount || (parseFloat(financeModalBooking.total_price || 0) * 0.3)).toLocaleString('id-ID')}
                </span>
              </div>
            </div>

            {/* STATUS DP HANGUS / NORMAL */}
            {financeModalBooking.status === 'cancelled' ? (
              <div className="p-3 bg-rose-500/10 border border-rose-500/30 rounded-xl space-y-1">
                <div className="font-bold text-rose-400 flex items-center gap-1.5">
                  <OctagonAlert className="w-4 h-4" />
                  <span>Pesanan Dibatalkan Sepihak (DP Hangus)</span>
                </div>
                <p className="text-[11px] text-slate-300">
                  Tagihan DP di Keuangan otomatis berstatus <b>Dibatalkan</b>. Buka menu Keuangan untuk mengeksekusi pembagian <b>50% Kompensasi Driver</b> & <b>50% Kas Platform</b>.
                </p>
              </div>
            ) : financeModalBooking.status === 'completed' ? (
              <div className="p-3 bg-emerald-500/10 border border-emerald-500/30 rounded-xl space-y-1">
                <div className="font-bold text-emerald-400 flex items-center gap-1.5">
                  <CheckCircle className="w-4 h-4" />
                  <span>Pesanan Selesai & Split Saldo</span>
                </div>
                <p className="text-[11px] text-slate-300">
                  Pelunasan telah masuk ke Keuangan. Revenue Split 80% telah masuk ke Saldo Siap Tarik Driver.
                </p>
              </div>
            ) : (
              <div className="p-3 bg-amber-500/10 border border-amber-500/30 rounded-xl space-y-1">
                <div className="font-bold text-amber-400 flex items-center gap-1.5">
                  <Clock className="w-4 h-4" />
                  <span>DP Dalam Antrean Verifikasi / Escrow</span>
                </div>
                <p className="text-[11px] text-slate-300">
                  DP pesanan ini sedang diverifikasi oleh admin di menu Keuangan (Tab DP & Escrow).
                </p>
              </div>
            )}

            <div className="pt-3 border-t border-slate-800 flex justify-end gap-2">
              <button
                onClick={() => setFinanceModalBooking(null)}
                className="px-4 py-2 bg-slate-800 text-slate-300 font-bold rounded-xl text-xs"
              >
                Tutup
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Modal Kontrol & Force Stop */}
      <Modal
        isOpen={!!selectedBooking && !isEditOpen}
        onClose={() => setSelectedBooking(null)}
        title="Kontrol Status & Force Stop Pesanan"
      >
        {selectedBooking && (
          <div className="space-y-4 text-xs">
            <div className="p-4 bg-slate-950 rounded-xl border border-slate-800 space-y-2">
              <div className="flex justify-between items-center">
                <span className="font-mono text-indigo-400 font-bold">ID: {selectedBooking.id}</span>
                <span className="text-slate-400">
                  Status: <strong className="text-white uppercase">{selectedBooking.status}</strong>
                </span>
              </div>
              <div className="grid grid-cols-2 gap-2 text-slate-300 pt-2 border-t border-slate-800">
                <div>
                  <span className="text-slate-500 block">Client Pemesan:</span>
                  <span className="font-bold text-white">{selectedBooking.users?.full_name || selectedBooking.client_name || 'Client'}</span>
                </div>
                <div>
                  <span className="text-slate-500 block">Mitra Terpilih:</span>
                  <span className="font-bold text-white">{selectedBooking.drivers?.users?.full_name || selectedBooking.driver_name || 'Belum Ada'}</span>
                </div>
              </div>
            </div>

            <div className="pt-4 border-t border-slate-800 space-y-3">
              <span className="block text-slate-400 font-semibold">Ubah Status Langsung (Otomatis Sync Keuangan):</span>
              <div className="flex flex-wrap gap-2">
                <button
                  onClick={() => handleUpdateStatus(selectedBooking.id, 'completed')}
                  className="px-3.5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg flex items-center gap-1.5"
                >
                  <CheckCircle className="w-4 h-4" />
                  <span>Selesai (Completed)</span>
                </button>

                <button
                  onClick={() => handleUpdateStatus(selectedBooking.id, 'ongoing')}
                  className="px-3.5 py-2 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-lg"
                >
                  Berjalan (Ongoing)
                </button>

                <button
                  onClick={() => handleUpdateStatus(selectedBooking.id, 'cancelled')}
                  className="px-3.5 py-2 bg-rose-600 hover:bg-rose-500 text-white font-bold rounded-lg flex items-center gap-1.5 shadow-lg shadow-rose-600/30"
                >
                  <OctagonAlert className="w-4 h-4" />
                  <span>BATALKAN PESANAN (FORCE STOP)</span>
                </button>
              </div>
            </div>

            <div className="pt-3 border-t border-slate-800/80 flex justify-between items-center">
              <button
                type="button"
                onClick={() => {
                  const b = selectedBooking;
                  setSelectedBooking(null);
                  handleDeleteClick(b);
                }}
                className="text-rose-400 hover:text-rose-300 font-bold flex items-center gap-1.5 hover:underline py-1 text-xs"
              >
                <Trash2 className="w-3.5 h-3.5" />
                <span>Hapus Pesanan Ini Secara Permanen...</span>
              </button>
            </div>
          </div>
        )}
      </Modal>

      {/* Modal Create */}
      <Modal
        isOpen={isCreateOpen}
        onClose={() => setIsCreateOpen(false)}
        title="Buat Pesanan Baru oleh Admin"
      >
        <form onSubmit={handleCreate} className="space-y-4 text-xs">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-slate-400 mb-1 font-semibold">Nama Client Pemesan</label>
              <input
                type="text"
                required
                value={formData.client_name}
                onChange={(e) => setFormData({ ...formData, client_name: e.target.value })}
                className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-lg text-white"
                placeholder="Contoh: Budi Santoso"
              />
            </div>
            <div>
              <label className="block text-slate-400 mb-1 font-semibold">Nama Driver / Partner</label>
              <input
                type="text"
                value={formData.driver_name}
                onChange={(e) => setFormData({ ...formData, driver_name: e.target.value })}
                className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-lg text-white"
                placeholder="Contoh: Rian Pratama"
              />
            </div>
          </div>

          <div>
            <label className="block text-slate-400 mb-1 font-semibold">Lokasi Penjemputan</label>
            <input
              type="text"
              required
              value={formData.pickup_location}
              onChange={(e) => setFormData({ ...formData, pickup_location: e.target.value })}
              className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-lg text-white"
              placeholder="Contoh: Mall Grand Indonesia"
            />
          </div>

          <div>
            <label className="block text-slate-400 mb-1 font-semibold">Lokasi Tujuan</label>
            <input
              type="text"
              required
              value={formData.dropoff_location}
              onChange={(e) => setFormData({ ...formData, dropoff_location: e.target.value })}
              className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-lg text-white"
              placeholder="Contoh: Senayan City"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-slate-400 mb-1 font-semibold">Total Harga Pesanan (Rp)</label>
              <input
                type="number"
                required
                value={formData.total_price}
                onChange={(e) => setFormData({ ...formData, total_price: e.target.value })}
                className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-lg text-white font-mono"
                placeholder="300000"
              />
              <span className="text-[10px] text-emerald-400 mt-1 block">Otomatis DP 30% = Rp {((parseFloat(formData.total_price || 0) * 0.3)).toLocaleString('id-ID')}</span>
            </div>
            <div>
              <label className="block text-slate-400 mb-1 font-semibold">Durasi (Menit)</label>
              <input
                type="number"
                value={formData.duration}
                onChange={(e) => setFormData({ ...formData, duration: e.target.value })}
                className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-lg text-white"
                placeholder="60"
              />
            </div>
          </div>

          <div className="pt-3 flex justify-end gap-2">
            <button
              type="button"
              onClick={() => setIsCreateOpen(false)}
              className="px-4 py-2 bg-slate-800 text-slate-300 rounded-lg font-bold"
            >
              Batal
            </button>
            <button
              type="submit"
              className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg font-bold shadow-lg shadow-indigo-600/20"
            >
              Simpan & Sync Keuangan
            </button>
          </div>
        </form>
      </Modal>

      {/* Modal Edit */}
      <Modal
        isOpen={isEditOpen}
        onClose={() => setIsEditOpen(false)}
        title="Edit Data Pesanan"
      >
        <form onSubmit={handleEditSubmit} className="space-y-4 text-xs">
          <div>
            <label className="block text-slate-400 mb-1 font-semibold">Lokasi Penjemputan</label>
            <input
              type="text"
              required
              value={formData.pickup_location}
              onChange={(e) => setFormData({ ...formData, pickup_location: e.target.value })}
              className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-lg text-white"
            />
          </div>
          <div>
            <label className="block text-slate-400 mb-1 font-semibold">Lokasi Tujuan</label>
            <input
              type="text"
              required
              value={formData.dropoff_location}
              onChange={(e) => setFormData({ ...formData, dropoff_location: e.target.value })}
              className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-lg text-white"
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-slate-400 mb-1 font-semibold">Total Harga (Rp)</label>
              <input
                type="number"
                required
                value={formData.total_price}
                onChange={(e) => setFormData({ ...formData, total_price: e.target.value })}
                className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-lg text-white"
              />
            </div>
            <div>
              <label className="block text-slate-400 mb-1 font-semibold">Durasi (Menit)</label>
              <input
                type="number"
                value={formData.duration}
                onChange={(e) => setFormData({ ...formData, duration: e.target.value })}
                className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-lg text-white"
              />
            </div>
          </div>
          <div className="pt-3 flex justify-end gap-2">
            <button
              type="button"
              onClick={() => setIsEditOpen(false)}
              className="px-4 py-2 bg-slate-800 text-slate-300 rounded-lg font-bold"
            >
              Batal
            </button>
            <button
              type="submit"
              className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg font-bold"
            >
              Update Pesanan
            </button>
          </div>
        </form>
      </Modal>

      {/* MODAL HAPUS PESANAN SECARA KETAT & PERMANEN */}
      {deleteModalBooking && (
        <Modal
          isOpen={!!deleteModalBooking}
          onClose={() => { if (!isDeleting) setDeleteModalBooking(null); }}
          title="Konfirmasi Penghapusan Pesanan (Ketat)"
        >
          <div className="space-y-4 text-xs text-slate-300">
            {/* Danger warning box */}
            <div className="p-3.5 bg-rose-950/40 border border-rose-500/50 rounded-xl text-rose-200 flex items-start gap-3">
              <OctagonAlert className="w-5 h-5 text-rose-400 shrink-0 mt-0.5" />
              <div className="space-y-1">
                <p className="font-extrabold text-sm text-rose-300">PERINGATAN: Tindakan Ini Bersifat Permanen!</p>
                <p className="text-slate-300 leading-relaxed text-xs">
                  Menghapus pesanan secara permanen akan membatalkan jadwal driver, menghapus data order, dan secara default akan <span className="font-bold text-rose-400">membersihkan riwayat Down Payment (DP) serta transaksi terkait di sistem Keuangan</span> agar tidak timbul data mengambang (orphan records).
                </p>
              </div>
            </div>

            {/* Booking details card */}
            <div className="p-3 bg-slate-900/80 border border-slate-700/80 rounded-xl space-y-2">
              <div className="flex justify-between items-center pb-2 border-b border-slate-800">
                <span className="text-slate-400 font-medium">ID Pesanan:</span>
                <span className="font-mono text-white font-bold">{deleteModalBooking.id}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-slate-400 font-medium">Client / Pemesan:</span>
                <span className="text-white font-bold">{deleteModalBooking.users?.full_name || deleteModalBooking.client_name || 'Client'}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-slate-400 font-medium">Mitra Driver:</span>
                <span className="text-indigo-400 font-bold">{deleteModalBooking.drivers?.users?.full_name || deleteModalBooking.driver_name || 'Belum ditugaskan'}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-slate-400 font-medium">Total Harga / DP:</span>
                <span className="text-emerald-400 font-bold">
                  Rp {Number(deleteModalBooking.total_price || 0).toLocaleString('id-ID')} / DP Rp {Number(deleteModalBooking.dp_amount || (deleteModalBooking.total_price * 0.3) || 0).toLocaleString('id-ID')}
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-slate-400 font-medium">Status DP Saat Ini:</span>
                <span className="font-mono font-bold text-amber-400">
                  {deleteModalBooking.dp_status || (deleteModalBooking.status === 'pending' ? 'PENDING' : 'HELD_IN_ESCROW')}
                </span>
              </div>
            </div>

            {/* Checkbox option for Finance Cleanup */}
            <label className="flex items-start gap-3 p-3 bg-slate-900 border border-slate-800 hover:border-slate-700 rounded-xl cursor-pointer transition-colors">
              <input 
                type="checkbox"
                checked={deleteFinanceChecked}
                onChange={(e) => setDeleteFinanceChecked(e.target.checked)}
                className="mt-0.5 rounded border-slate-700 bg-slate-800 text-rose-600 focus:ring-rose-500 w-4 h-4"
              />
              <div className="space-y-0.5">
                <span className="font-bold text-white block">Hapus seluruh riwayat tagihan & transaksi DP terkait di Modul Keuangan</span>
                <span className="text-[11px] text-slate-400 block">
                  {deleteFinanceChecked 
                    ? '✅ Seluruh data transaksi DP & pelunasan pesanan ini di halaman Keuangan akan langsung dihapus bersih.'
                    : '⚠️ Data tagihan DP akan tetap tersimpan sebagai catatan transaksi lama di modul Keuangan.'}
                </span>
              </div>
            </label>

            {/* Action Buttons */}
            <div className="pt-2 flex justify-end gap-2">
              <button
                type="button"
                disabled={isDeleting}
                onClick={() => setDeleteModalBooking(null)}
                className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg font-bold transition-colors"
              >
                Batal
              </button>
              <button
                type="button"
                disabled={isDeleting}
                onClick={handleConfirmDelete}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-500 text-white rounded-lg font-bold flex items-center gap-2 transition-all shadow-lg shadow-rose-600/30 active:scale-95"
              >
                {isDeleting ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin" />
                    <span>Menghapus...</span>
                  </>
                ) : (
                  <>
                    <Trash2 className="w-4 h-4" />
                    <span>Ya, Hapus Sekarang</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* MODAL HAPUS MASSAL PESANAN */}
      {isBulkDeleteModalOpen && (
        <Modal
          isOpen={isBulkDeleteModalOpen}
          onClose={() => { if (!isBulkDeleting) setIsBulkDeleteModalOpen(false); }}
          title={`Hapus ${selectedBookingIds.length} Pesanan Sekaligus`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            {/* Danger warning box */}
            <div className="p-3.5 bg-rose-950/40 border border-rose-500/50 rounded-xl text-rose-200 flex items-start gap-3">
              <OctagonAlert className="w-5 h-5 text-rose-400 shrink-0 mt-0.5" />
              <div className="space-y-1">
                <p className="font-extrabold text-sm text-rose-300">Konfirmasi Hapus Massal ({selectedBookingIds.length} Pesanan)</p>
                <p className="text-slate-300 leading-relaxed text-xs">
                  Tindakan ini akan menghapus permanen seluruh pesanan terpilih, membebaskan jadwal driver, dan membersihkan data obrolan terkait.
                </p>
              </div>
            </div>

            {/* Selected Bookings Summary */}
            <div className="p-3 bg-slate-900/80 border border-slate-700/80 rounded-xl space-y-2">
              <div className="flex justify-between items-center pb-2 border-b border-slate-800">
                <span className="text-slate-400 font-medium">Total Pesanan Terpilih:</span>
                <span className="font-mono text-white font-bold text-sm">{selectedBookingIds.length} Pesanan</span>
              </div>
              <div className="space-y-1">
                <span className="text-slate-400 font-medium block">Daftar ID:</span>
                <div className="flex flex-wrap gap-1 max-h-24 overflow-y-auto pr-1">
                  {selectedBookingIds.map((id) => (
                    <span key={id} className="font-mono text-[10px] bg-slate-800 text-indigo-300 px-2 py-0.5 rounded border border-slate-700">
                      {id.slice(0, 8)}...
                    </span>
                  ))}
                </div>
              </div>
            </div>

            {/* Checkbox option for Finance Cleanup */}
            <label className="flex items-start gap-3 p-3 bg-slate-900 border border-slate-800 hover:border-slate-700 rounded-xl cursor-pointer transition-colors">
              <input 
                type="checkbox"
                checked={bulkDeleteFinanceChecked}
                onChange={(e) => setBulkDeleteFinanceChecked(e.target.checked)}
                className="mt-0.5 rounded border-slate-700 bg-slate-800 text-rose-600 focus:ring-rose-500 w-4 h-4 cursor-pointer"
              />
              <div className="space-y-0.5">
                <span className="font-bold text-white block">Hapus seluruh riwayat tagihan & transaksi DP terkait di Modul Keuangan</span>
                <span className="text-[11px] text-slate-400 block">
                  {bulkDeleteFinanceChecked 
                    ? '✅ Seluruh data transaksi DP & pelunasan untuk pesanan yang dipilih akan langsung dibersihkan dari sistem Keuangan.'
                    : '⚠️ Data tagihan DP akan tetap tersimpan di modul Keuangan.'}
                </span>
              </div>
            </label>

            {/* Action Buttons */}
            <div className="pt-2 flex justify-end gap-2">
              <button
                type="button"
                disabled={isBulkDeleting}
                onClick={() => setIsBulkDeleteModalOpen(false)}
                className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg font-bold transition-colors"
              >
                Batal
              </button>
              <button
                type="button"
                disabled={isBulkDeleting}
                onClick={handleConfirmBulkDelete}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-500 text-white rounded-lg font-bold flex items-center gap-2 transition-all shadow-lg shadow-rose-600/30 active:scale-95"
              >
                {isBulkDeleting ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin" />
                    <span>Menghapus {selectedBookingIds.length} Pesanan...</span>
                  </>
                ) : (
                  <>
                    <Trash2 className="w-4 h-4" />
                    <span>Ya, Hapus {selectedBookingIds.length} Pesanan</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
};
