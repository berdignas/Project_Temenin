import React, { useState, useEffect } from 'react';
import { CalendarCheck, MapPin, Clock, DollarSign, RefreshCw, XCircle, CheckCircle, Plus, Edit2, Trash2, OctagonAlert } from 'lucide-react';
import { Badge } from '../components/Badge';
import { Modal } from '../components/Modal';
import { adminApi } from '../services/api';

export const Bookings = () => {
  const [bookings, setBookings] = useState([]);
  const [statusFilter, setStatusFilter] = useState('');
  const [loading, setLoading] = useState(true);
  const [selectedBooking, setSelectedBooking] = useState(null);
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [message, setMessage] = useState('');

  // Form state
  const [formData, setFormData] = useState({
    pickup_location: '',
    dropoff_location: '',
    total_price: '',
    duration: 60,
    status: 'pending'
  });

  const fetchBookings = async () => {
    setLoading(true);
    const data = await adminApi.getBookings(statusFilter);
    setBookings(data);
    setLoading(false);
  };

  useEffect(() => {
    fetchBookings();
  }, [statusFilter]);

  const handleUpdateStatus = async (id, status) => {
    const res = await adminApi.updateBookingStatus(id, status);
    setMessage(res.message);
    setSelectedBooking(null);
    fetchBookings();
    setTimeout(() => setMessage(''), 3000);
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    const res = await adminApi.createBooking(formData);
    setMessage(res.message);
    setIsCreateOpen(false);
    setFormData({ pickup_location: '', dropoff_location: '', total_price: '', duration: 60, status: 'pending' });
    fetchBookings();
    setTimeout(() => setMessage(''), 3000);
  };

  const handleEditOpen = (booking) => {
    setSelectedBooking(booking);
    setFormData({
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
    setTimeout(() => setMessage(''), 3000);
  };

  const handleDelete = async (id) => {
    if (window.confirm('Apakah Anda yakin ingin menghapus pesanan ini secara permanen?')) {
      const res = await adminApi.deleteBooking(id);
      setMessage(res.message);
      setSelectedBooking(null);
      fetchBookings();
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

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-extrabold text-white tracking-tight">Pemesanan & Order</h2>
          <p className="text-sm text-slate-400">CRUD Pemesanan & Kontrol Intervensi Darurat (Hentikan Pesanan)</p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={() => setIsCreateOpen(true)}
            className="px-4 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-bold flex items-center gap-2 transition-all shadow-lg shadow-indigo-600/20"
          >
            <Plus className="w-4 h-4" />
            <span>+ Buat Pesanan Baru</span>
          </button>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="px-3 py-2.5 bg-slate-800 border border-slate-700 rounded-xl text-xs text-white focus:outline-none focus:border-indigo-500"
          >
            <option value="">Semua Status Pesanan</option>
            <option value="pending">Pending (Mencari Driver)</option>
            <option value="ongoing">Ongoing (Sedang Berjalan)</option>
            <option value="completed">Completed (Selesai)</option>
            <option value="cancelled">Cancelled (Dibatalkan)</option>
          </select>
          <button
            onClick={fetchBookings}
            className="p-2.5 bg-slate-800 border border-slate-700 rounded-xl text-slate-300 hover:text-white"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Table */}
      <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl overflow-hidden backdrop-blur-md">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-800 text-slate-400 uppercase tracking-wider font-semibold bg-slate-900/50">
                <th className="py-3.5 px-4">Booking ID</th>
                <th className="py-3.5 px-4">Client / Pemesan</th>
                <th className="py-3.5 px-4">Driver / Mitra</th>
                <th className="py-3.5 px-4">Rute Penjemputan</th>
                <th className="py-3.5 px-4">Durasi & Harga</th>
                <th className="py-3.5 px-4">Status</th>
                <th className="py-3.5 px-4 text-right">Aksi CRUD & Kontrol</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 text-slate-300">
              {loading ? (
                <tr>
                  <td colSpan={7} className="py-8 text-center text-slate-500">
                    Memuat daftar pesanan...
                  </td>
                </tr>
              ) : bookings.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-8 text-center text-slate-500">
                    Tidak ada transaksi pemesanan.
                  </td>
                </tr>
              ) : (
                bookings.map((booking) => (
                  <tr key={booking.id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="py-4 px-4 font-mono font-bold text-indigo-400">
                      {booking.id}
                    </td>
                    <td className="py-4 px-4">
                      <p className="font-bold text-white text-sm">{booking.users?.full_name || 'Client'}</p>
                      <p className="text-[10px] text-slate-400">{booking.users?.phone || '-'}</p>
                    </td>
                    <td className="py-4 px-4">
                      {booking.drivers?.users?.full_name ? (
                        <div>
                          <p className="font-semibold text-slate-200">{booking.drivers.users.full_name}</p>
                          <p className="text-[10px] text-slate-400">{booking.drivers.vehicle_type} ({booking.drivers.plate_number})</p>
                        </div>
                      ) : (
                        <span className="text-amber-400 italic">Mencari Mitra</span>
                      )}
                    </td>
                    <td className="py-4 px-4 max-w-xs space-y-1">
                      <div className="flex items-center gap-1.5 text-emerald-400">
                        <MapPin className="w-3.5 h-3.5 shrink-0" />
                        <span className="truncate">{booking.pickup_location || 'Lokasi jemput'}</span>
                      </div>
                      <div className="flex items-center gap-1.5 text-rose-400">
                        <MapPin className="w-3.5 h-3.5 shrink-0" />
                        <span className="truncate">{booking.dropoff_location || 'Lokasi tujuan'}</span>
                      </div>
                    </td>
                    <td className="py-4 px-4">
                      <p className="font-bold text-white text-sm">
                        Rp {parseFloat(booking.total_price || 0).toLocaleString('id-ID')}
                      </p>
                      <p className="text-[10px] text-slate-400">{booking.duration || 60} Menit</p>
                    </td>
                    <td className="py-4 px-4">
                      {booking.status === 'completed' && <Badge variant="success">Selesai</Badge>}
                      {booking.status === 'ongoing' && <Badge variant="indigo">Berjalan</Badge>}
                      {booking.status === 'pending' && <Badge variant="warning">Mencari Driver</Badge>}
                      {booking.status === 'cancelled' && <Badge variant="danger">Batal</Badge>}
                    </td>
                    <td className="py-4 px-4 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          onClick={() => setSelectedBooking(booking)}
                          className="px-2.5 py-1.5 bg-slate-800 hover:bg-slate-700 border border-slate-700 rounded-lg text-slate-300 font-semibold transition-colors text-xs"
                          title="Detail & Force Stop"
                        >
                          Kontrol
                        </button>
                        <button
                          onClick={() => handleEditOpen(booking)}
                          className="p-1.5 bg-slate-800 hover:bg-slate-700 border border-slate-700 rounded-lg text-indigo-400 transition-colors"
                          title="Edit Pesanan"
                        >
                          <Edit2 className="w-3.5 h-3.5" />
                        </button>
                        <button
                          onClick={() => handleDelete(booking.id)}
                          className="p-1.5 bg-slate-800 hover:bg-rose-950/40 border border-slate-700 text-rose-400 rounded-lg transition-colors"
                          title="Hapus Pesanan"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
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

      {/* Modal Detail & Force Stop */}
      <Modal
        isOpen={!!selectedBooking && !isEditOpen}
        onClose={() => setSelectedBooking(null)}
        title="Kontrol Intervensi Status & Hentikan Pesanan"
      >
        {selectedBooking && (
          <div className="space-y-4 text-xs">
            <div className="p-4 bg-slate-950 rounded-xl border border-slate-800 space-y-2">
              <div className="flex justify-between items-center">
                <span className="font-mono text-indigo-400 font-bold">ID: {selectedBooking.id}</span>
                <span className="text-slate-400">
                  Tanggal: {new Date(selectedBooking.created_at || Date.now()).toLocaleDateString('id-ID')}
                </span>
              </div>
              <div className="grid grid-cols-2 gap-2 text-slate-300 pt-2 border-t border-slate-800">
                <div>
                  <span className="text-slate-500 block">Client Pemesan:</span>
                  <span className="font-bold text-white">{selectedBooking.users?.full_name || 'Client'}</span>
                  <span className="block text-[10px] text-slate-400">{selectedBooking.users?.phone || '-'}</span>
                </div>
                <div>
                  <span className="text-slate-500 block">Mitra Terpilih:</span>
                  <span className="font-bold text-white">{selectedBooking.drivers?.users?.full_name || 'Belum Ada Driver'}</span>
                </div>
              </div>
            </div>

            <div className="space-y-2 p-3 bg-slate-800/60 rounded-xl border border-slate-700">
              <span className="text-slate-400 block font-semibold">Detail Lokasi & Biaya</span>
              <p className="text-slate-300">Penjemputan: <strong className="text-white">{selectedBooking.pickup_location}</strong></p>
              <p className="text-slate-300">Tujuan: <strong className="text-white">{selectedBooking.dropoff_location}</strong></p>
              <p className="text-emerald-400 font-bold text-sm">Total Harga: Rp {parseFloat(selectedBooking.total_price || 0).toLocaleString('id-ID')}</p>
            </div>

            <div className="pt-4 border-t border-slate-800 space-y-3">
              <span className="block text-slate-400 font-semibold">Intervensi Langsung Admin:</span>
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
                  className="px-3.5 py-2 bg-rose-600 hover:bg-rose-500 text-white font-bold rounded-lg flex items-center gap-1.5 shadow-lg shadow-rose-600/30 animate-pulse"
                >
                  <OctagonAlert className="w-4 h-4" />
                  <span>HENTIKAN PESANAN (FORCE STOP)</span>
                </button>
              </div>
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
              <label className="block text-slate-400 mb-1 font-semibold">Total Harga (Rp)</label>
              <input
                type="number"
                required
                value={formData.total_price}
                onChange={(e) => setFormData({ ...formData, total_price: e.target.value })}
                className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-lg text-white"
                placeholder="50000"
              />
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
          <div>
            <label className="block text-slate-400 mb-1 font-semibold">Status Awal</label>
            <select
              value={formData.status}
              onChange={(e) => setFormData({ ...formData, status: e.target.value })}
              className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-lg text-white"
            >
              <option value="pending">Pending</option>
              <option value="ongoing">Ongoing</option>
              <option value="completed">Completed</option>
              <option value="cancelled">Cancelled</option>
            </select>
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
              className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg font-bold"
            >
              Simpan Pesanan
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
          <div>
            <label className="block text-slate-400 mb-1 font-semibold">Status Pesanan</label>
            <select
              value={formData.status}
              onChange={(e) => setFormData({ ...formData, status: e.target.value })}
              className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-lg text-white"
            >
              <option value="pending">Pending</option>
              <option value="ongoing">Ongoing</option>
              <option value="completed">Completed</option>
              <option value="cancelled">Cancelled</option>
            </select>
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
    </div>
  );
};
