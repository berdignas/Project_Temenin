const { supabase } = require('../config/supabase');
const { checkDriverAvailability, lockDriverSchedule, unlockDriverSchedule } = require('../services/scheduleService');
const escrowService = require('../services/escrowService');

// 1. Client creates a new booking request (Negotiation/Negosiasi or Direct)
exports.createBooking = async (req, res, next) => {
  try {
    const {
      pickup_location,
      dropoff_location,
      pickup_latitude,
      pickup_longitude,
      dropoff_latitude,
      dropoff_longitude,
      duration,
      duration_unit,
      total_price,
      booking_date,
      additional_details,
      driver_id // optional, for direct bookings
    } = req.body;

    const userId = req.user.id;
    const targetDate = booking_date ? new Date(booking_date) : new Date();
    let rawDuration = parseInt(duration) || 60;
    
    const unit = (duration_unit || additional_details?.duration_unit || additional_details?.unit || '').toString().toLowerCase();
    let durationMinutes;
    if (unit === 'hours' || unit === 'jam' || unit === 'hour') {
      durationMinutes = rawDuration * 60;
    } else {
      // Standard: jika unit 'minutes'/'menit' atau tidak ditentukan, nilai dianggap sebagai Menit murni
      durationMinutes = rawDuration;
    }

    // Jika booking langsung ke profil driver tertentu, cek bentrok jadwal dulu
    if (driver_id) {
      const availability = await checkDriverAvailability(driver_id, targetDate, durationMinutes);
      if (!availability.available) {
        return res.status(409).json({
          success: false,
          message: availability.reason || 'Jadwal driver tidak tersedia pada waktu tersebut'
        });
      }
    }

    const enrichedDetails = { ...(additional_details || {}) };
    const sType = (enrichedDetails.serviceType || enrichedDetails.service_type || '').toString().toLowerCase();
    const isExplicitFlexible = enrichedDetails.is_flexible === true || enrichedDetails.isFlexible === true;
    const isFlexibleService = isExplicitFlexible || sType === 'freedom' || sType === 'freedom_request' || sType === 'assistant' || sType === 'detektif' || sType === 'detective';
    enrichedDetails.is_flexible = isFlexibleService;

    const { data: booking, error } = await supabase
      .from('bookings')
      .insert({
        user_id: userId,
        driver_id: driver_id || null,
        status: 'pending',
        pickup_location,
        dropoff_location,
        pickup_latitude,
        pickup_longitude,
        dropoff_latitude,
        dropoff_longitude,
        duration: durationMinutes,
        total_price,
        booking_date: targetDate,
        additional_details: enrichedDetails
      })
      .select()
      .single();

    if (error) throw error;

    // Jika pemesanan langsung dari profil driver, otomatis kunci jadwal driver!
    if (driver_id) {
      await lockDriverSchedule(driver_id, booking.id, targetDate, durationMinutes, 'Pesanan Profil (Pending)');
    }

    res.status(201).json({
      success: true,
      message: 'Booking request created successfully',
      data: booking
    });
  } catch (error) {
    next(error);
  }
};

// 2. Client gets their booking requests history
exports.getClientBookings = async (req, res, next) => {
  try {
    const userId = req.user.id;

    const { data: bookings, error } = await supabase
      .from('bookings')
      .select(`
        *,
        driver:drivers (
          id,
          vehicle_name,
          plate_number,
          user:users (
            full_name,
            phone,
            avatar_url
          )
        )
      `)
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (error) throw error;

    res.status(200).json({
      success: true,
      data: bookings
    });
  } catch (error) {
    next(error);
  }
};

// 3. Driver gets all open bookings (status = 'pending')
exports.getOpenBookings = async (req, res, next) => {
  try {
    const userId = req.user.id;

    // Get current driver ID
    const { data: driver, error: driverError } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', userId)
      .single();

    if (driverError || !driver) {
      return res.status(403).json({
        success: false,
        message: 'Only registered drivers can view open bookings'
      });
    }

    // Get all bookings with status pending
    // Also include details of the client who requested it
    const { data: bookings, error } = await supabase
      .from('bookings')
      .select(`
        *,
        client:users (
          id,
          full_name,
          avatar_url,
          phone,
          is_verified
        )
      `)
      .eq('status', 'pending')
      .order('created_at', { ascending: false });

    if (error) throw error;

    // Check if the current driver has already placed a negotiation on these bookings
    const { data: driverNegotiations, error: negotiationsError } = await supabase
      .from('booking_negotiations')
      .select('booking_id, negotiated_price, status')
      .eq('driver_id', driver.id);

    if (negotiationsError) throw negotiationsError;

    const negotiationsMap = {};
    driverNegotiations.forEach(nego => {
      negotiationsMap[nego.booking_id] = {
        negotiatedPrice: nego.negotiated_price,
        status: nego.status
      };
    });

    const bookingsWithNegotiationInfo = bookings.map(b => ({
      ...b,
      hasNegotiated: !!negotiationsMap[b.id],
      myNegotiationInfo: negotiationsMap[b.id] || null
    }));

    res.status(200).json({
      success: true,
      data: bookingsWithNegotiationInfo
    });
  } catch (error) {
    next(error);
  }
};

// 4. Driver places a negotiation / counter-offer on a booking
exports.placeNegotiation = async (req, res, next) => {
  try {
    const { bookingId } = req.params;
    const { negotiated_price, notes } = req.body;
    const userId = req.user.id;

    if (!negotiated_price) {
      return res.status(400).json({
        success: false,
        message: 'Negotiated price is required'
      });
    }

    // Get current driver ID
    const { data: driver, error: driverError } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', userId)
      .single();

    if (driverError || !driver) {
      return res.status(403).json({
        success: false,
        message: 'Only registered drivers can submit negotiations'
      });
    }

    // Check if booking exists and is still pending
    const { data: booking, error: bookingError } = await supabase
      .from('bookings')
      .select('status, additional_details')
      .eq('id', bookingId)
      .single();

    if (bookingError || !booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    if (booking.status !== 'pending') {
      return res.status(400).json({
        success: false,
        message: 'This booking is no longer open for negotiation'
      });
    }

    // Policy Guard: Negosiasi HANYA diperbolehkan untuk Layanan Fleksibel (Freedom Request)
    const details = booking.additional_details || {};
    const sType = (details.serviceType || details.service_type || '').toString().toLowerCase();
    const isFlexible = details.is_flexible === true || details.isFlexible === true ||
      sType === 'freedom' || sType === 'freedom_request' || sType === 'assistant' || sType === 'detektif' || sType === 'detective';

    if (!isFlexible) {
      return res.status(400).json({
        success: false,
        message: 'Negosiasi harga tidak diizinkan untuk layanan ini. Tarif telah diatur oleh Admin. Negosiasi hanya berlaku untuk Layanan Fleksibel (Freedom Request).'
      });
    }

    // Check if negotiation already exists (update/negotiation)
    const { data: existingNego, error: checkError } = await supabase
      .from('booking_negotiations')
      .select('id')
      .eq('booking_id', bookingId)
      .eq('driver_id', driver.id)
      .maybeSingle();

    if (checkError) throw checkError;

    let resultNego;
    if (existingNego) {
      // Update negotiation
      const { data, error } = await supabase
        .from('booking_negotiations')
        .update({
          negotiated_price,
          notes,
          status: 'pending',
          updated_at: new Date()
        })
        .eq('id', existingNego.id)
        .select()
        .single();
      
      if (error) throw error;
      resultNego = data;
    } else {
      // Create new negotiation
      const { data, error } = await supabase
        .from('booking_negotiations')
        .insert({
          booking_id: bookingId,
          driver_id: driver.id,
          negotiated_price,
          notes
        })
        .select()
        .single();

      if (error) throw error;
      resultNego = data;
    }

    res.status(200).json({
      success: true,
      message: 'Negotiation submitted successfully',
      data: resultNego
    });
  } catch (error) {
    next(error);
  }
};

// 5. Get all negotiations for a specific booking request
exports.getBookingNegotiations = async (req, res, next) => {
  try {
    const { bookingId } = req.params;

    const { data: negotiations, error } = await supabase
      .from('booking_negotiations')
      .select(`
        *,
        driver:drivers (
          id,
          vehicle_name,
          plate_number,
          rating,
          total_rides,
          user:users (
            id,
            full_name,
            avatar_url,
            phone
          )
        )
      `)
      .eq('booking_id', bookingId)
      .order('negotiated_price', { ascending: true });

    if (error) throw error;

    res.status(200).json({
      success: true,
      data: negotiations
    });
  } catch (error) {
    next(error);
  }
};

// 6. Client accepts a specific driver's negotiation
exports.acceptNegotiation = async (req, res, next) => {
  try {
    const { bookingId, negotiationId } = req.params;
    const userId = req.user.id;

    // 1. Check current booking status & user ownership
    const { data: currentBooking, error: currentBookingErr } = await supabase
      .from('bookings')
      .select('id, user_id, status')
      .eq('id', bookingId)
      .single();

    if (currentBookingErr || !currentBooking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    if (currentBooking.user_id !== userId) {
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to accept negotiations for this booking'
      });
    }

    if (currentBooking.status !== 'pending') {
      return res.status(400).json({
        success: false,
        message: 'Pesanan ini sudah tidak dalam status pending (sudah diterima atau sedang berjalan)'
      });
    }

    // 2. Get negotiation info
    const { data: nego, error: negoError } = await supabase
      .from('booking_negotiations')
      .select('*')
      .eq('id', negotiationId)
      .eq('booking_id', bookingId)
      .single();

    if (negoError || !nego) {
      return res.status(404).json({
        success: false,
        message: 'Negotiation offer not found'
      });
    }

    // 3. Update booking: set status = 'accepted', total_price = negotiated_price, driver_id = nego.driver_id
    // Added .eq('status', 'pending') for atomic DB guard against race conditions
    const { data: booking, error: bookingError } = await supabase
      .from('bookings')
      .update({
        status: 'accepted',
        driver_id: nego.driver_id,
        total_price: nego.negotiated_price,
        updated_at: new Date()
      })
      .eq('id', bookingId)
      .eq('user_id', userId)
      .eq('status', 'pending')
      .select()
      .single();

    if (bookingError || !booking) {
      return res.status(400).json({
        success: false,
        message: 'Failed to accept negotiation. Booking may no longer be pending or does not belong to you.'
      });
    }

    // 4. Update negotiation statuses
    // Accepted negotiation
    await supabase
      .from('booking_negotiations')
      .update({ status: 'accepted', updated_at: new Date() })
      .eq('id', negotiationId);

    // Rejected other negotiations for this booking
    await supabase
      .from('booking_negotiations')
      .update({ status: 'rejected', updated_at: new Date() })
      .eq('booking_id', bookingId)
      .not('id', 'eq', negotiationId);

    // Lock driver's schedule automatically upon accepting negotiation
    if (booking.driver_id && booking.booking_date) {
      await lockDriverSchedule(booking.driver_id, booking.id, booking.booking_date, booking.duration || 60, 'Pesanan Terkonfirmasi');
    }

    // Auto-create notification record
    try {
      if (booking.user_id) {
        await supabase.from('notifications').insert({
          user_id: booking.user_id,
          title: 'Tawaran Diterima! 🎉',
          message: 'Tawaran pesanan telah disepakati dan dikonfirmasi.',
          type: 'booking',
          data: { booking_id: bookingId }
        });
      }
    } catch (_) {}

    res.status(200).json({
      success: true,
      message: 'Negotiation accepted. Driver assigned to booking.',
      data: booking
    });
  } catch (error) {
    next(error);
  }
};

// 7. Update booking status (General: ongoing, completed, cancelled)
exports.updateBookingStatus = async (req, res, next) => {
  try {
    const { bookingId } = req.params;
    const { status } = req.body;
    const userId = req.user.id;

    // Verify booking exists
    const { data: booking, error: getError } = await supabase
      .from('bookings')
      .select('*')
      .eq('id', bookingId)
      .single();

    if (getError || !booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    // Check authorization: client, driver, or admin
    const { data: driverData } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();

    const isClient = booking.user_id === userId;
    const isDriver = driverData && (booking.driver_id === driverData.id);
    const isAdmin = req.user.role === 'admin';

    if (!isClient && !isDriver && !isAdmin) {
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to update this booking'
      });
    }

    // 🛡️ PERBAIKAN ISU B: Blokir manipulasi status finansial oleh Client/Driver
    const forbiddenFinancialStatuses = ['paid', 'closed', 'dp_paid'];
    if (!isAdmin && forbiddenFinancialStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Status pembayaran '${status}' tidak dapat diubah secara manual. Pembayaran harus melalui alur pembayaran resmi.`
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

    const currentDetails = (booking.additional_details && typeof booking.additional_details === 'object') 
      ? { ...booking.additional_details } 
      : {};

    const updatedDetails = {
      ...currentDetails,
      sub_status: subStatus
    };

    // Hanya Admin yang dapat memodifikasi flag pelunasan langsung via endpoint status ini
    if (isAdmin) {
      if (subStatus === 'dp_paid') {
        updatedDetails.dp_paid = true;
      } else if (subStatus === 'closed' || subStatus === 'paid') {
        updatedDetails.pelunasan_paid = true;
        updatedDetails.final_paid = true;
      }
    }

    // Update status
    const { data: updatedBooking, error } = await supabase
      .from('bookings')
      .update({
        status: dbStatus,
        additional_details: updatedDetails,
        updated_at: new Date()
      })
      .eq('id', bookingId)
      .select()
      .single();

    if (error) throw error;

    // Schedule Lifecycle Management
    if (booking.driver_id) {
      if (dbStatus === 'accepted') {
        await lockDriverSchedule(booking.driver_id, booking.id, booking.booking_date, booking.duration || 60, 'Pesanan Terkonfirmasi');
      } else if (dbStatus === 'cancelled') {
        await unlockDriverSchedule(booking.id);
        const cancelReason = req.body.cancellation_reason || req.body.reason || 'Dibatalkan oleh pengguna';
        const cancelActor = isAdmin ? 'admin' : (isClient ? 'client' : (isDriver ? 'driver' : 'client'));
        await escrowService.handleBookingCancellation({
          bookingId,
          cancelledBy: cancelActor,
          reason: cancelReason,
          actorId: req.user.id
        });
      }
    }

    // If status is completed and driver_id is present, increment driver's total rides
    if (dbStatus === 'completed' && booking.driver_id) {
      const { data: driver } = await supabase
        .from('drivers')
        .select('total_rides')
        .eq('id', booking.driver_id)
        .single();
      
      const newTotalRides = (driver?.total_rides || 0) + 1;

      await supabase
        .from('drivers')
        .update({ total_rides: newTotalRides })
        .eq('id', booking.driver_id);

      // 💰 Pencairan bagi hasil 90% ke saldo driver HANYA jika pembayaran sudah lunas (Pelunasan terverifikasi)
      // Mencegah kebocoran dana platform saat pesanan baru dibayar DP
      const isPelunasanVerified = currentDetails.pelunasan_paid === true || currentDetails.final_paid === true || (isAdmin && updatedDetails.pelunasan_paid === true) || booking.sub_status === 'paid' || booking.sub_status === 'closed';
      if (isPelunasanVerified) {
        await escrowService.releaseDriverPayout(bookingId, updatedBooking, 'Pesanan Selesai');
      } else {
        console.log(`ℹ️ [Booking] Pesanan #${bookingId.substring(0, 8)} selesai operasional, namun pelunasan belum dibayar oleh klien. Payout driver tetap aman tertahan di Escrow.`);
      }
    }

    // Auto-create notification record for client & driver
    try {
      let notifTitle = '';
      let notifMessage = '';

      if (status === 'accepted') {
        notifTitle = 'Pesanan Diterima Driver! 🎉';
        notifMessage = 'Driver menyetujui pesanan Anda. Silakan bayar DP untuk melanjutkan.';
      } else if (status === 'on_the_way') {
        notifTitle = 'Driver Sedang Menuju Lokasi 🛵';
        notifMessage = 'Driver Anda sedang dalam perjalanan ke lokasi penjemputan.';
      } else if (status === 'arrived') {
        notifTitle = 'Driver Sudah Sampai! 📍';
        notifMessage = 'Driver Anda telah tiba di lokasi penjemputan.';
      } else if (status === 'started' || status === 'ongoing') {
        notifTitle = 'Layanan Dimulai ✨';
        notifMessage = 'Pendampingan bersama driver sedang berlangsung.';
      } else if (status === 'completed') {
        notifTitle = 'Layanan Selesai 🏁';
        notifMessage = 'Terima kasih telah menggunakan Temenin Ajaa. Jangan lupa beri ulasan!';
      } else if (status === 'cancelled') {
        if (isDriver) {
          notifTitle = 'Pesanan Dibatalkan Driver ⚠️';
          notifMessage = 'Driver membatalkan pesanan. Dana DP Anda telah dikembalikan 100% ke saldo dompet.';
        } else {
          notifTitle = 'Pesanan Dibatalkan ❌';
          notifMessage = 'Pesanan Anda telah dibatalkan. Sesuai ketentuan, DP tidak dapat dikembalikan.';
        }
      }

      if (notifTitle && booking.user_id) {
        await supabase.from('notifications').insert({
          user_id: booking.user_id,
          title: notifTitle,
          message: notifMessage,
          type: 'booking',
          data: { booking_id: bookingId }
        });
      }

      // If client cancelled, notify driver about forfeit compensation
      if (status === 'cancelled' && !isDriver && booking.driver_id) {
        const { data: drv } = await supabase.from('drivers').select('user_id').eq('id', booking.driver_id).single();
        if (drv?.user_id) {
          await supabase.from('notifications').insert({
            user_id: drv.user_id,
            title: 'Pesanan Dibatalkan Penumpang ⚠️',
            message: 'Penumpang membatalkan pesanan. Kompensasi DP sebesar 50% telah masuk ke saldo dompet Anda.',
            type: 'booking',
            data: { booking_id: bookingId }
          });
        }
      }
    } catch (notifErr) {
      console.error('Error inserting notification:', notifErr.message);
    }

    res.status(200).json({
      success: true,
      message: `Booking status updated to ${status}`,
      data: updatedBooking
    });
  } catch (error) {
    next(error);
  }
};

// 8. Client submits a review & rating for a completed booking
exports.createBookingReview = async (req, res, next) => {
  try {
    const { bookingId } = req.params;
    const { rating, comment } = req.body;
    const userId = req.user.id;

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating must be a number between 1 and 5'
      });
    }

    // 1. Get booking details to find the driver_id
    const { data: booking, error: bookingError } = await supabase
      .from('bookings')
      .select('id, user_id, driver_id, status')
      .eq('id', bookingId)
      .single();

    if (bookingError || !booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    if (booking.user_id !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Only the client who booked can submit a review'
      });
    }

    if (!booking.driver_id) {
      return res.status(400).json({
        success: false,
        message: 'No driver assigned to this booking'
      });
    }

    // 2. Insert or update review in 'reviews' table
    const { data: review, error: reviewError } = await supabase
      .from('reviews')
      .insert({
        booking_id: bookingId,
        user_id: userId,
        driver_id: booking.driver_id,
        rating: parseFloat(rating),
        comment: comment || ''
      })
      .select()
      .single();

    if (reviewError) throw reviewError;

    // 3. Recalculate driver's overall rating automatically
    const { data: allReviews, error: reviewsError } = await supabase
      .from('reviews')
      .select('rating')
      .eq('driver_id', booking.driver_id);

    if (!reviewsError && allReviews && allReviews.length > 0) {
      const sumRatings = allReviews.reduce((sum, r) => sum + parseFloat(r.rating || 5), 0);
      const avgRating = (sumRatings / allReviews.length).toFixed(1);

      await supabase
        .from('drivers')
        .update({ rating: parseFloat(avgRating), updated_at: new Date() })
        .eq('id', booking.driver_id);
    }

    res.status(201).json({
      success: true,
      message: 'Ulasan berhasil disimpan dan rating driver telah diperbarui',
      data: review
    });
  } catch (error) {
    next(error);
  }
};

// 9. Get all reviews for a booking or driver
exports.getBookingReviews = async (req, res, next) => {
  try {
    const { bookingId } = req.params;

    const { data: reviews, error } = await supabase
      .from('reviews')
      .select(`
        *,
        user:users (
          id,
          full_name,
          avatar_url
        )
      `)
      .eq('booking_id', bookingId)
      .order('created_at', { ascending: false });

    if (error) throw error;

    res.status(200).json({
      success: true,
      data: reviews
    });
  } catch (error) {
    next(error);
  }
};

// 10. Send a chat message in a booking room
exports.sendChatMessage = async (req, res, next) => {
  try {
    const { bookingId } = req.params;
    const { message, attachment_url, sender_role } = req.body;
    const userId = req.user.id;

    if (!message || message.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Message content cannot be empty'
      });
    }

    // Verify booking exists and user is participant
    const { data: bookingCheck, error: bookingErr } = await supabase
      .from('bookings')
      .select('id, user_id, driver_id')
      .eq('id', bookingId)
      .single();

    if (bookingErr || !bookingCheck) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    const { data: driverData } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();

    const isClient = bookingCheck.user_id === userId;
    const isDriver = driverData && (bookingCheck.driver_id === driverData.id);
    const isAdmin = req.user.role === 'admin';

    if (!isClient && !isDriver && !isAdmin) {
      return res.status(403).json({ success: false, message: 'You are not authorized to send messages in this booking' });
    }

    const resolvedRole = sender_role || (isDriver ? 'driver' : 'client');

    const { data: chatMessage, error } = await supabase
      .from('booking_messages')
      .insert({
        booking_id: bookingId,
        sender_id: userId,
        sender_role: resolvedRole,
        message: message.trim(),
        attachment_url: attachment_url || null,
        is_read: false
      })
      .select()
      .single();

    if (error) throw error;

    // NOTE: We intentionally DO NOT update bookings.additional_details here
    // to prevent race conditions that overwrite critical escrow/financial fields (dp_paid, escrow_balance)
    // and to eliminate database row bloat (TOAST table expansion).

    res.status(201).json({
      success: true,
      message: 'Message sent successfully',
      data: chatMessage
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get chat messages for a booking
// @route   GET /api/bookings/:bookingId/messages
// @access  Private (Client, Driver, or Admin)
exports.getChatMessages = async (req, res, next) => {
  try {
    const { bookingId } = req.params;
    const userId = req.user.id;

    // Verify booking and participant authorization
    const { data: bookingCheck, error: bookingErr } = await supabase
      .from('bookings')
      .select('id, user_id, driver_id')
      .eq('id', bookingId)
      .single();

    if (bookingErr || !bookingCheck) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    const { data: driverData } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();

    const isClient = bookingCheck.user_id === userId;
    const isDriver = driverData && (bookingCheck.driver_id === driverData.id);
    const isAdmin = req.user.role === 'admin';

    if (!isClient && !isDriver && !isAdmin) {
      return res.status(403).json({ success: false, message: 'You are not authorized to view messages in this booking' });
    }

    const { data: messages, error } = await supabase
      .from('booking_messages')
      .select('*')
      .eq('booking_id', bookingId)
      .order('created_at', { ascending: true });

    if (error) throw error;

    res.status(200).json({
      success: true,
      data: messages || []
    });
  } catch (error) {
    next(error);
  }
};
