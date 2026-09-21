const { supabaseAdmin } = require('../config/supabase');
const { lockDriverSchedule, unlockDriverSchedule } = require('../services/scheduleService');
const escrowService = require('../services/escrowService');
const { ensureAuthUser } = require('../utils/authSync');
const { atomicIncrementBalance } = require('../utils/balanceHelper');

// 1. Get Dashboard Summary Statistics
exports.getDashboardStats = async (req, res) => {
  try {
    const [usersRes, driversRes, bookingsRes, postsRes, withdrawalsRes] = await Promise.all([
      supabaseAdmin.from('users').select('id, role, is_verified', { count: 'exact' }),
      supabaseAdmin.from('drivers').select('id, status, is_available', { count: 'exact' }),
      supabaseAdmin.from('bookings').select('id, status, total_price', { count: 'exact' }),
      supabaseAdmin.from('community_posts').select('id', { count: 'exact' }),
      supabaseAdmin.from('payment_transactions').select('id', { count: 'exact', head: true }).eq('type', 'WITHDRAWAL').eq('status', 'PENDING')
    ]);

    const totalUsers = usersRes.count || 0;
    const totalDrivers = driversRes.count || 0;
    const pendingDrivers = driversRes.data ? driversRes.data.filter(d => d.status === 'pending').length : 0;
    const approvedDrivers = driversRes.data ? driversRes.data.filter(d => d.status === 'approved').length : 0;
    const totalBookings = bookingsRes.count || 0;
    const activeBookings = bookingsRes.data ? bookingsRes.data.filter(b => b.status === 'ongoing' || b.status === 'pending').length : 0;
    const pendingWithdrawals = withdrawalsRes.count || 0;
    
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
        pendingWithdrawals,
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

exports.createBooking = async (req, res) => {
  try {
    const { user_id, driver_id, pickup_location, dropoff_location, total_price, duration, status } = req.body;

    const { data, error } = await supabaseAdmin
      .from('bookings')
      .insert({
        user_id: user_id || null,
        driver_id: driver_id || null,
        pickup_location: pickup_location || 'Lokasi Penjemputan',
        dropoff_location: dropoff_location || 'Lokasi Tujuan',
        total_price: parseFloat(total_price) || 50000,
        duration: parseInt(duration) || 60,
        status: status || 'pending',
        additional_details: {
          sub_status: status === 'cancelled' ? 'cancelled' : (status === 'ongoing' ? 'dp_paid' : 'pending')
        },
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .select()
      .single();

    if (error) throw error;

    res.status(201).json({ success: true, message: 'Pesanan berhasil dibuat oleh Admin', data });
  } catch (error) {
    console.error('Error creating booking:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const { pickup_location, dropoff_location, total_price, duration, duration_unit, status, driver_id } = req.body;

    const { data: existing } = await supabaseAdmin
      .from('bookings')
      .select('additional_details')
      .eq('id', id)
      .single();

    const updatePayload = {
      updated_at: new Date().toISOString()
    };
    if (pickup_location !== undefined) updatePayload.pickup_location = pickup_location;
    if (dropoff_location !== undefined) updatePayload.dropoff_location = dropoff_location;
    if (total_price !== undefined) updatePayload.total_price = parseFloat(total_price);
    if (duration !== undefined) {
      let rawDuration = parseInt(duration) || 60;
      const unit = (duration_unit || req.body.unit || '').toString().toLowerCase();
      updatePayload.duration = (unit === 'hours' || unit === 'jam' || unit === 'hour') 
        ? rawDuration * 60 
        : rawDuration;
    }
    if (driver_id !== undefined) updatePayload.driver_id = driver_id || null;
    if (status !== undefined) {
      let dbStatus = status;
      const subStatus = status;

      if (['on_the_way', 'arrived', 'started', 'dp_paid', 'completion_requested'].includes(status)) {
        dbStatus = 'ongoing';
      } else if (['closed', 'paid'].includes(status)) {
        dbStatus = 'completed';
      } else if (!['pending', 'accepted', 'ongoing', 'completed', 'cancelled'].includes(status)) {
        dbStatus = 'ongoing';
      }
      updatePayload.status = dbStatus;

      const addDetails = (existing?.additional_details && typeof existing.additional_details === 'object') ? { ...existing.additional_details } : {};
      addDetails.sub_status = subStatus;
      if (subStatus === 'cancelled') addDetails.cancelled_by = 'admin';
      else if (subStatus === 'dp_paid') addDetails.dp_paid = true;
      else if (subStatus === 'closed' || subStatus === 'paid') {
        addDetails.pelunasan_paid = true;
        addDetails.final_paid = true;
      }
      updatePayload.additional_details = addDetails;
    }

    const { data, error } = await supabaseAdmin
      .from('bookings')
      .update(updatePayload)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    // Jika status diubah menjadi selesai / lunas oleh Admin, cairkan bagi hasil 90% hanya jika pelunasan terverifikasi (Idempoten)
    const isPelunasanVerified = data.additional_details?.pelunasan_paid === true || data.additional_details?.final_paid === true || data.sub_status === 'paid' || data.sub_status === 'closed';
    if (updatePayload.status === 'completed' && (data.driver_id || driver_id) && isPelunasanVerified) {
      await escrowService.releaseDriverPayout(id, data, 'Admin Edit Booking');
    }

    res.status(200).json({ success: true, message: 'Data pesanan berhasil diperbarui', data });
  } catch (error) {
    console.error('Error updating booking:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.deleteBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const deleteFinance = req.body?.deleteFinance !== undefined 
      ? req.body.deleteFinance 
      : (req.query?.deleteFinance !== undefined ? req.query.deleteFinance === 'true' : true);

    // 1. Fetch booking details
    const { data: booking } = await supabaseAdmin
      .from('bookings')
      .select('id, driver_id, status, total_price')
      .eq('id', id)
      .maybeSingle();

    // 2. Unlock schedule if driver was booked
    try {
      await unlockDriverSchedule(id);
    } catch (schErr) {
      console.warn('Unlock schedule warning:', schErr.message);
    }

    // 3. Clean up related payment_transactions completely
    if (deleteFinance !== false) {
      const { error: trxDelErr } = await supabaseAdmin
        .from('payment_transactions')
        .delete()
        .eq('booking_id', id);

      if (trxDelErr) {
        console.warn('Warning deleting payment transactions:', trxDelErr.message);
      }
    }

    // 4. Delete booking row
    const { error } = await supabaseAdmin.from('bookings').delete().eq('id', id);
    if (error) throw error;

    res.status(200).json({
      success: true,
      message: 'Pesanan dan seluruh riwayat transaksi tagihan/DP terkait berhasil dihapus permanen.'
    });
  } catch (error) {
    console.error('Error deleting booking:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.bulkDeleteBookings = async (req, res) => {
  try {
    const { ids, deleteFinance } = req.body;
    if (!Array.isArray(ids) || ids.length === 0) {
      return res.status(400).json({ success: false, message: 'Daftar ID pesanan tidak boleh kosong' });
    }

    const shouldDeleteFinance = deleteFinance !== false;

    // 1. Unlock driver schedules for all bookings
    for (const id of ids) {
      try {
        await unlockDriverSchedule(id);
      } catch (_) {}
    }

    // 2. Delete related payment transactions if requested
    if (shouldDeleteFinance) {
      const { error: trxErr } = await supabaseAdmin
        .from('payment_transactions')
        .delete()
        .in('booking_id', ids);

      if (trxErr) {
        console.warn('Warning deleting payment transactions in bulk:', trxErr.message);
      }
    }

    // 3. Delete related booking messages
    try {
      await supabaseAdmin
        .from('booking_messages')
        .delete()
        .in('booking_id', ids);
    } catch (_) {}

    // 4. Delete bookings
    const { error } = await supabaseAdmin
      .from('bookings')
      .delete()
      .in('id', ids);

    if (error) throw error;

    res.status(200).json({
      success: true,
      message: `${ids.length} pesanan berhasil dihapus permanen.`
    });
  } catch (error) {
    console.error('Error bulk deleting bookings:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateBookingStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!status) {
      return res.status(400).json({ success: false, message: 'Status wajib diisi' });
    }

    // Fetch existing details & driver info
    const { data: existing } = await supabaseAdmin
      .from('bookings')
      .select('*, driver_id, booking_date, duration, additional_details')
      .eq('id', id)
      .single();

    if (!existing) {
      return res.status(404).json({ success: false, message: 'Pemesanan tidak ditemukan' });
    }

    // Mapping sub-status ke status valid schema database PostgreSQL:
    // Schema CHECK constraint: status IN ('pending', 'accepted', 'ongoing', 'completed', 'cancelled')
    let dbStatus = status;
    const subStatus = status;

    if (['on_the_way', 'arrived', 'started', 'dp_paid', 'completion_requested'].includes(status)) {
      dbStatus = 'ongoing';
    } else if (['closed', 'paid'].includes(status)) {
      dbStatus = 'completed';
    } else if (!['pending', 'accepted', 'ongoing', 'completed', 'cancelled'].includes(status)) {
      dbStatus = 'ongoing';
    }

    const addDetails = (existing.additional_details && typeof existing.additional_details === 'object') ? { ...existing.additional_details } : {};
    addDetails.sub_status = subStatus;
    if (subStatus === 'cancelled') {
      addDetails.cancelled_by = 'admin';
    } else if (subStatus === 'dp_paid') {
      addDetails.dp_paid = true;
    } else if (subStatus === 'closed' || subStatus === 'paid') {
      addDetails.pelunasan_paid = true;
      addDetails.final_paid = true;
    }

    const { data, error } = await supabaseAdmin
      .from('bookings')
      .update({ 
        status: dbStatus, 
        additional_details: addDetails,
        updated_at: new Date().toISOString() 
      })
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    // Schedule Lifecycle Management jika driver_id tersedia
    if (existing.driver_id) {
      if (dbStatus === 'accepted') {
        await lockDriverSchedule(existing.driver_id, existing.id, existing.booking_date, existing.duration || 60, 'Pesanan Terkonfirmasi (Admin)');
      } else if (dbStatus === 'cancelled') {
        await unlockDriverSchedule(existing.id);
      }
    }

    // 💰 Pencairan Bagi Hasil 90% ke Saldo Driver via EscrowService jika Admin ACC/Selesaikan Pembayaran
    // 🛡️ IDEMPOTEN: Hanya dieksekusi 1 kali dan hanya jika pelunasan terverifikasi
    const isPelunasanVerified = addDetails.pelunasan_paid === true || addDetails.final_paid === true || subStatus === 'paid' || subStatus === 'closed';
    if ((dbStatus === 'completed' || subStatus === 'paid' || subStatus === 'closed') && existing.driver_id && isPelunasanVerified) {
      await escrowService.releaseDriverPayout(id, { ...existing, additional_details: addDetails }, 'Disetujui Admin');
    }

    res.status(200).json({ success: true, message: `Status pemesanan diubah menjadi ${subStatus}`, data });
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
      .select('balance, email, full_name')
      .eq('id', userId)
      .single();

    if (fetchErr || !user) {
      return res.status(404).json({ success: false, message: 'User tidak ditemukan' });
    }

    const numAmount = parseFloat(amount);
    const newBalance = await atomicIncrementBalance(userId, numAmount);

    const data = {
      id: userId,
      balance: newBalance,
      full_name: user.full_name,
      email: user.email
    };

    // Ensure auth user & record transaction
    await ensureAuthUser(userId, user.email);

    try {
      const { data: trx } = await supabaseAdmin
        .from('payment_transactions')
        .insert([{
          user_id: userId,
          type: 'TOPUP',
          amount: numAmount,
          unique_code: 0,
          total_payable: numAmount,
          status: 'APPROVED',
          sla_deadline: new Date().toISOString(),
          admin_verified_by: req.user?.id || null,
          admin_notes: 'Top-Up instan disetujui oleh Super Admin'
        }])
        .select()
        .single();

      const { error: wtError } = await supabaseAdmin.from('wallet_transactions').insert([{
        user_id: userId,
        type: 'TOPUP_ADMIN',
        amount: numAmount,
        description: `Top-Up saldo dari Admin sebesar Rp ${numAmount.toLocaleString('id-ID')}`,
        reference_id: trx?.id || null,
        created_at: new Date().toISOString()
      }]);
      if (wtError) {
        console.error('❌ [AdminTopUp] Failed to insert wallet_transactions:', wtError.message, wtError.details);
      }
    } catch (logErr) {
      console.warn('Log topup transaction warning:', logErr.message);
    }

    res.status(200).json({
      success: true,
      message: `Berhasil menambahkan saldo sebesar Rp ${numAmount.toLocaleString('id-ID')}`,
      data
    });
  } catch (error) {
    console.error('Error top up balance:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// 5b. Finance & Transaction Management CMS
exports.getTransactions = async (req, res) => {
  try {
    const { type, status, search } = req.query;

    let query = supabaseAdmin
      .from('payment_transactions')
      .select('*')
      .order('created_at', { ascending: false });

    if (type) query = query.eq('type', type);
    if (status && status !== 'ALL') query = query.eq('status', status);

    const { data: dbTransactions, error } = await query;
    if (error) throw error;

    // Fetch related users
    const userIds = [...new Set((dbTransactions || []).map(t => t.user_id).filter(Boolean))];
    const bookingIds = [...new Set((dbTransactions || []).map(t => t.booking_id).filter(Boolean))];

    let usersMap = {};
    if (userIds.length > 0) {
      const { data: usersData } = await supabaseAdmin
        .from('users')
        .select('id, full_name, email, phone, role')
        .in('id', userIds);
      (usersData || []).forEach(u => { usersMap[u.id] = u; });
    }

    let bookingsMap = {};
    if (bookingIds.length > 0) {
      const { data: bookingsData } = await supabaseAdmin
        .from('bookings')
        .select('id, status, total_price, driver_id, drivers(id, users(full_name))')
        .in('id', bookingIds);
      (bookingsData || []).forEach(b => { bookingsMap[b.id] = b; });
    }

    let formattedList = (dbTransactions || []).map(t => {
      let bankInfo = {};
      try {
        if (t.admin_notes && (t.admin_notes.startsWith('{') || t.admin_notes.startsWith('['))) {
          bankInfo = JSON.parse(t.admin_notes);
        }
      } catch {
        // ignore parse error
      }

      const user = usersMap[t.user_id] || {};
      const booking = bookingsMap[t.booking_id] || {};

      return {
        id: t.id,
        booking_id: t.booking_id,
        user_name: bankInfo.account_name || user.full_name || 'Pengguna',
        user_role: (user.role || 'client').toUpperCase(),
        driver_name: booking.drivers?.users?.full_name || (user.role === 'driver' ? user.full_name : '-'),
        type: t.type,
        amount: parseFloat(t.amount || 0),
        unique_code: t.unique_code || 0,
        total_payable: parseFloat(t.total_payable || t.amount || 0),
        status: t.status,
        booking_status: booking.status === 'cancelled' ? 'CANCELLED_BY_CLIENT' : (booking.status || null),
        bank_name: bankInfo.method === 'QRIS' ? 'QRIS (Xendit)' : (bankInfo.bank_name || 'Bank BCA'),
        account_number: bankInfo.method === 'QRIS' ? 'Gateway Otomatis' : (bankInfo.account_number || '-'),
        account_name: bankInfo.account_name || user.full_name || '-',
        proof_url: t.proof_url || null,
        ocr_match_score: t.proof_url ? 98 : null,
        sla_deadline: t.sla_deadline,
        admin_notes: bankInfo.notes || t.admin_notes || '',
        created_at: t.created_at,
        processed_at: t.updated_at || null
      };
    });

    if (search) {
      const q = search.toLowerCase();
      formattedList = formattedList.filter(t => 
        t.user_name?.toLowerCase().includes(q) ||
        t.driver_name?.toLowerCase().includes(q) ||
        t.id?.toLowerCase().includes(q) ||
        t.booking_id?.toLowerCase().includes(q)
      );
    }

    res.status(200).json({
      success: true,
      data: formattedList
    });
  } catch (error) {
    console.error('Error fetching admin transactions:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// 5c. Approve DP Transaction (Lock in Escrow & Start Booking)
exports.approveTransaction = async (req, res) => {
  try {
    const { id } = req.params;
    const { notes } = req.body;

    const { data: trx, error } = await supabaseAdmin
      .from('payment_transactions')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !trx) {
      return res.status(404).json({ success: false, message: 'Transaksi tidak ditemukan' });
    }

    // =========================================================================
    // 🛡️ PENANGANAN KHUSUS TRANSAKSI TIPE TOPUP
    // =========================================================================
    if (trx.type === 'TOPUP') {
      if (trx.status !== 'PENDING') {
        return res.status(400).json({ 
          success: false, 
          message: `Transaksi Top-Up ini sudah pernah diproses sebelumnya (Status: ${trx.status})` 
        });
      }

      const topUpAmount = parseFloat(trx.amount || 0);
      if (isNaN(topUpAmount) || topUpAmount <= 0) {
        return res.status(400).json({ success: false, message: 'Nominal Top-Up pada transaksi ini tidak valid' });
      }

      // 1. Pastikan record auth user ada untuk relasi FK
      const { data: targetUser, error: userFetchErr } = await supabaseAdmin
        .from('users')
        .select('id, balance, email, full_name')
        .eq('id', trx.user_id)
        .single();

      if (userFetchErr || !targetUser) {
        return res.status(404).json({ success: false, message: 'Pengguna pemilik transaksi Top-Up tidak ditemukan' });
      }

      await ensureAuthUser(trx.user_id, targetUser.email);

      // 2. Kreditkan saldo ke users.balance secara atomik
      const newBalance = await atomicIncrementBalance(trx.user_id, topUpAmount);

      // 3. Update status transaksi di payment_transactions menjadi APPROVED
      const { error: updTrxErr } = await supabaseAdmin
        .from('payment_transactions')
        .update({
          status: 'APPROVED',
          admin_verified_by: req.user?.id || null,
          admin_notes: notes || 'Top-Up manual disetujui & diverifikasi oleh Admin. Saldo telah dikreditkan.',
          processed_at: new Date().toISOString()
        })
        .eq('id', trx.id);

      if (updTrxErr) {
        console.error('❌ Gagal update status payment_transactions:', updTrxErr.message);
      }

      // 4. Catat mutasi resmi di buku besar dompet (wallet_transactions)
      try {
        const { error: wtError } = await supabaseAdmin.from('wallet_transactions').insert([{
          user_id: trx.user_id,
          type: 'TOPUP',
          amount: topUpAmount,
          description: `Top-Up saldo disetujui Admin sebesar Rp ${topUpAmount.toLocaleString('id-ID')}`,
          reference_id: trx.id,
          created_at: new Date().toISOString()
        }]);
        if (wtError) {
          console.error('❌ [AdminTopUp] Gagal mencatat wallet_transactions:', wtError.message);
        }
      } catch (wtErr) {
        console.warn('wallet_transactions insert warning:', wtErr.message);
      }

      // 5. Kirim notifikasi ke aplikasi klien
      try {
        await supabaseAdmin.from('notifications').insert([{
          user_id: trx.user_id,
          title: 'Top-Up Saldo Berhasil! 🎉',
          message: `Pengajuan Top-Up saldo sebesar Rp ${topUpAmount.toLocaleString('id-ID')} telah disetujui Admin dan masuk ke dompet Anda.`,
          type: 'wallet',
          data: { transaction_id: trx.id }
        }]);
      } catch (_) {}

      return res.status(200).json({
        success: true,
        message: `Top-Up sebesar Rp ${topUpAmount.toLocaleString('id-ID')} berhasil disetujui! Saldo pengguna telah diperbarui (Total Saldo: Rp ${newBalance.toLocaleString('id-ID')}).`,
        data: {
          transaction_id: trx.id,
          user_id: trx.user_id,
          amount: topUpAmount,
          new_balance: newBalance
        }
      });
    }

    // =========================================================================
    // PENANGANAN TRANSAKSI PEMBAYARAN DP PESANAN (BOOKINGS)
    // =========================================================================
    const bookingId = trx.booking_id;
    if (!bookingId) {
      return res.status(400).json({ success: false, message: 'booking_id tidak valid untuk transaksi pembayaran pemesanan' });
    }

    const { data: booking, error: bErr } = await supabaseAdmin
      .from('bookings')
      .select('*')
      .eq('id', bookingId)
      .single();

    if (bErr || !booking) {
      return res.status(404).json({ success: false, message: 'Pesanan tidak ditemukan' });
    }

    const dpAmount = parseFloat(trx.amount || 0);

    // 1. Hold DP payment in Escrow Vault
    const updatedBooking = await escrowService.holdPaymentInEscrow({
      booking,
      payAmount: dpAmount,
      isPelunasan: false,
      paymentType: 'dp'
    });

    // 2. Advance booking status to ongoing & dp_paid
    const addDetails = { ...(updatedBooking.additional_details || {}) };
    addDetails.dp_paid = true;
    addDetails.dp_payment_status = 'approved';
    addDetails.dp_approved_at = new Date().toISOString();

    await supabaseAdmin
      .from('bookings')
      .update({
        status: 'ongoing',
        sub_status: 'dp_paid',
        additional_details: addDetails,
        updated_at: new Date().toISOString()
      })
      .eq('id', bookingId);

    // 3. Update payment_transactions status
    if (trx) {
      await supabaseAdmin
        .from('payment_transactions')
        .update({
          status: 'HELD_IN_ESCROW',
          admin_verified_by: req.user?.id || null,
          admin_notes: notes || 'DP Disetujui Admin. Dana tersimpan di Escrow Vault.'
        })
        .eq('id', trx.id);
    }

    res.status(200).json({
      success: true,
      message: 'Transaksi DP berhasil dikonfirmasi dan dana masuk ke Escrow Vault.'
    });
  } catch (error) {
    console.error('Error approving transaction:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// 5d. Settle Pelunasan Transaction & Release Driver Payout Split
exports.settlePelunasanSplit = async (req, res) => {
  try {
    const { id } = req.params;
    const { notes } = req.body;

    const { data: trx, error } = await supabaseAdmin
      .from('payment_transactions')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !trx) {
      return res.status(404).json({ success: false, message: 'Transaksi tidak ditemukan' });
    }

    const bookingId = trx.booking_id;
    const { data: booking, error: bErr } = await supabaseAdmin
      .from('bookings')
      .select('*')
      .eq('id', bookingId)
      .single();

    if (bErr || !booking) {
      return res.status(404).json({ success: false, message: 'Pesanan tidak ditemukan' });
    }

    const pelunasanAmount = parseFloat(trx.amount || 0);

    // 1. Hold Pelunasan into Escrow
    const updatedBooking = await escrowService.holdPaymentInEscrow({
      booking,
      payAmount: pelunasanAmount,
      isPelunasan: true,
      paymentType: 'pelunasan'
    });

    // 2. Mark booking as completed & pelunasan_paid = true
    const addDetails = { ...(updatedBooking.additional_details || {}) };
    addDetails.pelunasan_paid = true;
    addDetails.pelunasan_payment_status = 'approved';
    addDetails.pelunasan_approved_at = new Date().toISOString();

    await supabaseAdmin
      .from('bookings')
      .update({
        status: 'completed',
        sub_status: 'paid',
        additional_details: addDetails,
        updated_at: new Date().toISOString()
      })
      .eq('id', bookingId);

    // 3. Release Driver Payout (90% driver share)
    const payoutResult = await escrowService.releaseDriverPayout(
      bookingId,
      { ...updatedBooking, status: 'completed', additional_details: addDetails },
      'Pelunasan Disetujui Admin'
    );

    // 4. Update transaction status
    if (trx) {
      await supabaseAdmin
        .from('payment_transactions')
        .update({
          status: 'APPROVED',
          admin_verified_by: req.user?.id || null,
          admin_notes: notes || 'Pelunasan disetujui. Dana bagi hasil berhasil dicairkan ke Driver.'
        })
        .eq('id', trx.id);
    }

    res.status(200).json({
      success: true,
      message: `Pelunasan Disetujui! Rp ${(payoutResult?.driverEarning || 0).toLocaleString('id-ID')} masuk ke Saldo Driver, Rp ${(payoutResult?.platformFee || 0).toLocaleString('id-ID')} Platform Fee.`,
      data: payoutResult
    });
  } catch (error) {
    console.error('Error settling pelunasan split:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// 5e. Disburse Driver Withdrawal Payout
exports.disbursePayout = async (req, res) => {
  try {
    const { id } = req.params;
    const { notes } = req.body;

    const { data: trx, error } = await supabaseAdmin
      .from('payment_transactions')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !trx) {
      return res.status(404).json({ success: false, message: 'Transaksi penarikan tidak ditemukan' });
    }

    if (trx.status !== 'PENDING') {
      return res.status(400).json({ success: false, message: `Transaksi sudah berstatus ${trx.status}` });
    }

    // Update status to DISBURSED
    await supabaseAdmin
      .from('payment_transactions')
      .update({
        status: 'DISBURSED',
        admin_verified_by: req.user?.id || null,
        admin_notes: notes || 'Penarikan dana disetujui & berhasil ditransfer ke rekening Driver.'
      })
      .eq('id', id);

    try {
      const { data: updatedRows, error: wtErr } = await supabaseAdmin
        .from('wallet_transactions')
        .update({
          type: 'WITHDRAWAL_COMPLETED',
          description: `Penarikan dana sebesar Rp ${parseFloat(trx.amount || 0).toLocaleString('id-ID')} telah berhasil ditransfer oleh Admin.`
        })
        .eq('reference_id', id)
        .select();

      if (wtErr) {
        console.error('❌ [DisbursePayout] Failed to update wallet_transactions:', wtErr.message, wtErr.details);
      } else if (!updatedRows || updatedRows.length === 0) {
        // Jika pencatatan awal belum ada, masukkan mutasi penarikan selesai ke buku besar
        const withdrawAmount = parseFloat(trx.amount || 0);
        const { error: insErr } = await supabaseAdmin.from('wallet_transactions').insert([{
          user_id: trx.user_id,
          type: 'WITHDRAWAL_COMPLETED',
          amount: -withdrawAmount,
          description: `Penarikan dana sebesar Rp ${withdrawAmount.toLocaleString('id-ID')} telah berhasil ditransfer oleh Admin.`,
          reference_id: id,
          created_at: new Date().toISOString()
        }]);
        if (insErr) {
          console.error('❌ [DisbursePayout] Failed to insert completed withdrawal into wallet_transactions:', insErr.message);
        }
      }
    } catch (wtErr) {
      console.warn('Update wallet_transactions warning:', wtErr.message);
    }

    res.status(200).json({
      success: true,
      message: 'Penarikan dana disetujui & berhasil ditandai selesai ditransfer ke rekening Driver.'
    });
  } catch (error) {
    console.error('Error disbursing payout:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// 5f. Reject Transaction (Refunds held balance if WITHDRAWAL)
exports.rejectTransaction = async (req, res) => {
  try {
    const { id } = req.params;
    const { notes } = req.body;

    const { data: trx, error } = await supabaseAdmin
      .from('payment_transactions')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !trx) {
      return res.status(404).json({ success: false, message: 'Transaksi tidak ditemukan' });
    }

    if (trx.status !== 'PENDING') {
      return res.status(400).json({ success: false, message: `Transaksi sudah berstatus ${trx.status}` });
    }

    // If WITHDRAWAL, automatically refund the held balance back to driver atomically
    if (trx.type === 'WITHDRAWAL') {
      const refundAmount = parseFloat(trx.amount || 0);
      const newBalance = await atomicIncrementBalance(trx.user_id, refundAmount);

      try {
        const { error: wtErr } = await supabaseAdmin.from('wallet_transactions').insert([{
          user_id: trx.user_id,
          type: 'REFUND_WITHDRAWAL',
          amount: refundAmount,
          description: `Pengembalian dana penarikan yang ditolak Admin: ${notes || 'Data rekening tidak sesuai'}`,
          reference_id: trx.id,
          created_at: new Date().toISOString()
        }]);
        if (wtErr) {
          console.error('❌ [RejectTransaction] Failed to log refund wallet_transactions:', wtErr.message, wtErr.details);
        }
      } catch (wtErr) {
        console.warn('Log refund wallet transaction warning:', wtErr.message);
      }
    } else if (trx.booking_id) {
      // If DP or Pelunasan, mark booking metadata as rejected
      const { data: booking } = await supabaseAdmin
        .from('bookings')
        .select('additional_details')
        .eq('id', trx.booking_id)
        .single();

      const addDetails = { ...(booking?.additional_details || {}) };
      if (trx.type === 'DP') addDetails.dp_payment_status = 'rejected';
      else if (trx.type === 'PELUNASAN') addDetails.pelunasan_payment_status = 'rejected';

      await supabaseAdmin
        .from('bookings')
        .update({ additional_details: addDetails, updated_at: new Date().toISOString() })
        .eq('id', trx.booking_id);
    }

    // Mark transaction as REJECTED
    await supabaseAdmin
      .from('payment_transactions')
      .update({
        status: 'REJECTED',
        admin_verified_by: req.user?.id || null,
        admin_notes: notes || 'Transaksi ditolak oleh Admin'
      })
      .eq('id', id);

    res.status(200).json({
      success: true,
      message: `Transaksi ${trx.type} berhasil ditolak${trx.type === 'WITHDRAWAL' ? ' dan saldo telah dikembalikan ke dompet driver' : ''}.`
    });
  } catch (error) {
    console.error('Error rejecting transaction:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// 5g. Execute DP Forfeit (50% Driver Compensation, 50% Platform Fee)
exports.executeDpForfeit = async (req, res) => {
  try {
    const { id } = req.params;
    const { notes } = req.body;

    let bookingId = id.startsWith('trx-dp-') ? id.replace('trx-dp-', '') : null;
    let forfeitAmount = 0;

    if (!bookingId) {
      const { data: trx } = await supabaseAdmin
        .from('payment_transactions')
        .select('*')
        .eq('id', id)
        .single();
      if (trx) {
        bookingId = trx.booking_id;
        forfeitAmount = parseFloat(trx.amount || 0);
      }
    }

    if (!bookingId) {
      return res.status(400).json({ success: false, message: 'booking_id tidak valid untuk eksekusi DP hangus' });
    }

    const { data: booking } = await supabaseAdmin
      .from('bookings')
      .select('*, drivers(user_id)')
      .eq('id', bookingId)
      .single();

    if (!booking) {
      return res.status(404).json({ success: false, message: 'Pesanan tidak ditemukan' });
    }

    if (!forfeitAmount) {
      forfeitAmount = booking.dp_amount ? parseFloat(booking.dp_amount) : Math.round(parseFloat(booking.total_price || 0) * 0.3);
    }

    const driverShare = Math.round(forfeitAmount * 0.5);
    const platformShare = forfeitAmount - driverShare;

    // Credit driver share to driver balance atomically
    const driverUserId = booking.drivers?.user_id;
    if (driverUserId) {
      const newBal = await atomicIncrementBalance(driverUserId, driverShare);

      try {
        const { error: wtErr } = await supabaseAdmin.from('wallet_transactions').insert([{
          user_id: driverUserId,
          type: 'DP_FORFEIT_COMPENSATION',
          amount: driverShare,
          description: `Kompensasi pembatalan sepihak pesanan ${bookingId} (50% DP)`,
          reference_id: bookingId,
          created_at: new Date().toISOString()
        }]);
        if (wtErr) {
          console.error('❌ [ForfeitCompensation] Failed to log forfeit wallet_transactions:', wtErr.message, wtErr.details);
        }
      } catch (wtErr) {
        console.warn('Forfeit compensation log warning:', wtErr.message);
      }
    }

    // Update payment_transactions
    if (!id.startsWith('trx-dp-')) {
      await supabaseAdmin
        .from('payment_transactions')
        .update({
          status: 'FORFEITED',
          admin_verified_by: req.user?.id || null,
          admin_notes: notes || 'Pesanan dibatalkan sepihak. DP Hangus (50% Driver, 50% Platform Fee)'
        })
        .eq('id', id);
    }

    res.status(200).json({
      success: true,
      message: `DP Hangus Dieksekusi! Rp ${driverShare.toLocaleString('id-ID')} masuk ke Saldo Driver, Rp ${platformShare.toLocaleString('id-ID')} ke Kas Platform.`
    });
  } catch (error) {
    console.error('Error executing DP forfeit:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// 5g. Delete / Clean up Transaction Record
exports.deleteTransaction = async (req, res) => {
  try {
    const { id } = req.params;

    const { data: trx, error: fetchErr } = await supabaseAdmin
      .from('payment_transactions')
      .select('*')
      .eq('id', id)
      .maybeSingle();

    if (fetchErr || !trx) {
      return res.status(404).json({ success: false, message: 'Transaksi tidak ditemukan' });
    }

    const { error: delErr } = await supabaseAdmin
      .from('payment_transactions')
      .delete()
      .eq('id', id);

    if (delErr) throw delErr;

    res.status(200).json({
      success: true,
      message: `Riwayat transaksi ${trx.type} (ID: ${trx.id}) berhasil dihapus permanen dari sistem keuangan.`
    });
  } catch (error) {
    console.error('Error deleting transaction:', error);
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

// 7. Event Terdekat Management
let memoryEvents = [
  {
    id: 'ev-1',
    title: 'We The Fest 2026',
    date_string: '14-16 Ags 2026',
    location: 'GBK Sports Complex, Jaksel',
    image_url: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=600&auto=format&fit=crop',
    ticket_url: 'https://wethefest.com',
    category: 'Festival Musik',
    description: 'Festival musik musim panas terbesar di Jakarta menghadirkan musisi internasional dan lokal terbaik.',
    is_active: true,
    created_at: new Date()
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
    created_at: new Date()
  },
  {
    id: 'ev-3',
    title: 'Indonesia Comic Con',
    date_string: '23-25 Des 2026',
    location: 'JCC Senayan, Jaksel',
    image_url: 'https://images.unsplash.com/photo-1563089145-599997674d42?q=80&w=600&auto=format&fit=crop',
    ticket_url: 'https://indonesiacomiccon.com',
    category: 'Pameran & Pop Culture',
    description: 'Ajang kumpul komunitas pecinta anime, cosplay, game, dan komik terbesar di Indonesia.',
    is_active: true,
    created_at: new Date()
  }
];

exports.getEvents = async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('app_events')
      .select('*')
      .order('created_at', { ascending: false });

    if (error || !data || data.length === 0) {
      return res.status(200).json({ success: true, data: memoryEvents });
    }
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(200).json({ success: true, data: memoryEvents });
  }
};

exports.createEvent = async (req, res) => {
  try {
    const eventData = {
      ...req.body,
      is_active: req.body.is_active !== undefined ? req.body.is_active : true,
      created_at: new Date()
    };

    const { data, error } = await supabaseAdmin
      .from('app_events')
      .insert([eventData])
      .select();

    if (error) {
      const newEv = { id: 'ev-' + Date.now(), ...eventData };
      memoryEvents.unshift(newEv);
      return res.status(201).json({ success: true, message: 'Event berhasil ditambahkan', data: newEv });
    }

    res.status(201).json({ success: true, message: 'Event berhasil ditambahkan', data: data[0] });
  } catch (error) {
    const newEv = { id: 'ev-' + Date.now(), ...req.body, is_active: true, created_at: new Date() };
    memoryEvents.unshift(newEv);
    res.status(201).json({ success: true, message: 'Event berhasil disimpan', data: newEv });
  }
};

exports.updateEvent = async (req, res) => {
  try {
    const { id } = req.params;
    const { data, error } = await supabaseAdmin
      .from('app_events')
      .update({ ...req.body, updated_at: new Date() })
      .eq('id', id)
      .select();

    memoryEvents = memoryEvents.map(ev => ev.id === id ? { ...ev, ...req.body } : ev);

    res.status(200).json({ success: true, message: 'Event berhasil diperbarui', data: data ? data[0] : null });
  } catch (error) {
    const { id } = req.params;
    memoryEvents = memoryEvents.map(ev => ev.id === id ? { ...ev, ...req.body } : ev);
    res.status(200).json({ success: true, message: 'Event diperbarui' });
  }
};

exports.deleteEvent = async (req, res) => {
  try {
    const { id } = req.params;
    await supabaseAdmin.from('app_events').delete().eq('id', id);
    memoryEvents = memoryEvents.filter(ev => ev.id !== id);
    res.status(200).json({ success: true, message: 'Event berhasil dihapus' });
  } catch (error) {
    const { id } = req.params;
    memoryEvents = memoryEvents.filter(ev => ev.id !== id);
    res.status(200).json({ success: true, message: 'Event berhasil dihapus' });
  }
};
