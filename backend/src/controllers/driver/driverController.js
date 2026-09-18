// controllers/driverController.js
const { supabase, supabaseAdmin } = require('../../config/supabase');
const { lockDriverSchedule, unlockDriverSchedule } = require('../../services/scheduleService');
const escrowService = require('../../services/escrowService');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { ensureAuthUser } = require('../../utils/authSync');
const { atomicDeductBalance, atomicIncrementBalance } = require('../../utils/balanceHelper');

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

    // Ensure user exists in auth.users with matching user.id for GoTrue compatibility
    await ensureAuthUser(user.id, user.email);

    // Generate token JWT dengan klaim standar Supabase GoTrue
    const token = jwt.sign(
      { 
        aud: 'authenticated',
        role: 'authenticated',
        sub: user.id,
        id: user.id, 
        email: user.email, 
        phone: user.phone,
        full_name: user.full_name,
        app_metadata: {
          provider: 'email',
          providers: ['email'],
          role: 'driver'
        },
        user_metadata: {
          full_name: user.full_name,
          role: 'driver'
        }
      },
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
          id,
          full_name,
          email,
          phone,
          avatar_url,
          gender,
          role,
          balance,
          points,
          is_verified
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

    if (!status) {
      return res.status(400).json({
        success: false,
        message: 'Status is required'
      });
    }

    // Get driver_id
    const { data: driver, error: driverError } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', userId)
      .single();

    if (driverError || !driver) {
      return res.status(404).json({
        success: false,
        message: 'Driver not found'
      });
    }

    // Fetch existing booking
    const { data: existingBooking, error: getError } = await supabase
      .from('bookings')
      .select('*')
      .eq('id', bookingId)
      .single();

    if (getError || !existingBooking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    // 🛡️ PERBAIKAN ISU B: Driver tidak boleh mengubah status pembayaran
    const forbiddenFinancialStatuses = ['paid', 'closed', 'dp_paid'];
    if (forbiddenFinancialStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Status pembayaran '${status}' tidak dapat diubah oleh driver. Pelunasan harus diproses secara sah oleh client/sistem.`
      });
    }

    // Map sub-statuses to valid DB schema constraint status
    // Allowed DB status: 'pending', 'accepted', 'ongoing', 'completed', 'cancelled'
    let dbStatus = status;
    let subStatus = status;

    if (['on_the_way', 'arrived', 'started', 'completion_requested'].includes(status)) {
      dbStatus = 'ongoing';
    } else if (status === 'completed') {
      dbStatus = 'completed';
    } else if (status === 'cancelled') {
      dbStatus = 'cancelled';
    } else if (!['pending', 'accepted', 'ongoing', 'completed', 'cancelled'].includes(status)) {
      dbStatus = 'ongoing';
    }

    const currentDetails = (existingBooking.additional_details && typeof existingBooking.additional_details === 'object')
      ? { ...existingBooking.additional_details }
      : {};

    const updatedDetails = {
      ...currentDetails,
      sub_status: subStatus
    };

    // Update booking
    const { data: booking, error } = await supabase
      .from('bookings')
      .update({
        status: dbStatus,
        additional_details: updatedDetails,
        updated_at: new Date()
      })
      .eq('id', bookingId)
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

    // Schedule Lifecycle Management
    const targetDriverId = existingBooking.driver_id || driver.id;
    if (targetDriverId) {
      if (dbStatus === 'accepted') {
        await lockDriverSchedule(targetDriverId, booking.id, booking.booking_date, booking.duration || 60, 'Pesanan Terkonfirmasi');
      } else if (dbStatus === 'cancelled') {
        await unlockDriverSchedule(booking.id);
        const cancelReason = req.body.cancellation_reason || req.body.reason || 'Dibatalkan oleh driver';
        await escrowService.handleBookingCancellation({
          bookingId,
          cancelledBy: 'driver',
          reason: cancelReason,
          actorId: req.user.id
        });
      }
    }

    // If status is completed, increment driver's total_rides
    if (dbStatus === 'completed' && targetDriverId) {
      const { data: driverData } = await supabase
        .from('drivers')
        .select('total_rides')
        .eq('id', targetDriverId)
        .single();

      const newTotalRides = (driverData?.total_rides || 0) + 1;
      await supabase
        .from('drivers')
        .update({ total_rides: newTotalRides })
        .eq('id', targetDriverId);

      // 💰 Pencairan bagi hasil 90% ke saldo driver HANYA jika pembayaran sudah lunas (Pelunasan terverifikasi)
      // Mencegah kebocoran dana platform saat pesanan baru dibayar DP
      const isPelunasanVerified = currentDetails.pelunasan_paid === true || currentDetails.final_paid === true || existingBooking.sub_status === 'paid' || existingBooking.sub_status === 'closed';
      if (isPelunasanVerified) {
        await escrowService.releaseDriverPayout(bookingId, booking, 'Pesanan Diselesaikan Driver');
      } else {
        console.log(`ℹ️ [Driver Booking] Pesanan #${bookingId.substring(0, 8)} selesai operasional oleh driver, namun pelunasan belum dibayar oleh klien. Payout driver tetap aman tertahan di Escrow.`);
      }
    }

    // Auto-create notification record for client
    try {
      let notifTitle = '';
      let notifMessage = '';

      if (status === 'accepted') {
        notifTitle = 'Pesanan Diterima Driver! 🎉';
        notifMessage = 'Driver menyetujui pesanan Anda.';
      } else if (status === 'on_the_way') {
        notifTitle = 'Driver Sedang Menuju Lokasi 🛵';
        notifMessage = 'Driver Anda sedang dalam perjalanan ke lokasi penjemputan.';
      } else if (status === 'arrived') {
        notifTitle = 'Driver Sudah Sampai! 📍';
        notifMessage = 'Driver Anda telah tiba di lokasi penjemputan.';
      } else if (status === 'started' || status === 'ongoing') {
        notifTitle = 'Layanan Dimulai ✨';
        notifMessage = 'Pendampingan bersama driver sedang berlangsung.';
      } else if (status === 'completed' || status === 'closed' || status === 'paid') {
        notifTitle = 'Layanan Selesai 🏁';
        notifMessage = 'Terima kasih telah menggunakan Temenin Ajaa. Jangan lupa beri ulasan!';
      } else if (status === 'cancelled') {
        notifTitle = 'Pesanan Dibatalkan Driver ⚠️';
        notifMessage = 'Driver membatalkan pesanan. Dana DP Anda telah dikembalikan 100% ke saldo dompet aplikasi.';
      }

      if (notifTitle && existingBooking.user_id) {
        await supabase.from('notifications').insert({
          user_id: existingBooking.user_id,
          title: notifTitle,
          message: notifMessage,
          type: 'booking',
          data: { booking_id: bookingId }
        });
      }
    } catch (_) {}

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

    // Calculate pending escrow from bookings where payout is still held in escrow
    let pendingEscrow = 0;
    try {
      const { data: activeBookings } = await supabase
        .from('bookings')
        .select('total_price, escrow_balance, status, payout_status, additional_details')
        .eq('driver_id', driver.id)
        .neq('status', 'cancelled');

      (activeBookings || []).forEach(b => {
        const add = (b.additional_details && typeof b.additional_details === 'object') ? b.additional_details : {};
        const isReleased = b.payout_status === 'released' || add.payout_status === 'released' || add.driver_credited === true;
        const esc = parseFloat(b.escrow_balance) || parseFloat(add.escrow_balance) || 0;
        if (!isReleased && esc > 0) {
          pendingEscrow += esc;
        }
      });
    } catch (_) {}

    res.status(200).json({
      success: true,
      totalEarnings,
      totalRides,
      pendingEscrow,
      data: {
        total_earnings: totalEarnings,
        total_rides: totalRides,
        pending_escrow: pendingEscrow,
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
        id,
        user_id,
        vehicle_type,
        vehicle_name,
        plate_number,
        price_per_hour,
        rating,
        total_rides,
        is_available,
        status,
        latitude,
        longitude,
        users:user_id (
          full_name,
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

// Get Driver Schedule Slots (Public or for Driver)
const getDriverSchedules = async (req, res) => {
  try {
    const { id } = req.params;
    let driverId = id;

    if (!driverId || driverId === 'my') {
      const { data: d } = await supabase
        .from('drivers')
        .select('id')
        .eq('user_id', req.user.id)
        .single();
      if (!d) return res.status(404).json({ success: false, message: 'Driver profile not found' });
      driverId = d.id;
    }

    const { data: schedules, error } = await supabase
      .from('driver_schedules')
      .select('*')
      .eq('driver_id', driverId)
      .eq('status', 'locked')
      .order('start_time', { ascending: true });

    if (error) throw error;

    res.status(200).json({
      success: true,
      data: schedules
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Add Manual Off/Block Time Slot (Driver)
const addManualSchedule = async (req, res) => {
  try {
    const { start_time, end_time, title } = req.body;
    const userId = req.user.id;

    if (!start_time || !end_time) {
      return res.status(400).json({ success: false, message: 'Waktu mulai dan selesai wajib diisi' });
    }

    const { data: driver } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', userId)
      .single();

    if (!driver) return res.status(404).json({ success: false, message: 'Driver tidak ditemukan' });

    const { data: schedule, error } = await supabase
      .from('driver_schedules')
      .insert({
        driver_id: driver.id,
        booking_id: null,
        start_time: new Date(start_time).toISOString(),
        end_time: new Date(end_time).toISOString(),
        status: 'locked'
      })
      .select()
      .single();

    if (error) throw error;

    res.status(201).json({
      success: true,
      message: 'Jadwal manual berhasil dikunci',
      data: schedule
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Delete Manual Schedule Slot (Driver)
const deleteManualSchedule = async (req, res) => {
  try {
    const { scheduleId } = req.params;
    const userId = req.user.id;

    const { data: driver } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', userId)
      .single();

    if (!driver) return res.status(404).json({ success: false, message: 'Driver tidak ditemukan' });

    const { error } = await supabase
      .from('driver_schedules')
      .delete()
      .eq('id', scheduleId)
      .eq('driver_id', driver.id);

    if (error) throw error;

    res.status(200).json({
      success: true,
      message: 'Jadwal berhasil dihapus'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Update Buffer Time (Driver)
const updateBufferTime = async (req, res) => {
  try {
    const { buffer_time_minutes } = req.body;
    const userId = req.user.id;

    if (buffer_time_minutes === undefined || buffer_time_minutes < 0) {
      return res.status(400).json({ success: false, message: 'Buffer time minimal 0 menit' });
    }

    const { data: driver, error } = await supabase
      .from('drivers')
      .update({ buffer_time_minutes: parseInt(buffer_time_minutes, 10), updated_at: new Date() })
      .eq('user_id', userId)
      .select()
      .single();

    if (error) throw error;

    res.status(200).json({
      success: true,
      message: 'Toleransi waktu istirahat (buffer time) berhasil diperbarui',
      data: driver
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Update Driver Profile
const updateDriverProfile = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      full_name,
      phone,
      avatar_url,
      gender,
      vehicle_name,
      plate_number,
      price_per_hour,
      experience_years,
      vehicle_stnk
    } = req.body;

    // Update user details
    const userUpdates = {};
    if (full_name) userUpdates.full_name = full_name.trim();
    if (phone) userUpdates.phone = phone.trim();
    if (avatar_url) userUpdates.avatar_url = avatar_url.trim();
    if (gender) userUpdates.gender = gender.trim();
    userUpdates.updated_at = new Date();

    if (Object.keys(userUpdates).length > 1) {
      const { error: userError } = await supabase
        .from('users')
        .update(userUpdates)
        .eq('id', userId);

      if (userError) {
        return res.status(400).json({
          success: false,
          message: 'Failed to update user table: ' + userError.message
        });
      }
    }

    // Update driver details
    const driverUpdates = {};
    if (vehicle_name) driverUpdates.vehicle_name = vehicle_name.trim();
    if (plate_number) driverUpdates.plate_number = plate_number.toUpperCase().trim();
    if (price_per_hour !== undefined) driverUpdates.price_per_hour = Number(price_per_hour);
    if (experience_years !== undefined) driverUpdates.experience_years = Number(experience_years);
    if (vehicle_stnk) driverUpdates.vehicle_stnk = vehicle_stnk;
    driverUpdates.updated_at = new Date();

    const { data: updatedDriver, error: driverError } = await supabase
      .from('drivers')
      .update(driverUpdates)
      .eq('user_id', userId)
      .select(`
        *,
        users:user_id (
          full_name,
          email,
          phone,
          avatar_url,
          gender,
          balance,
          points
        )
      `)
      .single();

    if (driverError) {
      return res.status(400).json({
        success: false,
        message: 'Failed to update driver profile: ' + driverError.message
      });
    }

    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      data: updatedDriver
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

/**
 * Driver requests withdrawal from wallet balance
 * Enforces strict limit: amount <= balance, cannot withdraw more than balance
 * Automatically and atomically deducts the balance immediately
 */
const requestWithdrawal = async (req, res) => {
  try {
    const userId = req.user.id;
    const { 
      amount, 
      bank_name = 'Bank BCA', 
      account_number, 
      account_name, 
      notes = '' 
    } = req.body;

    const withdrawAmount = parseFloat(amount || 0);

    if (isNaN(withdrawAmount) || withdrawAmount < 10000) {
      return res.status(400).json({
        success: false,
        message: 'Nominal penarikan minimal Rp 10.000'
      });
    }

    if (!account_number || account_number.toString().trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Nomor rekening / e-wallet tujuan wajib diisi'
      });
    }

    // 1. Fetch current driver user data
    const { data: user, error: userErr } = await supabaseAdmin
      .from('users')
      .select('id, balance, full_name, email, role')
      .eq('id', userId)
      .single();

    if (userErr || !user) {
      return res.status(404).json({
        success: false,
        message: 'Akun driver tidak ditemukan'
      });
    }

    const currentBalance = parseFloat(user.balance || 0);

    // 2. STRICT VALIDATION: Cannot withdraw more than active balance
    if (withdrawAmount > currentBalance) {
      return res.status(400).json({
        success: false,
        message: `Saldo tidak mencukupi untuk melakukan penarikan sebesar Rp ${withdrawAmount.toLocaleString('id-ID')}. Saldo aktif Anda: Rp ${currentBalance.toLocaleString('id-ID')}`
      });
    }

    // 3. Ensure user exists in auth.users for FK integrity
    await ensureAuthUser(userId, user.email);

    // 4. ATOMIC DEDUCTION: deduct immediately using PostgreSQL row-lock via RPC / OCC CAS
    let newBalance;
    try {
      newBalance = await atomicDeductBalance(userId, withdrawAmount);
    } catch (deductErr) {
      if (deductErr.message === 'INSUFFICIENT_BALANCE') {
        return res.status(400).json({
          success: false,
          message: `Saldo tidak mencukupi untuk melakukan penarikan sebesar Rp ${withdrawAmount.toLocaleString('id-ID')}.`
        });
      }
      return res.status(400).json({
        success: false,
        message: 'Gagal memproses pemotongan saldo: ' + deductErr.message
      });
    }

    // 5. Insert withdrawal request into payment_transactions
    const recipientName = (account_name && account_name.trim()) ? account_name.trim() : user.full_name;
    const trxPayload = {
      user_id: userId,
      type: 'WITHDRAWAL',
      amount: withdrawAmount,
      unique_code: 0,
      total_payable: withdrawAmount,
      status: 'PENDING',
      sla_deadline: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
      admin_notes: JSON.stringify({
        bank_name: bank_name.trim(),
        account_number: account_number.toString().trim(),
        account_name: recipientName,
        notes: notes || 'Pengajuan penarikan saldo driver'
      })
    };

    const { data: newTrx, error: insErr } = await supabaseAdmin
      .from('payment_transactions')
      .insert([trxPayload])
      .select()
      .single();

    if (insErr) {
      console.error('Insert payment_transactions withdrawal error:', insErr);
      // Rollback deducted balance atomically
      try {
        await atomicIncrementBalance(userId, withdrawAmount);
      } catch (rbErr) {
        console.error('❌ Failed to rollback deducted balance:', rbErr.message);
      }
      return res.status(500).json({
        success: false,
        message: 'Gagal menyimpan pengajuan penarikan: ' + insErr.message
      });
    }

    // 6. Record in wallet_transactions
    try {
      const { error: wtErr } = await supabaseAdmin.from('wallet_transactions').insert([{
        user_id: userId,
        type: 'WITHDRAWAL_PENDING',
        amount: -withdrawAmount,
        description: `Pengajuan penarikan dana ke ${bank_name} (${account_number}) - A.N ${recipientName}`,
        reference_id: newTrx.id,
        created_at: new Date().toISOString()
      }]);
      if (wtErr) {
        console.error('❌ [DriverWithdrawal] Failed to record wallet_transactions:', wtErr.message, wtErr.details);
      }
    } catch (wtErr) {
      console.warn('wallet_transactions insert warning:', wtErr.message);
    }

    res.status(201).json({
      success: true,
      message: `Permintaan penarikan dana sebesar Rp ${withdrawAmount.toLocaleString('id-ID')} berhasil diajukan! Saldo aktif otomatis terpotong dan menunggu konfirmasi transfer Admin.`,
      data: {
        transaction: newTrx,
        bank_name,
        account_number,
        account_name: recipientName,
        deducted_amount: withdrawAmount,
        remaining_balance: newBalance
      }
    });

  } catch (error) {
    console.error('Driver withdrawal error:', error);
    res.status(500).json({
      success: false,
      message: 'Gagal memproses penarikan dana: ' + error.message
    });
  }
};

/**
 * Driver gets their withdrawal requests and statuses
 */
const getWithdrawalHistory = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data: withdrawals, error } = await supabaseAdmin
      .from('payment_transactions')
      .select('*')
      .eq('user_id', userId)
      .eq('type', 'WITHDRAWAL')
      .order('created_at', { ascending: false });

    if (error) throw error;

    const formatted = (withdrawals || []).map(w => {
      let bankInfo = {};
      try {
        if (w.admin_notes && (w.admin_notes.startsWith('{') || w.admin_notes.startsWith('['))) {
          bankInfo = JSON.parse(w.admin_notes);
        }
      } catch {
        // ignore JSON parse
      }

      return {
        id: w.id,
        amount: parseFloat(w.amount || 0),
        status: w.status,
        sla_deadline: w.sla_deadline,
        bank_name: bankInfo.bank_name || 'Bank BCA',
        account_number: bankInfo.account_number || '-',
        account_name: bankInfo.account_name || '-',
        admin_notes: bankInfo.notes || w.admin_notes,
        created_at: w.created_at
      };
    });

    res.status(200).json({
      success: true,
      data: formatted
    });
  } catch (error) {
    console.error('Get withdrawal history error:', error);
    res.status(500).json({
      success: false,
      message: error.message
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
  getAllDrivers,
  getDriverSchedules,
  addManualSchedule,
  deleteManualSchedule,
  updateBufferTime,
  updateDriverProfile,
  requestWithdrawal,
  getWithdrawalHistory
};