// backend/src/services/escrowService.js
const { supabaseAdmin } = require('../config/supabase');
const { atomicIncrementBalance } = require('../utils/balanceHelper');

// Active per-booking locks to serialize concurrent payout requests
const activeBookingPayoutLocks = new Map();

/**
 * Escrow & Payout Service
 * Handles escrow holding and single-execution driver payout (90% driver / 10% platform commission)
 */
class EscrowService {
  /**
   * Safe helper to update booking in Supabase.
   * If column 'escrow_balance' or 'payout_status' does not yet exist in PostgreSQL schema cache,
   * it gracefully falls back to storing them in additional_details JSONB without crashing.
   */
  async safeUpdateBooking(bookingId, payload) {
    try {
      const { data, error } = await supabaseAdmin
        .from('bookings')
        .update(payload)
        .eq('id', bookingId)
        .select()
        .single();

      if (error) {
        const isColumnMissing = 
          error.code === 'PGRST204' || 
          error.code === '42703' || 
          (error.message && (
            error.message.includes('schema cache') || 
            error.message.includes('column') || 
            error.message.includes('escrow_balance') || 
            error.message.includes('payout_status')
          ));

        if (isColumnMissing) {
          console.warn('⚠️ Top-level escrow columns missing in DB table. Falling back to additional_details JSONB.');
          const fallbackPayload = { ...payload };
          delete fallbackPayload.escrow_balance;
          delete fallbackPayload.payout_status;

          const { data: fallbackData, error: fallbackError } = await supabaseAdmin
            .from('bookings')
            .update(fallbackPayload)
            .eq('id', bookingId)
            .select()
            .single();

          if (fallbackError) throw fallbackError;
          return fallbackData;
        }
        throw error;
      }
      return data;
    } catch (err) {
      console.error(`Error updating booking ${bookingId}:`, err);
      throw err;
    }
  }

  /**
   * Record a client payment (DP or Pelunasan) into Escrow
   */
  async holdPaymentInEscrow({ booking, payAmount, isPelunasan, paymentType }) {
    const currentEscrow = parseFloat(booking.escrow_balance) || parseFloat(booking.additional_details?.escrow_balance) || 0;
    const newEscrowBalance = currentEscrow + payAmount;

    const addDetails = (booking.additional_details && typeof booking.additional_details === 'object')
      ? { ...booking.additional_details }
      : {};

    addDetails.escrow_balance = newEscrowBalance;

    if (isPelunasan) {
      addDetails.sub_status = 'paid';
      addDetails.final_paid = true;
      addDetails.pelunasan_paid = true;
    } else {
      addDetails.sub_status = 'dp_paid';
      addDetails.dp_paid = true;
    }

    const currentPayoutStatus = booking.payout_status || addDetails.payout_status || 'held';
    addDetails.payout_status = currentPayoutStatus;

    const newDbStatus = isPelunasan 
      ? 'completed' 
      : (booking.driver_id ? 'ongoing' : 'pending');

    const platformFeeFromThis = payAmount * 0.10;
    const totalPlatformFee = (parseFloat(booking.platform_fee) || 0) + platformFeeFromThis;

    const updatePayload = {
      status: newDbStatus,
      platform_fee: totalPlatformFee,
      escrow_balance: newEscrowBalance,
      payout_status: currentPayoutStatus,
      additional_details: addDetails,
      updated_at: new Date().toISOString()
    };

    const updatedBooking = await this.safeUpdateBooking(booking.id, updatePayload);
    console.log(`🔒 [Escrow] Held Rp ${payAmount.toLocaleString('id-ID')} in escrow for Booking #${booking.id.substring(0, 8)} (Total Escrow: Rp ${newEscrowBalance.toLocaleString('id-ID')}, Type: ${paymentType || (isPelunasan ? 'Pelunasan' : 'DP')})`);
    return updatedBooking;
  }

  /**
   * Release driver payout (90% share) exactly ONCE upon order completion
   * Idempotent & race-condition proof using per-booking serialization lock and optimistic concurrency
   */
  /**
   * Release driver payout (90% share) exactly ONCE upon order completion
   * Bulletproof architecture:
   * 1. Tier 1: PostgreSQL Atomic Stored Procedure (process_driver_payout_atomic) with row-level lock (SELECT FOR UPDATE)
   * 2. Tier 2: Distributed Database CAS Lock (Compare-And-Swap) in PostgreSQL + Inverted Transactional Order (Balance credited first, with automatic compensation/rollback if failed)
   */
  async releaseDriverPayout(bookingId, bookingData = null, triggerSource = 'System') {
    // 🛡️ TIER 1: PostgreSQL Atomic Stored Procedure with Row-Level Locking (SELECT ... FOR UPDATE)
    // Multi-instance / Docker / PM2 cluster safe: PostgreSQL engine handles distributed row serialization.
    try {
      const { data: rpcData, error: rpcError } = await supabaseAdmin.rpc('process_driver_payout_atomic', {
        p_booking_id: bookingId,
        p_trigger_source: triggerSource
      });

      if (!rpcError && rpcData && typeof rpcData === 'object') {
        if (rpcData.already_released) {
          console.log(`ℹ️ [Escrow Payout] Payout for Booking #${bookingId.substring(0, 8)} was ALREADY released previously (Atomic RPC). Skipping duplicate payout.`);
          return {
            success: true,
            alreadyReleased: true,
            message: 'Payout has already been released to driver'
          };
        }

        if (rpcData.success) {
          console.log(`✅ [Escrow Payout] SUCCESS (Atomic RPC): Credited Rp ${Number(rpcData.driver_income).toLocaleString('id-ID')} to Driver ${rpcData.driver_user_id} for Booking #${bookingId.substring(0, 8)} [Trigger: ${triggerSource}]`);
          return {
            success: true,
            alreadyReleased: false,
            driverIncome: Number(rpcData.driver_income),
            driverUserId: rpcData.driver_user_id,
            message: rpcData.message || `Bagi hasil sebesar Rp ${Number(rpcData.driver_income).toLocaleString('id-ID')} berhasil dicairkan ke saldo driver`
          };
        } else {
          console.warn(`⚠️ [Escrow Payout Guard] Atomic RPC declined payout for Booking #${bookingId.substring(0, 8)}: ${rpcData.message || rpcData.reason}`);
          return {
            success: false,
            status: rpcData.status || 'held',
            reason: rpcData.reason || 'REJECTED',
            message: rpcData.message || 'Pencairan tidak memenuhi syarat'
          };
        }
      }
    } catch (rpcErr) {
      // If RPC not found (e.g. pending DB migration), proceed seamlessly to Tier 2
      console.warn(`ℹ️ [Escrow Payout] Atomic RPC not deployed or unavailable (${rpcErr.message}). Engaging Tier-2 Distributed CAS Transaction engine.`);
    }

    // 🛡️ TIER 2: Distributed CAS (Compare-And-Swap) Database Transaction Engine with Inverted Safe Ordering
    // Multi-instance lock is acquired directly in PostgreSQL table 'bookings'.
    while (activeBookingPayoutLocks.has(bookingId)) {
      await activeBookingPayoutLocks.get(bookingId);
    }
    let releaseLock;
    const lockPromise = new Promise(resolve => { releaseLock = resolve; });
    activeBookingPayoutLocks.set(bookingId, lockPromise);

    try {
      // 1. Fetch fresh booking record
      const { data: freshBooking, error: fetchErr } = await supabaseAdmin
        .from('bookings')
        .select('*')
        .eq('id', bookingId)
        .single();

      if (fetchErr || !freshBooking) {
        console.error(`[Escrow Payout] Booking #${bookingId} not found`);
        return { success: false, message: 'Booking not found' };
      }
      const booking = freshBooking;

      const addDetails = (booking.additional_details && typeof booking.additional_details === 'object')
        ? { ...booking.additional_details }
        : {};

      const currentPayoutStatus = booking.payout_status || addDetails.payout_status;
      const isAlreadyCredited = currentPayoutStatus === 'released' || addDetails.driver_credited === true;

      if (isAlreadyCredited) {
        console.log(`ℹ️ [Escrow Payout] Payout for Booking #${bookingId.substring(0, 8)} was ALREADY released previously. Skipping duplicate payout.`);
        return {
          success: true,
          alreadyReleased: true,
          message: 'Payout has already been released to driver'
        };
      }

      if (!booking.driver_id) {
        return { success: false, message: 'No driver assigned to this booking' };
      }

      if (booking.status === 'cancelled') {
        return { success: false, message: 'Pesanan telah dibatalkan, bagi hasil driver tidak dapat dicairkan' };
      }

      // 2. Validate Pelunasan & Escrow Balance
      const isPelunasanVerified = 
        addDetails.pelunasan_paid === true || 
        addDetails.final_paid === true || 
        booking.sub_status === 'paid' || 
        booking.sub_status === 'closed' ||
        addDetails.sub_status === 'paid' || 
        addDetails.sub_status === 'closed';

      const totalPrice = parseFloat(booking.total_price) || parseFloat(booking.escrow_balance) || parseFloat(addDetails.escrow_balance) || 0;
      const currentEscrow = parseFloat(booking.escrow_balance) || parseFloat(addDetails.escrow_balance) || 0;
      const driverIncome = totalPrice * 0.90;

      if (!isPelunasanVerified) {
        console.warn(`⚠️ [Escrow Payout Held] Tidak dapat mencairkan bagi hasil driver untuk pesanan #${bookingId.substring(0, 8)}. Klien belum menyelesaikan pelunasan (Status: ${booking.status}/${booking.sub_status || addDetails.sub_status}, DP Paid: ${addDetails.dp_paid}, Pelunasan Paid: ${addDetails.pelunasan_paid}). Dana tetap aman di Escrow.`);
        return {
          success: false,
          status: 'held',
          reason: 'WAITING_PELUNASAN',
          message: 'Pelunasan belum diselesaikan oleh klien. Dana bagi hasil driver tetap aman tertahan di escrow hingga pelunasan lunas.'
        };
      }

      if (currentEscrow < (driverIncome - 1)) {
        console.error(`🚨 [Escrow Payout Deficit Blocked] Percobaan pencairan dana driver melebihi saldo escrow untuk pesanan #${bookingId.substring(0, 8)}! Saldo Escrow: Rp ${currentEscrow.toLocaleString('id-ID')}, Dibutuhkan Driver: Rp ${driverIncome.toLocaleString('id-ID')}. Pencairan dibatalkan demi keamanan kas perusahaan.`);
        return {
          success: false,
          status: 'held',
          reason: 'INSUFFICIENT_ESCROW',
          message: `Saldo escrow (Rp ${currentEscrow.toLocaleString('id-ID')}) tidak mencukupi untuk pembayaran bagi hasil driver (Rp ${driverIncome.toLocaleString('id-ID')}). Pencairan dibatalkan.`
        };
      }

      if (driverIncome <= 0) {
        console.warn(`⚠️ [Escrow Payout] Driver income calculated as 0 for Booking #${bookingId}`);
        return { success: false, message: 'Nilai bagi hasil driver tidak valid (<= 0)' };
      }

      // 3. Fetch driver
      const { data: driver, error: driverErr } = await supabaseAdmin
        .from('drivers')
        .select('id, user_id')
        .eq('id', booking.driver_id)
        .maybeSingle();

      if (driverErr || !driver || !driver.user_id) {
        return { success: false, message: 'Driver record not found' };
      }

      // 🛡️ 4. DISTRIBUTED DATABASE-LEVEL CAS LOCK ACQUISITION
      // Atomically transition status to 'processing' across all instances in PostgreSQL!
      const lockAcquiredAt = new Date().toISOString();
      const claimPayload = {
        payout_status: 'processing',
        updated_at: lockAcquiredAt
      };
      const claimDetails = { ...addDetails, payout_status: 'processing', payout_claimed_at: lockAcquiredAt };
      claimPayload.additional_details = claimDetails;

      const { data: lockResult, error: lockClaimError } = await supabaseAdmin
        .from('bookings')
        .update(claimPayload)
        .eq('id', bookingId)
        .neq('payout_status', 'released')
        .neq('payout_status', 'processing')
        .select()
        .maybeSingle();

      // If lock was not acquired (another instance claimed or released it)
      if (lockClaimError || !lockResult) {
        const { data: checkBooking } = await supabaseAdmin
          .from('bookings')
          .select('payout_status, additional_details')
          .eq('id', bookingId)
          .single();

        const latestStatus = checkBooking?.payout_status || checkBooking?.additional_details?.payout_status;
        if (latestStatus === 'released' || checkBooking?.additional_details?.driver_credited === true) {
          return {
            success: true,
            alreadyReleased: true,
            message: 'Payout has already been released to driver'
          };
        }

        console.warn(`🔒 [Distributed Lock] Booking #${bookingId.substring(0, 8)} sedang diproses oleh worker lain.`);
        return {
          success: false,
          status: 'held',
          reason: 'CONCURRENT_PROCESSING',
          message: 'Transaksi pencairan sedang diproses oleh worker lain. Silakan tunggu.'
        };
      }

      // 🛡️ 5. INVERTED SAFE ORDER: UPDATE DRIVER BALANCE FIRST
      // Booking is NOT marked released yet. If balance credit fails or DB disconnects, booking is NEVER falsely marked released!
      let balanceUpdated = false;
      let finalDriverBalance = 0;

      try {
        finalDriverBalance = await atomicIncrementBalance(driver.user_id, driverIncome);
        balanceUpdated = true;
      } catch (incErr) {
        console.error(`❌ [Escrow Payout] Gagal menambah saldo driver secara atomik:`, incErr.message);
      }

      // 🛡️ 6. AUTOMATIC COMPENSATION / ROLLBACK IF BALANCE UPDATE FAILS
      if (!balanceUpdated) {
        console.error(`❌ [Escrow Payout] Gagal memperbarui saldo driver untuk Booking #${bookingId}. Menjalankan rollback status escrow ke 'held'.`);
        claimDetails.payout_status = 'held';
        delete claimDetails.payout_claimed_at;
        await this.safeUpdateBooking(bookingId, {
          payout_status: 'held',
          additional_details: claimDetails,
          updated_at: new Date().toISOString()
        });
        return {
          success: false,
          message: 'Gagal memperbarui saldo driver. Transaksi berhasil di-rollback ke status held untuk dicoba kembali.'
        };
      }

      // 🛡️ 7. DRIVER BALANCE CONFIRMED CREDITED: Now finalize booking record as 'released'
      claimDetails.driver_credited = true;
      claimDetails.payout_status = 'released';
      claimDetails.payout_amount = driverIncome;
      claimDetails.payout_at = new Date().toISOString();
      claimDetails.payout_trigger = triggerSource;

      const finalizePayload = {
        payout_status: 'released',
        escrow_balance: 0,
        additional_details: claimDetails,
        updated_at: new Date().toISOString()
      };

      await this.safeUpdateBooking(bookingId, finalizePayload);

      // 8. Record wallet transaction mutation audit
      try {
        await supabaseAdmin.from('wallet_transactions').insert({
          user_id: driver.user_id,
          type: 'trip_income',
          amount: driverIncome,
          description: `Pendapatan pesanan #${bookingId.substring(0, 8)} (${triggerSource})`,
          reference_id: bookingId
        });
      } catch (wtErr) {
        console.warn('⚠️ [Escrow Payout] wallet_transactions insert warning:', wtErr.message);
      }

      console.log(`✅ [Escrow Payout] SUCCESS (Distributed CAS): Credited Rp ${driverIncome.toLocaleString('id-ID')} to Driver ${driver.user_id} for Booking #${bookingId.substring(0, 8)} [Trigger: ${triggerSource}]`);

      return {
        success: true,
        alreadyReleased: false,
        driverIncome,
        driverUserId: driver.user_id,
        message: `Bagi hasil sebesar Rp ${driverIncome.toLocaleString('id-ID')} berhasil dicairkan ke saldo driver`
      };
    } catch (error) {
      console.error(`❌ [Escrow Payout] Error releasing payout for booking ${bookingId}:`, error);
      return {
        success: false,
        message: 'Gagal mencairkan saldo driver: ' + error.message
      };
    } finally {
      activeBookingPayoutLocks.delete(bookingId);
      if (releaseLock) releaseLock();
    }
  }

  /**
   * Handle Escrow Settlement upon Booking Cancellation
   * 
   * Fair Policy:
   * 1. CANCELLED BY CLIENT (Penumpang):
   *    - Client broke commitment after driver locked schedule / prepared.
   *    - Escrow (DP) is NON-REFUNDABLE to client.
   *    - 50% Driver Compensation credited to driver's balance (users.balance) + wallet_transactions (DP_FORFEIT_COMPENSATION).
   *    - 50% Platform cancellation fee.
   *    - Escrow balance becomes 0, payout_status = 'forfeited'.
   * 
   * 2. CANCELLED BY DRIVER (Mitra Driver):
   *    - Driver broke commitment. Client is not at fault.
   *    - 100% of Escrow (DP) is REFUNDED to client's balance (users.balance) + wallet_transactions (REFUND).
   *    - Driver receives Rp 0.
   *    - Escrow balance becomes 0, payout_status = 'refunded'.
   * 
   * 3. CANCELLED BY ADMIN:
   *    - Defaults to 100% refund to client (unless admin specified forfeit).
   * 
   * 4. IF ESCROW == 0 (No DP was paid yet):
   *    - No financial transfers needed.
   *    - payout_status = 'cancelled'.
   */
  async handleBookingCancellation({ bookingId, cancelledBy, reason = 'Dibatalkan', actorId = null }) {
    try {
      console.log(`🔍 [Escrow Cancel] Processing cancellation settlement for Booking #${bookingId.substring(0, 8)} (Cancelled By: ${cancelledBy})`);

      const { data: booking, error: fetchErr } = await supabaseAdmin
        .from('bookings')
        .select('*, drivers(id, user_id)')
        .eq('id', bookingId)
        .single();

      if (fetchErr || !booking) {
        console.error(`❌ [Escrow Cancel] Booking #${bookingId} not found:`, fetchErr);
        return { success: false, message: 'Pesanan tidak ditemukan' };
      }

      const currentEscrow = parseFloat(booking.escrow_balance || booking.additional_details?.escrow_balance || 0);
      const currentPayoutStatus = booking.payout_status || booking.additional_details?.payout_status || 'held';

      // Idempotency: If already finalized, refunded, or released, do not process financial transfers again
      if (['released', 'refunded', 'forfeited'].includes(currentPayoutStatus) || currentEscrow <= 0) {
        console.log(`ℹ️ [Escrow Cancel] Booking #${bookingId.substring(0, 8)} has no active escrow funds or already settled (Escrow: Rp ${currentEscrow}, Status: ${currentPayoutStatus}).`);
        
        const addDetails = { ...(booking.additional_details || {}) };
        addDetails.cancelled_by = cancelledBy;
        addDetails.cancellation_reason = reason;
        addDetails.cancelled_at = new Date().toISOString();

        await this.safeUpdateBooking(bookingId, {
          status: 'cancelled',
          payout_status: currentPayoutStatus === 'held' ? 'cancelled' : currentPayoutStatus,
          additional_details: addDetails,
          updated_at: new Date().toISOString()
        });

        return {
          success: true,
          escrowSettled: false,
          action: 'NO_FUNDS',
          message: 'Pesanan dibatalkan tanpa pergeseran dana (belum ada DP).'
        };
      }

      // Determine driver user ID
      const driverUserId = booking.drivers?.user_id;

      if (cancelledBy === 'driver') {
        // =========================================================================
        // CASE A: DRIVER MEMBATALKAN -> 100% REFUND PENUH KE SALDO PENUMPANG
        // =========================================================================
        console.log(`🚨 [Escrow Cancel] Driver cancelled Booking #${bookingId.substring(0, 8)}. Refunding 100% (Rp ${currentEscrow.toLocaleString('id-ID')}) to Client ${booking.user_id}`);

        // 1. Tambah saldo ke akun client di users.balance secara atomik
        const newClientBal = await atomicIncrementBalance(booking.user_id, currentEscrow);

        // 2. Catat mutasi REFUND di wallet_transactions client
        try {
          const { error: wtErr } = await supabaseAdmin.from('wallet_transactions').insert([{
            user_id: booking.user_id,
            type: 'REFUND',
            amount: currentEscrow,
            description: `Pengembalian dana 100% DP karena driver membatalkan pesanan #${bookingId.substring(0, 8)}`,
            reference_id: bookingId,
            created_at: new Date().toISOString()
          }]);
          if (wtErr) {
            console.error('❌ Failed to insert refund wallet_transaction:', wtErr.message);
          }
        } catch (wtErr) {
          console.warn('Refund wallet_transaction warning:', wtErr.message);
        }

        // 3. Update booking status
        const addDetails = { ...(booking.additional_details || {}) };
        addDetails.cancelled_by = 'driver';
        addDetails.cancellation_reason = reason;
        addDetails.refund_to_client = currentEscrow;
        addDetails.cancelled_at = new Date().toISOString();

        await this.safeUpdateBooking(bookingId, {
          status: 'cancelled',
          payout_status: 'refunded',
          escrow_balance: 0,
          additional_details: addDetails,
          updated_at: new Date().toISOString()
        });

        // 4. Update payment_transactions jika ada
        await supabaseAdmin
          .from('payment_transactions')
          .update({
            status: 'REJECTED',
            admin_notes: `Dibatalkan oleh Driver: ${reason}. DP Rp ${currentEscrow.toLocaleString('id-ID')} dikembalikan penuh ke saldo client.`,
            processed_at: new Date().toISOString()
          })
          .eq('booking_id', bookingId);

        return {
          success: true,
          escrowSettled: true,
          action: 'FULL_REFUND_TO_CLIENT',
          refundAmount: currentEscrow,
          message: `Driver membatalkan pesanan. Dana DP sebesar Rp ${currentEscrow.toLocaleString('id-ID')} telah dikembalikan 100% ke saldo dompet penumpang.`
        };

      } else {
        // =========================================================================
        // CASE B: CLIENT MEMBATALKAN -> DP HANGUS: 50% DRIVER / 50% KAS PLATFORM
        // =========================================================================
        const driverShare = Math.round(currentEscrow * 0.5);
        const platformShare = currentEscrow - driverShare;

        console.log(`🚨 [Escrow Cancel] Client cancelled Booking #${bookingId.substring(0, 8)}. DP Hangus: Rp ${driverShare.toLocaleString('id-ID')} to Driver, Rp ${platformShare.toLocaleString('id-ID')} to Platform`);

        // 1. Jika driver sudah ditentukan, kreditkan kompensasi 50% ke saldo driver secara atomik
        if (driverUserId) {
          const newDrvBal = await atomicIncrementBalance(driverUserId, driverShare);

          // Catat mutasi DP_FORFEIT_COMPENSATION di wallet_transactions driver
          try {
            const { error: wtErr } = await supabaseAdmin.from('wallet_transactions').insert([{
              user_id: driverUserId,
              type: 'DP_FORFEIT_COMPENSATION',
              amount: driverShare,
              description: `Kompensasi pembatalan sepihak pesanan #${bookingId.substring(0, 8)} oleh penumpang (50% DP)`,
              reference_id: bookingId,
              created_at: new Date().toISOString()
            }]);
            if (wtErr) {
              console.error('❌ Failed to insert forfeit compensation wallet_transaction:', wtErr.message);
            }
          } catch (wtErr) {
            console.warn('Forfeit wallet_transaction warning:', wtErr.message);
          }

          // Catat audit log di revenue_split_logs
          try {
            await supabaseAdmin.from('revenue_split_logs').insert([{
              booking_id: bookingId,
              total_amount: currentEscrow,
              driver_id: driverUserId,
              driver_share: driverShare,
              driver_percentage: 50.00,
              system_share: platformShare,
              system_percentage: 50.00,
              split_type: 'DP_CANCEL_FORFEIT',
              created_at: new Date().toISOString()
            }]);
          } catch (rslErr) {
            // Table optional
          }
        }

        // 2. Update booking status
        const addDetails = { ...(booking.additional_details || {}) };
        addDetails.cancelled_by = cancelledBy || 'client';
        addDetails.cancellation_reason = reason;
        addDetails.driver_forfeit_compensation = driverShare;
        addDetails.platform_forfeit_share = platformShare;
        addDetails.cancelled_at = new Date().toISOString();

        await this.safeUpdateBooking(bookingId, {
          status: 'cancelled',
          payout_status: 'forfeited',
          escrow_balance: 0,
          additional_details: addDetails,
          updated_at: new Date().toISOString()
        });

        // 3. Update payment_transactions jika ada
        await supabaseAdmin
          .from('payment_transactions')
          .update({
            status: 'FORFEITED',
            admin_notes: `Dibatalkan oleh Penumpang: ${reason}. DP Rp ${currentEscrow.toLocaleString('id-ID')} dibagi 50% Driver dan 50% Sistem.`,
            processed_at: new Date().toISOString()
          })
          .eq('booking_id', bookingId);

        return {
          success: true,
          escrowSettled: true,
          action: 'FORFEIT_SPLIT_50_50',
          driverShare,
          platformShare,
          message: `Pesanan dibatalkan penumpang. DP hangus: Rp ${driverShare.toLocaleString('id-ID')} kompensasi ke saldo driver, Rp ${platformShare.toLocaleString('id-ID')} ke kas platform.`
        };
      }
    } catch (error) {
      console.error(`❌ [Escrow Cancel] Error processing cancellation for booking ${bookingId}:`, error);
      return { success: false, message: error.message };
    }
  }
}

module.exports = new EscrowService();
