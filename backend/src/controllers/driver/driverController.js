// controllers/driverController.js
const { supabase } = require('../../config/supabase');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// Register Driver
const registerDriver = async (req, res) => {
  try {
    const {
      email, password, full_name, phone, gender,
      vehicle_type, vehicle_name, plate_number,
      price_per_hour, experience_years, id_card_number,
      driver_license_number, vehicle_stnk
    } = req.body;

    // Validasi input dasar
    if (!email || !password || !full_name || !vehicle_type || !vehicle_name || !plate_number) {
      return res.status(400).json({
        success: false,
        message: 'Data wajib harus diisi (email, password, nama, tipe kendaraan, nama kendaraan, plat nomor)'
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password minimal 6 karakter'
      });
    }

    if (price_per_hour && price_per_hour < 25000) {
      return res.status(400).json({
        success: false,
        message: 'Harga per jam minimal Rp 25.000'
      });
    }

    const cleanEmail = email.toLowerCase().trim();

    // Cek apakah email sudah terdaftar di tabel users
    const { data: existingUser, error: checkError } = await supabase
      .from('users')
      .select('email')
      .eq('email', cleanEmail)
      .maybeSingle();

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email sudah terdaftar'
      });
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const password_hash = await bcrypt.hash(password, salt);

    // Insert ke tabel users (sebagai driver)
    const { data: user, error: userError } = await supabase
      .from('users')
      .insert([
        {
          email: cleanEmail,
          password_hash: password_hash,
          full_name: full_name.trim(),
          phone: phone?.trim() || null,
          gender: gender?.trim() || 'Laki-laki',
          role: 'driver',
          is_verified: true,
          balance: 0,
          points: 0,
          created_at: new Date(),
          updated_at: new Date()
        }
      ])
      .select()
      .single();

    if (userError) {
      console.error('User creation error:', userError);
      return res.status(400).json({
        success: false,
        message: 'Gagal mendaftar: ' + userError.message
      });
    }

    // Insert ke tabel drivers
    const { data: driver, error: driverError } = await supabase
      .from('drivers')
      .insert([
        {
          user_id: user.id,
          vehicle_type: vehicle_type,
          vehicle_name: vehicle_name.trim(),
          plate_number: plate_number.toUpperCase().trim(),
          price_per_hour: price_per_hour || 50000,
          rating: 5.0,
          total_rides: 0,
          is_available: true,
          status: 'pending', // pending, approved, rejected
          experience_years: experience_years || 0,
          id_card_number: id_card_number,
          driver_license_number: driver_license_number,
          vehicle_stnk: vehicle_stnk,
          registration_date: new Date(),
          approved_at: null
        }
      ])
      .select()
      .single();

    if (driverError) {
      // Rollback user jika insert driver gagal
      await supabase.from('users').delete().eq('id', user.id);
      
      console.error('Driver creation error:', driverError);
      return res.status(400).json({
        success: false,
        message: 'Gagal mendaftarkan driver: ' + driverError.message
      });
    }

    // Generate token JWT
    const token = jwt.sign(
      { id: user.id, email: user.email, role: 'driver' },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    // Hapus sensitive data
    const { password_hash: _, ...userWithoutPassword } = user;

    res.status(201).json({
      success: true,
      message: 'Pendaftaran driver berhasil! Menunggu verifikasi admin',
      data: {
        user: userWithoutPassword,
        driver: driver,
        token: token
      }
    });
    
  } catch (error) {
    console.error('Register driver error:', error);
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan pada server: ' + error.message
    });
  }
};

// Get Driver Profile
const getDriverProfile = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data: driver, error } = await supabase
      .from('drivers')
      .select(`
        *,
        users:user_id (
          full_name,
          email,
          phone,
          avatar_url,
          gender
        )
      `)
      .eq('user_id', userId)
      .single();

    if (error) {
      return res.status(404).json({
        success: false,
        message: 'Driver profile not found'
      });
    }

    res.status(200).json({
      success: true,
      data: driver
    });
  } catch (error) {
    console.error('Get driver profile error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Update Driver Status (Available/Offline)
const updateDriverStatus = async (req, res) => {
  try {
    const { is_available, latitude, longitude } = req.body;
    const userId = req.user.id;

    const { data: driver, error } = await supabase
      .from('drivers')
      .update({
        is_available: is_available,
        latitude: latitude || null,
        longitude: longitude || null,
        updated_at: new Date()
      })
      .eq('user_id', userId)
      .select()
      .single();

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    res.status(200).json({
      success: true,
      message: `Status driver ${is_available ? 'aktif' : 'offline'}`,
      data: driver
    });
  } catch (error) {
    console.error('Update driver status error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Get Driver Bookings
const getDriverBookings = async (req, res) => {
  try {
    const userId = req.user.id;
    const { status } = req.query;

    // Get driver_id from user_id
    const { data: driver, error: driverError } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', userId)
      .single();

    if (driverError) {
      return res.status(404).json({
        success: false,
        message: 'Driver not found'
      });
    }

    let query = supabase
      .from('bookings')
      .select(`
        *,
        users:user_id (
          full_name,
          email,
          phone,
          avatar_url
        )
      `)
      .eq('driver_id', driver.id)
      .order('created_at', { ascending: false });

    if (status && status !== 'all') {
      query = query.eq('status', status);
    }

    const { data: bookings, error } = await query;

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    res.status(200).json({
      success: true,
      data: bookings
    });
  } catch (error) {
    console.error('Get driver bookings error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Update Booking Status (Driver)
const updateBookingStatus = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { status } = req.body;
    const userId = req.user.id;

    // Get driver_id
    const { data: driver, error: driverError } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', userId)
      .single();

    if (driverError) {
      return res.status(404).json({
        success: false,
        message: 'Driver not found'
      });
    }

    // Update booking
    const { data: booking, error } = await supabase
      .from('bookings')
      .update({
        status: status,
        updated_at: new Date()
      })
      .eq('id', bookingId)
      .eq('driver_id', driver.id)
      .select(`
        *,
        users:user_id (
          id,
          full_name,
          email,
          phone,
          avatar_url,
          role,
          balance,
          points
        )
      `)
      .single();

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    res.status(200).json({
      success: true,
      message: 'Status booking berhasil diupdate',
      data: booking
    });
  } catch (error) {
    console.error('Update booking status error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Get Driver Earnings
const getDriverEarnings = async (req, res) => {
  try {
    const userId = req.user.id;
    const { period } = req.query; // 'daily', 'weekly', 'monthly'

    // Get driver_id
    const { data: driver, error: driverError } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', userId)
      .single();

    if (driverError) {
      return res.status(404).json({
        success: false,
        message: 'Driver not found'
      });
    }

    let dateFilter = {};
    const now = new Date();
    
    switch(period) {
      case 'daily':
        dateFilter = {
          gte: new Date(now.setHours(0, 0, 0, 0)).toISOString(),
          lte: new Date(now.setHours(23, 59, 59, 999)).toISOString()
        };
        break;
      case 'weekly':
        const weekStart = new Date(now);
        weekStart.setDate(now.getDate() - now.getDay());
        dateFilter = {
          gte: new Date(weekStart.setHours(0, 0, 0, 0)).toISOString(),
          lte: new Date(now.setHours(23, 59, 59, 999)).toISOString()
        };
        break;
      case 'monthly':
        dateFilter = {
          gte: new Date(now.getFullYear(), now.getMonth(), 1).toISOString(),
          lte: new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59).toISOString()
        };
        break;
    }

    const { data: completedBookings, error } = await supabase
      .from('bookings')
      .select('total_price, created_at')
      .eq('driver_id', driver.id)
      .eq('status', 'completed')
      .gte('created_at', dateFilter.gte)
      .lte('created_at', dateFilter.lte);

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    const totalEarnings = completedBookings.reduce((sum, booking) => sum + (booking.total_price || 0), 0);
    const totalRides = completedBookings.length;

    res.status(200).json({
      success: true,
      data: {
        total_earnings: totalEarnings,
        total_rides: totalRides,
        period: period || 'all',
        bookings: completedBookings
      }
    });
  } catch (error) {
    console.error('Get driver earnings error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Get All Drivers (client-facing)
const getAllDrivers = async (req, res) => {
  try {
    const { data: drivers, error } = await supabase
      .from('drivers')
      .select(`
        *,
        users:user_id (
          full_name,
          email,
          phone,
          avatar_url,
          gender
        )
      `)
      .eq('status', 'approved'); // Only return approved drivers

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    res.status(200).json({
      success: true,
      data: drivers
    });
  } catch (error) {
    console.error('Get all drivers error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error: ' + error.message
    });
  }
};

module.exports = {
  registerDriver,
  getDriverProfile,
  updateDriverStatus,
  getDriverBookings,
  updateBookingStatus,
  getDriverEarnings,
  getAllDrivers
};