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

// Fallback Empty Data
let mockUsers = [];
let mockDrivers = [];
let mockBookings = [];
let mockPosts = [];
let mockEvents = [
  {
    id: 'ev-1',
    title: 'We The Fest 2026',
    date_string: '14-16 Ags 2026',
    location: 'GBK Sports Complex, Jaksel',
    image_url: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=600&auto=format&fit=crop',
    ticket_url: 'https://wethefest.com',
    category: 'Festival Musik',
    description: 'Festival musik musim panas terbesar di Jakarta dengan deretan artis lokal dan internasional terbaik.',
    is_active: true,
    created_at: new Date().toISOString()
  },
  {
    id: 'ev-2',
    title: 'Java Jazz Festival',
    date_string: '28-30 Nov 2026',
    location: 'JIExpo Kemayoran, Jakpus',
    image_url: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?q=80&w=600&auto=format&fit=crop',
    ticket_url: 'https://javajazzfestival.com',
    category: 'Konser Musik',
    description: 'Rasakan alunan jazz spektakuler dari musisi legendaris dalam dan luar negeri.',
    is_active: true,
    created_at: new Date().toISOString()
  },
  {
    id: 'ev-3',
    title: 'Indonesia Comic Con',
    date_string: '23-25 Des 2026',
    location: 'JCC Senayan, Jaksel',
    image_url: 'https://images.unsplash.com/photo-1563089145-599997674d42?q=80&w=600&auto=format&fit=crop',
    ticket_url: 'https://indonesiacomiccon.com',
    category: 'Pameran & Pop Culture',
    description: 'Ajang kumpul komunitas pecinta anime, cosplay, game, dan komik terbesar se-Indonesia.',
    is_active: true,
    created_at: new Date().toISOString()
  }
];

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
      const newB = { id: 'bk-' + Date.now(), ...data, created_at: new Date() };
      mockBookings.unshift(newB);
      return { success: true, message: 'Pesanan berhasil dibuat' };
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

  deleteBooking: async (id) => {
    try {
      const res = await client.delete(`/admin/bookings/${id}`);
      return res.data;
    } catch {
      mockBookings = mockBookings.filter(b => b.id !== id);
      return { success: true, message: 'Pesanan berhasil dihapus' };
    }
  },

  updateBookingStatus: async (id, status) => {
    try {
      const res = await client.put(`/admin/bookings/${id}/status`, { status });
      return res.data;
    } catch {
      mockBookings = mockBookings.map(b => b.id === id ? { ...b, status } : b);
      return { success: true, message: `Status booking diubah ke ${status}` };
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
  }
};
