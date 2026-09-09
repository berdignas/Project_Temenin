import React, { useState, useEffect } from 'react';
import { 
  Search, 
  PlusCircle, 
  Edit3, 
  Trash2, 
  Calendar, 
  MapPin, 
  ExternalLink, 
  Eye, 
  CheckCircle2, 
  XCircle, 
  Ticket, 
  Sparkles,
  Info
} from 'lucide-react';
import { Badge } from '../components/Badge';
import { Modal } from '../components/Modal';
import { adminApi } from '../services/api';

export const Events = () => {
  const [events, setEvents] = useState([]);
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState('');

  // Modals state
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [isPreviewOpen, setIsPreviewOpen] = useState(false);
  const [selectedEvent, setSelectedEvent] = useState(null);

  // Form State
  const defaultForm = {
    title: '',
    category: 'Konser Musik',
    date_string: '',
    location: '',
    image_url: '',
    ticket_url: '',
    description: '',
    is_active: true
  };
  const [formData, setFormData] = useState(defaultForm);

  const fetchEvents = async () => {
    setLoading(true);
    const data = await adminApi.getEvents();
    setEvents(data || []);
    setLoading(false);
  };

  useEffect(() => {
    fetchEvents();
  }, []);

  const handleOpenCreate = () => {
    setFormData(defaultForm);
    setIsCreateOpen(true);
  };

  const handleOpenEdit = (ev) => {
    setSelectedEvent(ev);
    setFormData({
      title: ev.title || '',
      category: ev.category || 'Konser Musik',
      date_string: ev.date_string || '',
      location: ev.location || '',
      image_url: ev.image_url || '',
      ticket_url: ev.ticket_url || '',
      description: ev.description || '',
      is_active: ev.is_active !== undefined ? ev.is_active : true
    });
    setIsEditOpen(true);
  };

  const handleOpenPreview = (ev) => {
    setSelectedEvent(ev);
    setIsPreviewOpen(true);
  };

  const handleCreateSubmit = async (e) => {
    e.preventDefault();
    const res = await adminApi.createEvent(formData);
    setMessage(res.message || 'Event berhasil ditambahkan');
    setIsCreateOpen(false);
    fetchEvents();
    setTimeout(() => setMessage(''), 3500);
  };

  const handleEditSubmit = async (e) => {
    e.preventDefault();
    if (!selectedEvent) return;
    const res = await adminApi.updateEvent(selectedEvent.id, formData);
    setMessage(res.message || 'Event berhasil diperbarui');
    setIsEditOpen(false);
    setSelectedEvent(null);
    fetchEvents();
    setTimeout(() => setMessage(''), 3500);
  };

  const handleDelete = async (id) => {
    if (window.confirm('Apakah Anda yakin ingin menghapus event ini dari daftar?')) {
      const res = await adminApi.deleteEvent(id);
      setMessage(res.message || 'Event berhasil dihapus');
      fetchEvents();
      setTimeout(() => setMessage(''), 3500);
    }
  };

  const handleToggleStatus = async (ev) => {
    const newStatus = !ev.is_active;
    await adminApi.updateEvent(ev.id, { is_active: newStatus });
    setMessage(`Event "${ev.title}" sekarang ${newStatus ? 'Aktif (Tampil)' : 'Dinonaktifkan'}`);
    fetchEvents();
    setTimeout(() => setMessage(''), 3500);
  };

  // Filter logic
  const filteredEvents = events.filter((ev) => {
    const matchSearch = 
      ev.title?.toLowerCase().includes(search.toLowerCase()) ||
      ev.location?.toLowerCase().includes(search.toLowerCase()) ||
      ev.category?.toLowerCase().includes(search.toLowerCase());
    
    if (filterStatus === 'active') return matchSearch && ev.is_active;
    if (filterStatus === 'inactive') return matchSearch && !ev.is_active;
    return matchSearch;
  });

  return (
    <div className="space-y-6">
      {/* Alert Banner */}
      {message && (
        <div className="p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-2xl text-sm font-semibold text-emerald-400 flex items-center gap-3 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 flex-shrink-0" />
          <span>{message}</span>
        </div>
      )}

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-2xl font-extrabold text-white tracking-tight">Manajemen Event & Konser</h2>
            <span className="px-2.5 py-0.5 text-xs font-bold bg-indigo-500/20 text-indigo-300 rounded-full border border-indigo-500/30">
              {events.length} Event
            </span>
          </div>
          <p className="text-sm text-slate-400 mt-1">
            Event populer ini akan muncul di Beranda aplikasi Client sebagai inspirasi order dan tujuan perjalanan
          </p>
        </div>

        <button
          onClick={handleOpenCreate}
          className="inline-flex items-center gap-2 px-4 py-2.5 bg-gradient-to-r from-pink-600 to-rose-600 hover:from-pink-500 hover:to-rose-500 text-white font-bold text-sm rounded-xl shadow-lg shadow-pink-600/20 transition-all duration-200 self-start sm:self-auto"
        >
          <PlusCircle className="w-4 h-4" />
          Tambah Event Baru
        </button>
      </div>

      {/* Filter & Search Bar */}
      <div className="bg-slate-900 border border-slate-800 rounded-2xl p-4 flex flex-col md:flex-row gap-4 justify-between items-center">
        {/* Search */}
        <div className="relative w-full md:w-96">
          <Search className="w-4 h-4 text-slate-500 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Cari nama event, lokasi, kategori..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white placeholder-slate-500 focus:outline-none focus:border-pink-500/50 transition-colors"
          />
        </div>

        {/* Filter Tab */}
        <div className="flex items-center gap-2 w-full md:w-auto">
          <span className="text-xs text-slate-400 font-semibold mr-1">Status:</span>
          {['all', 'active', 'inactive'].map((st) => (
            <button
              key={st}
              onClick={() => setFilterStatus(st)}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${
                filterStatus === st
                  ? 'bg-pink-600/20 text-pink-400 border border-pink-500/40'
                  : 'text-slate-400 hover:text-white bg-slate-800/40'
              }`}
            >
              {st === 'all' ? 'Semua' : st === 'active' ? 'Aktif' : 'Nonaktif'}
            </button>
          ))}
        </div>
      </div>

      {/* Events Grid */}
      {loading ? (
        <div className="text-center py-20">
          <div className="w-10 h-10 border-2 border-pink-500 border-t-transparent rounded-full animate-spin mx-auto mb-3"></div>
          <p className="text-sm text-slate-400">Memuat daftar event...</p>
        </div>
      ) : filteredEvents.length === 0 ? (
        <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-12 text-center">
          <Ticket className="w-12 h-12 text-slate-600 mx-auto mb-3" />
          <h3 className="text-base font-bold text-white">Belum Ada Event</h3>
          <p className="text-xs text-slate-400 max-w-sm mx-auto mt-1 mb-5">
            {search ? 'Tidak ada event yang cocok dengan kata kunci pencarian.' : 'Mulai tambahkan event seru untuk memicu client memesan layanan Temenin Ajaa.'}
          </p>
          <button
            onClick={handleOpenCreate}
            className="px-4 py-2 bg-pink-600 hover:bg-pink-500 text-white font-bold text-xs rounded-xl"
          >
            Tambah Event Pertama
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredEvents.map((ev) => (
            <div
              key={ev.id}
              className="bg-slate-900 border border-slate-800 hover:border-slate-700 rounded-2xl overflow-hidden flex flex-col transition-all duration-200 group shadow-lg hover:shadow-slate-950/50"
            >
              {/* Event Image Banner */}
              <div className="relative h-44 bg-slate-950 overflow-hidden">
                <img
                  src={ev.image_url || 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=600&auto=format&fit=crop'}
                  alt={ev.title}
                  className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                  onError={(e) => {
                    e.target.src = 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=600&auto=format&fit=crop';
                  }}
                />
                <div className="absolute inset-0 bg-gradient-to-t from-slate-900 via-transparent to-black/40"></div>

                {/* Badges on Image */}
                <div className="absolute top-3 left-3 flex items-center gap-2">
                  <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-black/60 backdrop-blur-md text-pink-400 border border-pink-500/30">
                    {ev.category || 'Event'}
                  </span>
                </div>

                <div className="absolute top-3 right-3">
                  <button
                    onClick={() => handleToggleStatus(ev)}
                    title="Klik untuk ubah status aktif/nonaktif"
                    className={`px-2.5 py-1 rounded-full text-[10px] font-extrabold backdrop-blur-md border transition-all ${
                      ev.is_active
                        ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/40'
                        : 'bg-rose-500/20 text-rose-400 border-rose-500/40'
                    }`}
                  >
                    {ev.is_active ? '● AKTIF' : '○ NONAKTIF'}
                  </button>
                </div>

                {/* Date Tag */}
                <div className="absolute bottom-3 left-3 flex items-center gap-1.5 text-xs font-bold text-white bg-slate-900/80 px-2.5 py-1 rounded-lg backdrop-blur-md border border-slate-700/50">
                  <Calendar className="w-3.5 h-3.5 text-pink-400" />
                  <span>{ev.date_string}</span>
                </div>
              </div>

              {/* Event Body */}
              <div className="p-5 flex-1 flex flex-col justify-between space-y-4">
                <div className="space-y-2">
                  <h3 className="text-lg font-extrabold text-white group-hover:text-pink-400 transition-colors line-clamp-1">
                    {ev.title}
                  </h3>

                  <div className="flex items-start gap-1.5 text-xs text-slate-400">
                    <MapPin className="w-3.5 h-3.5 text-rose-400 flex-shrink-0 mt-0.5" />
                    <span className="line-clamp-1">{ev.location}</span>
                  </div>

                  <p className="text-xs text-slate-400 line-clamp-2 leading-relaxed">
                    {ev.description || 'Tidak ada deskripsi detail.'}
                  </p>
                </div>

                {/* Ticket Link info */}
                {ev.ticket_url && (
                  <div className="p-2.5 rounded-xl bg-slate-950 border border-slate-800/80 flex items-center justify-between text-xs">
                    <div className="flex items-center gap-2 truncate">
                      <Ticket className="w-3.5 h-3.5 text-pink-400 flex-shrink-0" />
                      <span className="text-slate-300 truncate">Link Tiket Resmi Tersedia</span>
                    </div>
                    <a
                      href={ev.ticket_url}
                      target="_blank"
                      rel="noreferrer"
                      className="text-pink-400 hover:text-pink-300 font-semibold inline-flex items-center gap-1 flex-shrink-0"
                    >
                      Buka <ExternalLink className="w-3 h-3" />
                    </a>
                  </div>
                )}

                {/* Card Action Buttons */}
                <div className="pt-2 border-t border-slate-800 flex items-center justify-between gap-2">
                  <button
                    onClick={() => handleOpenPreview(ev)}
                    className="flex-1 py-2 px-3 bg-slate-800 hover:bg-slate-700/80 text-white rounded-xl text-xs font-bold inline-flex items-center justify-center gap-1.5 transition-colors"
                  >
                    <Eye className="w-3.5 h-3.5 text-indigo-400" />
                    Detail
                  </button>
                  <button
                    onClick={() => handleOpenEdit(ev)}
                    className="p-2 bg-slate-800 hover:bg-slate-700/80 text-slate-300 hover:text-white rounded-xl text-xs transition-colors"
                    title="Edit Event"
                  >
                    <Edit3 className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => handleDelete(ev.id)}
                    className="p-2 bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 rounded-xl text-xs transition-colors"
                    title="Hapus Event"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* ======================================================== */}
      {/* MODAL: TAMBAH / EDIT EVENT */}
      {/* ======================================================== */}
      <Modal
        isOpen={isCreateOpen || isEditOpen}
        onClose={() => {
          setIsCreateOpen(false);
          setIsEditOpen(false);
          setSelectedEvent(null);
        }}
        title={isEditOpen ? 'Edit Data Event' : 'Tambah Event Baru'}
        maxWidth="max-w-2xl"
      >
        <form onSubmit={isEditOpen ? handleEditSubmit : handleCreateSubmit} className="space-y-4">
          {/* Judul & Kategori */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                Nama / Judul Event *
              </label>
              <input
                type="text"
                required
                placeholder="Contoh: Java Jazz Festival 2026"
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:outline-none focus:border-pink-500/50"
              />
            </div>
            <div>
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                Kategori Acara
              </label>
              <select
                value={formData.category}
                onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:outline-none focus:border-pink-500/50"
              >
                <option value="Konser Musik">Konser Musik</option>
                <option value="Festival Musik">Festival Musik</option>
                <option value="Pameran & Komik">Pameran & Komik</option>
                <option value="Olahraga & Pertandingan">Olahraga & Pertandingan</option>
                <option value="Wisata & Kuliner">Wisata & Kuliner</option>
                <option value="Komunitas & Gathering">Komunitas & Gathering</option>
              </select>
            </div>
          </div>

          {/* Tanggal & Lokasi */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                Tanggal / Periode Acara *
              </label>
              <input
                type="text"
                required
                placeholder="Contoh: 14 - 16 Ags 2026"
                value={formData.date_string}
                onChange={(e) => setFormData({ ...formData, date_string: e.target.value })}
                className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:outline-none focus:border-pink-500/50"
              />
            </div>
            <div>
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                Lokasi / Venue *
              </label>
              <input
                type="text"
                required
                placeholder="Contoh: GBK Sports Complex, Jaksel"
                value={formData.location}
                onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:outline-none focus:border-pink-500/50"
              />
            </div>
          </div>

          {/* URL Gambar & Live Preview */}
          <div>
            <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
              URL Poster / Gambar Event *
            </label>
            <input
              type="url"
              required
              placeholder="https://images.unsplash.com/..."
              value={formData.image_url}
              onChange={(e) => setFormData({ ...formData, image_url: e.target.value })}
              className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:outline-none focus:border-pink-500/50"
            />
            {formData.image_url && (
              <div className="mt-2.5 relative h-32 w-full rounded-xl overflow-hidden border border-slate-800 bg-slate-950">
                <img
                  src={formData.image_url}
                  alt="Preview"
                  className="w-full h-full object-cover"
                  onError={(e) => {
                    e.target.style.display = 'none';
                  }}
                />
              </div>
            )}
          </div>

          {/* Link Pembelian Tiket */}
          <div>
            <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
              Link Beli Tiket Resmi (Opsional)
            </label>
            <input
              type="url"
              placeholder="https://loket.com/event/... atau web promotor"
              value={formData.ticket_url}
              onChange={(e) => setFormData({ ...formData, ticket_url: e.target.value })}
              className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:outline-none focus:border-pink-500/50"
            />
            <p className="text-[11px] text-slate-500 mt-1">
              Link ini akan dibuka ketika user mengetuk tombol "Beli Tiket Resmi" di aplikasi Client.
            </p>
          </div>

          {/* Deskripsi */}
          <div>
            <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
              Deskripsi Lengkap & Panduan Acara *
            </label>
            <textarea
              required
              rows={4}
              placeholder="Jelaskan daya tarik acara, lineup bintang tamu, dan panduan untuk pengunjung..."
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white focus:outline-none focus:border-pink-500/50 resize-none"
            />
          </div>

          {/* Status Aktif Switch */}
          <div className="flex items-center gap-3 p-3 bg-slate-950 rounded-xl border border-slate-800">
            <input
              type="checkbox"
              id="isActive"
              checked={formData.is_active}
              onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
              className="w-4 h-4 rounded text-pink-600 focus:ring-pink-500"
            />
            <label htmlFor="isActive" className="text-xs font-bold text-white cursor-pointer select-none">
              Tampilkan langsung di Beranda Aplikasi Client (Status Aktif)
            </label>
          </div>

          {/* Submit Actions */}
          <div className="pt-4 border-t border-slate-800 flex justify-end gap-3">
            <button
              type="button"
              onClick={() => {
                setIsCreateOpen(false);
                setIsEditOpen(false);
              }}
              className="px-4 py-2.5 text-xs font-bold text-slate-400 hover:text-white rounded-xl"
            >
              Batal
            </button>
            <button
              type="submit"
              className="px-5 py-2.5 bg-gradient-to-r from-pink-600 to-rose-600 hover:from-pink-500 hover:to-rose-500 text-white text-xs font-bold rounded-xl shadow-lg shadow-pink-600/20"
            >
              {isEditOpen ? 'Simpan Perubahan' : 'Terbitkan Event'}
            </button>
          </div>
        </form>
      </Modal>

      {/* ======================================================== */}
      {/* MODAL: PREVIEW DETAIL EVENT (SESUAI LOGIKA DETAIL LENGKAP) */}
      {/* ======================================================== */}
      <Modal
        isOpen={isPreviewOpen && selectedEvent !== null}
        onClose={() => {
          setIsPreviewOpen(false);
          setSelectedEvent(null);
        }}
        title="Detail & Pratinjau Event"
        maxWidth="max-w-2xl"
      >
        {selectedEvent && (
          <div className="space-y-5">
            {/* Banner Preview */}
            <div className="relative h-56 rounded-2xl overflow-hidden border border-slate-800 bg-slate-950">
              <img
                src={selectedEvent.image_url || 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=600&auto=format&fit=crop'}
                alt={selectedEvent.title}
                className="w-full h-full object-cover"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-slate-950 via-transparent to-black/30"></div>
              <div className="absolute top-3 left-3">
                <span className="px-3 py-1 rounded-full text-xs font-bold bg-black/60 backdrop-blur-md text-pink-400 border border-pink-500/40">
                  {selectedEvent.category || 'Event'}
                </span>
              </div>
              <div className="absolute top-3 right-3">
                <span className={`px-3 py-1 rounded-full text-xs font-extrabold backdrop-blur-md border ${
                  selectedEvent.is_active
                    ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/40'
                    : 'bg-rose-500/20 text-rose-400 border-rose-500/40'
                }`}>
                  {selectedEvent.is_active ? 'TAMPIL DI APLIKASI' : 'DISEMBUNYIKAN'}
                </span>
              </div>
            </div>

            {/* Event Info */}
            <div className="space-y-2">
              <h3 className="text-xl font-extrabold text-white">{selectedEvent.title}</h3>
              <div className="flex flex-wrap items-center gap-4 text-xs text-slate-300">
                <span className="flex items-center gap-1.5 bg-slate-800/60 px-3 py-1.5 rounded-lg border border-slate-700/50">
                  <Calendar className="w-3.5 h-3.5 text-pink-400" />
                  {selectedEvent.date_string}
                </span>
                <span className="flex items-center gap-1.5 bg-slate-800/60 px-3 py-1.5 rounded-lg border border-slate-700/50">
                  <MapPin className="w-3.5 h-3.5 text-rose-400" />
                  {selectedEvent.location}
                </span>
              </div>
            </div>

            {/* Deskripsi */}
            <div className="p-4 bg-slate-950 rounded-2xl border border-slate-800/80 space-y-2">
              <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider">Deskripsi Acara:</h4>
              <p className="text-sm text-slate-300 leading-relaxed whitespace-pre-line">
                {selectedEvent.description || 'Tidak ada deskripsi.'}
              </p>
            </div>

            {/* Official Ticket Link Box */}
            {selectedEvent.ticket_url ? (
              <div className="p-4 bg-pink-500/5 rounded-2xl border border-pink-500/20 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div>
                  <h4 className="text-xs font-bold text-pink-400 flex items-center gap-1.5">
                    <Ticket className="w-4 h-4" />
                    Tautan Pembelian Tiket Resmi:
                  </h4>
                  <p className="text-xs text-slate-400 truncate max-w-md mt-0.5">{selectedEvent.ticket_url}</p>
                </div>
                <a
                  href={selectedEvent.ticket_url}
                  target="_blank"
                  rel="noreferrer"
                  className="px-3.5 py-2 bg-pink-600 hover:bg-pink-500 text-white rounded-xl text-xs font-bold inline-flex items-center gap-1.5 self-start sm:self-auto"
                >
                  Uji Buka Link <ExternalLink className="w-3.5 h-3.5" />
                </a>
              </div>
            ) : (
              <div className="p-3 bg-slate-950 rounded-xl border border-slate-800 text-xs text-slate-400 flex items-center gap-2">
                <Info className="w-4 h-4 text-slate-500" />
                <span>Link tiket resmi tidak diatur (Free Entry / Tiket di Lokasi).</span>
              </div>
            )}

            {/* Catatan Bisnis & Ketentuan Layanan */}
            <div className="p-4 bg-amber-500/10 border border-amber-500/20 rounded-2xl space-y-1.5">
              <h4 className="text-xs font-bold text-amber-400 flex items-center gap-1.5">
                <Sparkles className="w-3.5 h-3.5" />
                Aturan & Panduan Layanan Terhadap Event:
              </h4>
              <p className="text-xs text-slate-300 leading-relaxed">
                • <strong>Tanpa Diskon:</strong> Pemesanan ke event ini menggunakan tarif normal agar Temenin Ajaa tidak bakar uang.
              </p>
              <p className="text-xs text-slate-300 leading-relaxed">
                • <strong>Tiket Partner:</strong> Jika Client memesan layanan <em>Hangout Service</em> (masuk ke dalam event), tiket masuk Partner ditanggung oleh Client.
              </p>
              <p className="text-xs text-slate-300 leading-relaxed">
                • <strong>Freedom Request:</strong> Client dapat memesan bantuan antre tiket OTS melalui penawaran khusus di aplikasi.
              </p>
            </div>

            {/* Footer Modal */}
            <div className="pt-3 border-t border-slate-800 flex justify-end gap-2">
              <button
                onClick={() => {
                  setIsPreviewOpen(false);
                  handleOpenEdit(selectedEvent);
                }}
                className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-white text-xs font-bold rounded-xl inline-flex items-center gap-1.5"
              >
                <Edit3 className="w-3.5 h-3.5" /> Edit Event
              </button>
              <button
                onClick={() => setIsPreviewOpen(false)}
                className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-bold rounded-xl"
              >
                Tutup
              </button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};
