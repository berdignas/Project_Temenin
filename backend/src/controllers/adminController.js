const { supabaseAdmin } = require('../config/supabase');

// 1. Get Dashboard Summary Statistics
exports.getDashboardStats = async (req, res) => {
  try {
    const [usersRes, driversRes, bookingsRes, postsRes] = await Promise.all([
      supabaseAdmin.from('users').select('id, role, is_verified', { count: 'exact' }),
      supabaseAdmin.from('drivers').select('id, status, is_available', { count: 'exact' }),
      supabaseAdmin.from('bookings').select('id, status, total_price', { count: 'exact' }),
      supabaseAdmin.from('community_posts').select('id', { count: 'exact' })
    ]);

    const totalUsers = usersRes.count || 0;
    const totalDrivers = driversRes.count || 0;
    const pendingDrivers = driversRes.data ? driversRes.data.filter(d => d.status === 'pending').length : 0;
    const approvedDrivers = driversRes.data ? driversRes.data.filter(d => d.status === 'approved').length : 0;
    const totalBookings = bookingsRes.count || 0;
    const activeBookings = bookingsRes.data ? bookingsRes.data.filter(b => b.status === 'ongoing' || b.status === 'pending').length : 0;
    
    // Revenue calculation
    const totalRevenue = bookingsRes.data
      ? bookingsRes.data
          .filter(b => b.status === 'completed')
          .reduce((sum, b) => sum + (parseFloat(b.total_price) || 0), 0)
      : 0;

    // Fetch recent 5 bookings
    const { data: recentBookings } = await supabaseAdmin
      .from('bookings')
      .select('*, users(full_name, phone)')
      .order('created_at', { ascending: false })
      .limit(5);

    // Fetch recent pending driver approvals
    const { data: pendingDriverList } = await supabaseAdmin
      .from('drivers')
      .select('*, users(full_name, email, phone, avatar_url)')
      .eq('status', 'pending')
      .limit(5);

    res.status(200).json({
      success: true,
      data: {
        totalUsers,
        totalDrivers,
        pendingDrivers,
        approvedDrivers,
        totalBookings,
        activeBookings,
        totalRevenue,
        recentBookings: recentBookings || [],
        pendingDriverList: pendingDriverList || []
      }
    });
  } catch (error) {
    console.error('Error fetching admin dashboard stats:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// 2. Users / Client Management
exports.getUsers = async (req, res) => {
  try {
    const { role, search } = req.query;
    let query = supabaseAdmin.from('users').select('*').order('created_at', { ascending: false });

    if (role) {
      query = query.eq('role', role);
    }
    if (search) {
      query = query.or(`full_name.ilike.%${search}%,phone.ilike.%${search}%,email.ilike.%${search}%`);
    }

    const { data, error } = await query;
    if (error) throw error;

    res.status(200).json({ success: true, data: data || [] });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateUser = async (req, res) => {
  try {
    const { id } = req.params;
    const { full_name, phone, role, balance, points, is_verified } = req.body;

    const { data, error } = await supabaseAdmin
      .from('users')
      .update({
        full_name,
        phone,
        role,
        balance,
        points,
        is_verified,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    res.status(200).json({ success: true, message: 'Data pengguna berhasil diperbarui', data });
  } catch (error) {
    console.error('Error updating user:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.deleteUser = async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = await supabaseAdmin.from('users').delete().eq('id', id);
    if (error) throw error;

    res.status(200).json({ success: true, message: 'Pengguna berhasil dihapus' });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// 3. Drivers / Mitra Management
exports.getDrivers = async (req, res) => {
  try {
    const { status, search } = req.query;
    let query = supabaseAdmin
      .from('drivers')
      .select('*, users(full_name, email, phone, avatar_url, balance, is_verified)')
      .order('created_at', { ascending: false });

    if (status) {
      query = query.eq('status', status);
    }

    const { data, error } = await query;
    if (error) throw error;

    res.status(200).json({ success: true, data: data || [] });
  } catch (error) {
    console.error('Error fetching drivers:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.verifyDriverStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body; // 'approved' or 'rejected'

    if (!['approved', 'rejected', 'pending'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Status tidak valid' });
    }

    const updatePayload = {
      status,
      updated_at: new Date().toISOString()
    };

    if (status === 'approved') {
      updatePayload.approved_at = new Date().toISOString();
    }

    const { data, error } = await supabaseAdmin
      .from('drivers')
      .update(updatePayload)
      .eq('id', id)
      .select('*, users(full_name, phone)')
      .single();

    if (error) throw error;

    // Direct update user role to 'driver' if approved
    if (status === 'approved' && data.user_id) {
      await supabaseAdmin.from('users').update({ role: 'driver', is_verified: true }).eq('id', data.user_id);
    }

    res.status(200).json({
      success: true,
      message: `Status mitra driver berhasil diubah menjadi ${status}`,
      data
    });
  } catch (error) {
    console.error('Error verifying driver:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateDriver = async (req, res) => {
  try {
    const { id } = req.params;
    const { vehicle_type, vehicle_name, plate_number, price_per_hour, is_available, experience_years } = req.body;

    const { data, error } = await supabaseAdmin
      .from('drivers')
      .update({
        vehicle_type,
        vehicle_name,
        plate_number,
        price_per_hour,
        is_available,
        experience_years,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    res.status(200).json({ success: true, message: 'Data driver berhasil diperbarui', data });
  } catch (error) {
    console.error('Error updating driver:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// 4. Bookings Management
exports.getBookings = async (req, res) => {
  try {
    const { status } = req.query;
    let query = supabaseAdmin
      .from('bookings')
      .select('*, users!bookings_user_id_fkey(full_name, phone), drivers!bookings_driver_id_fkey(*, users(full_name, phone))')
      .order('created_at', { ascending: false });

    if (status) {
      query = query.eq('status', status);
    }

    const { data, error } = await query;
    if (error) throw error;

    res.status(200).json({ success: true, data: data || [] });
  } catch (error) {
    console.error('Error fetching bookings:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateBookingStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const { data, error } = await supabaseAdmin
      .from('bookings')
      .update({ status, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    res.status(200).json({ success: true, message: `Status pemesanan diubah menjadi ${status}`, data });
  } catch (error) {
    console.error('Error updating booking status:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// 5. Balance Top-Up Management
exports.topUpUserBalance = async (req, res) => {
  try {
    const { userId, amount } = req.body;
    if (!userId || !amount || isNaN(amount) || amount <= 0) {
      return res.status(400).json({ success: false, message: 'UserId dan Jumlah Top-Up tidak valid' });
    }

    // Get current balance
    const { data: user, error: fetchErr } = await supabaseAdmin
      .from('users')
      .select('balance')
      .eq('id', userId)
      .single();

    if (fetchErr || !user) {
      return res.status(404).json({ success: false, message: 'User tidak ditemukan' });
    }

    const newBalance = (parseFloat(user.balance) || 0) + parseFloat(amount);

    const { data, error } = await supabaseAdmin
      .from('users')
      .update({ balance: newBalance, updated_at: new Date().toISOString() })
      .eq('id', userId)
      .select()
      .single();

    if (error) throw error;

    res.status(200).json({
      success: true,
      message: `Berhasil menambahkan saldo sebesar Rp ${parseFloat(amount).toLocaleString('id-ID')}`,
      data
    });
  } catch (error) {
    console.error('Error top up balance:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// 6. Community Posts Moderation
exports.getCommunityPosts = async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('community_posts')
      .select('*, users(full_name, avatar_url, phone)')
      .order('created_at', { ascending: false });

    if (error) throw error;

    res.status(200).json({ success: true, data: data || [] });
  } catch (error) {
    console.error('Error fetching community posts:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.deleteCommunityPost = async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = await supabaseAdmin.from('community_posts').delete().eq('id', id);
    if (error) throw error;

    res.status(200).json({ success: true, message: 'Postingan berhasil dihapus' });
  } catch (error) {
    console.error('Error deleting post:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};
