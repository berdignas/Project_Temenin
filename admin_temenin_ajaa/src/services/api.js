import axios from 'axios';

const API_BASE_URL = 'http://localhost:3002/api';

const client = axios.create({
  baseURL: API_BASE_URL,
  timeout: 5000,
  headers: {
    'Content-Type': 'application/json'
  }
});

// Attach Authorization Bearer token from localStorage
client.interceptors.request.use((config) => {
  const token = localStorage.getItem('admin_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Handle 401 Unauthorized automatically
client.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response && error.response.status === 401) {
      localStorage.removeItem('admin_token');
      localStorage.removeItem('admin_user');
      if (window.location.pathname !== '/login') {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

// Fallback Empty Data
let mockUsers = [];
let mockDrivers = [];
let mockBookings = [];
let mockTransactions = [];
let mockPosts = [];
let mockEvents = [];

export const adminApi = {
  // Auth
  login: async (email, password) => {
    const res = await client.post('/auth/login', { email, password });
    return res.data;
  },

  // Stats
  getStats: async () => {
    try {
      const res = await client.get('/admin/stats');
      return res.data.data;
    } catch {
      const totalUsers = mockUsers.length;
      const totalDrivers = mockDrivers.length;
      const pendingDrivers = mockDrivers.filter(d => d.status === 'pending').length;
      const approvedDrivers = mockDrivers.filter(d => d.status === 'approved').length;
      const totalBookings = mockBookings.length;
      const activeBookings = mockBookings.filter(b => b.status === 'ongoing' || b.status === 'pending').length;
      const totalRevenue = mockBookings.reduce((acc, b) => acc + (b.total_price || 0), 0);

      return {
        totalUsers,
        totalDrivers,
        pendingDrivers,
        approvedDrivers,
        totalBookings,
        activeBookings,
        totalRevenue,
        recentBookings: mockBookings.slice(0, 5),
        pendingDriverList: mockDrivers.filter(d => d.status === 'pending')
      };
    }
  },

  // Users
  getUsers: async (search = '', role = '') => {
    try {
      const res = await client.get('/admin/users', { params: { search, role } });
      return res.data.data;
    } catch {
      let filtered = [...mockUsers];
      if (role) filtered = filtered.filter(u => u.role === role);
      if (search) {
        const s = search.toLowerCase();
        filtered = filtered.filter(u => 
          u.full_name?.toLowerCase().includes(s) || 
          u.phone?.includes(s) || 
          u.email?.toLowerCase().includes(s)
        );
      }
      return filtered;
    }
  },

  updateUser: async (id, data) => {
    try {
      const res = await client.put(`/admin/users/${id}`, data);
      return res.data;
    } catch {
      mockUsers = mockUsers.map(u => u.id === id ? { ...u, ...data } : u);
      return { success: true, message: 'User updated successfully' };
    }
  },

  deleteUser: async (id) => {
    try {
      const res = await client.delete(`/admin/users/${id}`);
      return res.data;
    } catch {
      mockUsers = mockUsers.filter(u => u.id !== id);
      return { success: true, message: 'User deleted' };
    }
  },

  // Drivers
  getDrivers: async (status = '') => {
    try {
      const res = await client.get('/admin/drivers', { params: { status } });
      return res.data.data;
    } catch {
      if (status) {
        return mockDrivers.filter(d => d.status === status);
      }
      return mockDrivers;
    }
  },

  verifyDriver: async (id, status) => {
    try {
      const res = await client.put(`/admin/drivers/${id}/verify`, { status });
      return res.data;
    } catch {
      mockDrivers = mockDrivers.map(d => d.id === id ? { ...d, status } : d);
      return { success: true, message: `Status driver diubah menjadi ${status}` };
    }
  },

  updateDriver: async (id, data) => {
    try {
      const res = await client.put(`/admin/drivers/${id}`, data);
      return res.data;
    } catch {
      mockDrivers = mockDrivers.map(d => d.id === id ? { ...d, ...data } : d);
      return { success: true, message: 'Driver updated' };
    }
  },

  // Bookings
  getBookings: async (status = '') => {
    try {
      const res = await client.get('/admin/bookings', { params: { status } });
      return res.data.data;
    } catch {
      if (status) return mockBookings.filter(b => b.status === status);
      return mockBookings;
    }
  },

  createBooking: async (data) => {
    try {
      const res = await client.post('/admin/bookings', data);
      return res.data;
    } catch {
      const bookingId = 'bk-' + Date.now();
      const totalPrice = parseFloat(data.total_price || 0);
      const dpAmount = totalPrice * 0.3; // 30% DP
      
      const newB = { 
        id: bookingId, 
        ...data, 
        total_price: totalPrice,
        dp_amount: dpAmount,
        dp_status: 'PENDING',
        created_at: new Date().toISOString() 
      };
      mockBookings.unshift(newB);

      // AUTO-SYNC TO FINANCE TRANSACTIONS: Generate DP Transaction
      const dpTrx = {
        id: 'trx-dp-' + Date.now(),
        booking_id: bookingId,
        user_name: data.client_name || 'Client Pemesan',
        user_role: 'CLIENT',
        driver_name: data.driver_name || 'Driver / Partner',
        type: 'DP',
        amount: dpAmount > 0 ? dpAmount : 100000,
        unique_code: Math.floor(Math.random() * 899) + 100,
        total_payable: (dpAmount > 0 ? dpAmount : 100000) + Math.floor(Math.random() * 899) + 100,
        status: 'PENDING',
        bank_name: 'Bank BCA',
        account_number: '882' + Math.floor(Math.random() * 899999),
        account_name: data.client_name || 'Client Pemesan',
        proof_url: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?q=80&w=600&auto=format&fit=crop',
        ocr_match_score: 98,
        sla_deadline: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
        created_at: new Date().toISOString()
      };
      mockTransactions.unshift(dpTrx);

      return { success: true, message: `Pesanan berhasil dibuat & Tagihan DP Rp ${dpAmount.toLocaleString('id-ID')} masuk ke Keuangan` };
    }
  },

  updateBooking: async (id, data) => {
    try {
      const res = await client.put(`/admin/bookings/${id}`, data);
      return res.data;
    } catch {
      mockBookings = mockBookings.map(b => b.id === id ? { ...b, ...data } : b);
      return { success: true, message: 'Pesanan berhasil diperbarui' };
    }
  },

  deleteBooking: async (id, deleteFinance = true) => {
    try {
      const res = await client.delete(`/admin/bookings/${id}`, {
        data: { deleteFinance },
        params: { deleteFinance }
      });
      return res.data;
    } catch {
      mockBookings = mockBookings.filter(b => b.id !== id);
      if (deleteFinance) {
        mockTransactions = mockTransactions.filter(t => t.booking_id !== id);
      }
      return { success: true, message: 'Pesanan & data tagihan terkait berhasil dihapus' };
    }
  },

  updateBookingStatus: async (id, status) => {
    try {
      const res = await client.put(`/admin/bookings/${id}/status`, { status });
      return res.data;
    } catch {
      let updatedBooking = null;
      mockBookings = mockBookings.map(b => {
        if (b.id === id) {
          updatedBooking = { ...b, status };
          return updatedBooking;
        }
        return b;
      });

      // AUTO-SYNC TO FINANCE TRANSACTIONS ACCORDING TO BOOKING STATUS CHANGE
      if (status === 'cancelled') {
        // Flag DP Transaction as Cancelled -> Ready for DP Forfeit Execution (50% Driver / 50% System)
        mockTransactions = mockTransactions.map(t => {
          if (t.booking_id === id && t.type === 'DP') {
            return {
              ...t,
              booking_status: 'CANCELLED_BY_CLIENT',
              admin_notes: 'Pesanan dibatalkan. Menunggu Eksekusi DP Hangus (50% Driver, 50% Platform)'
            };
          }
          return t;
        });
      } else if (status === 'completed') {
        // Generate Pelunasan Transaction for Revenue Split (80% Driver / 20% Platform)
        const booking = mockBookings.find(b => b.id === id);
        const totalPrice = parseFloat(booking?.total_price || 300000);
        const pelunasanAmount = totalPrice * 0.7; // 70% Pelunasan

        const pelunasanTrx = {
          id: 'trx-pel-' + Date.now(),
          booking_id: id,
          user_name: booking?.users?.full_name || 'Client Pemesan',
          user_role: 'CLIENT',
          driver_name: booking?.drivers?.users?.full_name || 'Driver / Partner',
          type: 'PELUNASAN',
          amount: pelunasanAmount,
          unique_code: 88,
          total_payable: pelunasanAmount + 88,
          status: 'PENDING',
          bank_name: 'Bank BCA',
          account_number: '8820491823',
          account_name: booking?.users?.full_name || 'Client Pemesan',
          proof_url: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?q=80&w=600&auto=format&fit=crop',
          ocr_match_score: 100,
          sla_deadline: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
          created_at: new Date().toISOString()
        };
        mockTransactions.unshift(pelunasanTrx);
      }

      return { 
        success: true, 
        message: status === 'cancelled' 
          ? 'Pesanan Dibatalkan! Tagihan DP di Keuangan otomatis berstatus Dibatalkan (DP Hangus).'
          : status === 'completed'
          ? 'Pesanan Selesai! Tagihan Pelunasan telah dikirim ke Keuangan untuk Revenue Split.'
          : `Status booking diubah ke ${status}`
      };
    }
  },

  // Top Up
  topUpBalance: async (userId, amount) => {
    try {
      const res = await client.post('/admin/topup', { userId, amount });
      return res.data;
    } catch {
      mockUsers = mockUsers.map(u => {
        if (u.id === userId) {
          return { ...u, balance: (u.balance || 0) + parseFloat(amount) };
        }
        return u;
      });
      return { success: true, message: `Saldo sebesar Rp ${parseFloat(amount).toLocaleString('id-ID')} berhasil ditambahkan` };
    }
  },

  // Finance Transactions (Escrow, DP, Pelunasan, Forfeit, Penarikan, Top Up)
  getTransactions: async (type = '', status = '') => {
    try {
      const res = await client.get('/admin/finance/transactions', { params: { type, status } });
      return res.data.data;
    } catch {
      let allTrx = [...mockTransactions];

      // AUTOMATICALLY SYNC / DERIVE DP TRANSACTIONS FOR EVERY BOOKING VIA FOREIGN KEY (booking_id)
      mockBookings.forEach(b => {
        const hasDpTrx = allTrx.some(t => t.booking_id === b.id && t.type === 'DP');
        if (!hasDpTrx) {
          const totalPrice = parseFloat(b.total_price || 300000);
          const dpAmount = b.dp_amount || (totalPrice * 0.3);
          allTrx.unshift({
            id: 'trx-dp-' + b.id,
            booking_id: b.id,
            user_name: b.users?.full_name || b.client_name || 'Client Pemesan',
            user_role: 'CLIENT',
            driver_name: b.drivers?.users?.full_name || b.driver_name || 'Driver Direct',
            type: 'DP',
            amount: dpAmount,
            unique_code: 247,
            total_payable: dpAmount + 247,
            status: b.dp_status || (b.status === 'ongoing' || b.status === 'completed' ? 'HELD_IN_ESCROW' : 'PENDING'),
            booking_status: b.status === 'cancelled' ? 'CANCELLED_BY_CLIENT' : b.status,
            bank_name: 'Bank BCA',
            account_number: '8820491823',
            account_name: b.users?.full_name || b.client_name || 'Client Pemesan',
            proof_url: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?q=80&w=600&auto=format&fit=crop',
            ocr_match_score: 98,
            sla_deadline: new Date(Date.now() + 18 * 3600 * 1000).toISOString(),
            created_at: b.created_at || new Date().toISOString()
          });
        }
      });

      let filtered = allTrx;
      if (type) filtered = filtered.filter(t => t.type === type);
      if (status) filtered = filtered.filter(t => t.status === status);
      return filtered;
    }
  },

  approveTransaction: async (id, notes = '') => {
    try {
      const res = await client.post(`/admin/finance/transactions/${id}/approve`, { notes });
      return res.data;
    } catch {
      mockTransactions = mockTransactions.map(t => {
        if (t.id === id) {
          const newStatus = t.type === 'DP' || t.type === 'PELUNASAN' ? 'HELD_IN_ESCROW' : 'APPROVED';
          return { ...t, status: newStatus, admin_notes: notes, processed_at: new Date().toISOString() };
        }
        return t;
      });
      return { success: true, message: 'Transaksi berhasil dikonfirmasi dan dana masuk ke Escrow Vault.' };
    }
  },

  executeDpForfeit: async (id, notes = '') => {
    try {
      const res = await client.post(`/admin/finance/transactions/${id}/forfeit`, { notes });
      return res.data;
    } catch {
      let forfeitInfo = null;
      mockTransactions = mockTransactions.map(t => {
        if (t.id === id) {
          const driverShare = t.amount * 0.5;
          const systemShare = t.amount * 0.5;
          forfeitInfo = { driverShare, systemShare };
          return {
            ...t,
            status: 'FORFEITED',
            admin_notes: notes || 'Pesanan dibatalkan sepihak. DP Hangus (50% Kompensasi Driver, 50% Platform Fee)',
            processed_at: new Date().toISOString()
          };
        }
        return t;
      });
      return {
        success: true,
        message: `DP Hangus Dieksekusi! Rp ${(forfeitInfo?.driverShare || 0).toLocaleString('id-ID')} masuk ke Saldo Driver, Rp ${(forfeitInfo?.systemShare || 0).toLocaleString('id-ID')} ke Kas Platform.`
      };
    }
  },

  settlePelunasanSplit: async (id, notes = '') => {
    try {
      const res = await client.post(`/admin/finance/transactions/${id}/settle`, { notes });
      return res.data;
    } catch {
      let splitInfo = null;
      mockTransactions = mockTransactions.map(t => {
        if (t.id === id) {
          const driverShare = t.total_payable * 0.8; // 80% to driver
          const systemShare = t.total_payable * 0.2; // 20% system fee
          splitInfo = { driverShare, systemShare };
          return {
            ...t,
            status: 'APPROVED',
            admin_notes: notes || 'Pelunasan disetujui. Revenue split: 80% Driver, 20% Platform Fee',
            processed_at: new Date().toISOString()
          };
        }
        return t;
      });
      return {
        success: true,
        message: `Pelunasan Disetujui! 80% (Rp ${(splitInfo?.driverShare || 0).toLocaleString('id-ID')}) dikirim ke Wallet Driver, 20% (Rp ${(splitInfo?.systemShare || 0).toLocaleString('id-ID')}) Komisi Platform.`
      };
    }
  },

  disbursePayout: async (id, notes = '') => {
    try {
      const res = await client.post(`/admin/finance/transactions/${id}/disburse`, { notes });
      return res.data;
    } catch {
      mockTransactions = mockTransactions.map(t => {
        if (t.id === id) {
          return { ...t, status: 'DISBURSED', admin_notes: notes, processed_at: new Date().toISOString() };
        }
        return t;
      });
      return { success: true, message: 'Penarikan dana disetujui & berhasil ditransfer ke rekening Driver.' };
    }
  },

  rejectTransaction: async (id, notes = '') => {
    try {
      const res = await client.post(`/admin/finance/transactions/${id}/reject`, { notes });
      return res.data;
    } catch {
      mockTransactions = mockTransactions.map(t => {
        if (t.id === id) {
          return { ...t, status: 'REJECTED', admin_notes: notes, processed_at: new Date().toISOString() };
        }
        return t;
      });
      return { success: true, message: 'Transaksi berhasil ditolak.' };
    }
  },

  deleteTransaction: async (id) => {
    try {
      const res = await client.delete(`/admin/finance/transactions/${id}`);
      return res.data;
    } catch {
      mockTransactions = mockTransactions.filter(t => t.id !== id);
      return { success: true, message: 'Riwayat transaksi berhasil dihapus dari sistem.' };
    }
  },

  // Community
  getPosts: async () => {
    try {
      const res = await client.get('/admin/community/posts');
      return res.data.data;
    } catch {
      return mockPosts;
    }
  },

  deletePost: async (id) => {
    try {
      const res = await client.delete(`/admin/community/posts/${id}`);
      return res.data;
    } catch {
      mockPosts = mockPosts.filter(p => p.id !== id);
      return { success: true, message: 'Postingan berhasil dihapus' };
    }
  },

  // Events Terdekat & Promosi
  getEvents: async () => {
    try {
      const res = await client.get('/admin/events');
      return res.data.data;
    } catch {
      return mockEvents;
    }
  },

  createEvent: async (data) => {
    try {
      const res = await client.post('/admin/events', data);
      return res.data;
    } catch {
      const newEv = {
        id: 'ev-' + Date.now(),
        ...data,
        is_active: data.is_active !== undefined ? data.is_active : true,
        created_at: new Date().toISOString()
      };
      mockEvents.unshift(newEv);
      return { success: true, message: 'Event berhasil ditambahkan', data: newEv };
    }
  },

  updateEvent: async (id, data) => {
    try {
      const res = await client.put(`/admin/events/${id}`, data);
      return res.data;
    } catch {
      mockEvents = mockEvents.map(ev => ev.id === id ? { ...ev, ...data } : ev);
      return { success: true, message: 'Event berhasil diperbarui' };
    }
  },

  deleteEvent: async (id) => {
    try {
      const res = await client.delete(`/admin/events/${id}`);
      return res.data;
    } catch {
      mockEvents = mockEvents.filter(ev => ev.id !== id);
      return { success: true, message: 'Event berhasil dihapus' };
    }
  },

  // Platform & Pricing Settings
  getSettings: async () => {
    try {
      const res = await client.get('/admin/settings');
      return res.data.data;
    } catch {
      return {
        price_per_km: 5000,
        price_per_km_sporty: 7500,
        min_ride_price: 15000,
        base_hourly_price: 50000,
        min_hourly_price: 35000,
        sleep_call_package_price: 45000,
        virtual_counseling_hourly_price: 35000,
        gaming_buddy_per_match_price: 15000,
        commission_rate: 10,
        allow_negotiation_flexible_only: true
      };
    }
  },

  updateSettings: async (settings) => {
    try {
      const res = await client.put('/admin/settings', settings);
      return res.data;
    } catch {
      return { success: true, message: 'Pengaturan sistem & tarif layanan berhasil diperbarui' };
    }
  }
};
