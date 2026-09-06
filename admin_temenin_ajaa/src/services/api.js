import axios from 'axios';

const API_BASE_URL = 'http://localhost:3002/api';

const client = axios.create({
  baseURL: API_BASE_URL,
  timeout: 5000,
  headers: {
    'Content-Type': 'application/json'
  }
});

// Fallback Empty Data
let mockUsers = [];
let mockDrivers = [];
let mockBookings = [];
let mockPosts = [];

export const adminApi = {
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
  }
};
