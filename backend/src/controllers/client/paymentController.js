// backend/src/controllers/client/paymentController.js
const { supabaseAdmin } = require('../../config/supabase');
const escrowService = require('../../services/escrowService');
const xenditService = require('../../services/xenditService');
const { ensureAuthUser } = require('../../utils/authSync');
const { atomicDeductBalance } = require('../../utils/balanceHelper');

class PaymentController {
  /**
   * Get all payment methods for user from Supabase DB
   */
  async getPaymentMethods(req, res) {
    try {
      const userId = req.user.id;

      // 1. Fetch user payment methods from Supabase
      const { data: methods, error } = await supabaseAdmin
        .from('user_payment_methods')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: true });

      if (error) throw error;

      // If no methods exist for user yet, seed default ones into Supabase DB
      if (!methods || methods.length === 0) {
        const defaultMethods = [
          {
            user_id: userId,
            method_type: 'Virtual Account',
            provider: 'BCA',
            last_four: '8839',
            is_default: true,
            created_at: new Date()
          },
          {
            user_id: userId,
            method_type: 'E-Wallet',
            provider: 'GoPay',
            last_four: null,
            is_default: false,
            created_at: new Date()
          }
        ];

        const { data: seeded, error: seedError } = await supabaseAdmin
          .from('user_payment_methods')
          .insert(defaultMethods)
          .select();

        if (!seedError && seeded) {
          console.log(`\n💳 Seeded initial payment methods in Supabase for user: ${userId}`);
          return res.status(200).json({
            success: true,
            message: 'Payment methods retrieved successfully',
            data: seeded
          });
        }
      }

      console.log(`\n💳 Retrieved ${methods?.length || 0} payment methods from Supabase for user: ${userId}`);

      res.status(200).json({
        success: true,
        message: 'Payment methods retrieved successfully',
        data: methods || []
      });
    } catch (error) {
      console.error('Get payment methods error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to retrieve payment methods: ' + error.message
      });
    }
  }

  /**
   * Add a new payment method to Supabase DB
   */
  async addPaymentMethod(req, res) {
    try {
      const userId = req.user.id;
      const { method_type, provider } = req.body;

      if (!method_type || !provider) {
        return res.status(400).json({
          success: false,
          message: 'method_type and provider are required'
        });
      }

      // Check existing methods to set is_default
      const { data: existingMethods } = await supabaseAdmin
        .from('user_payment_methods')
        .select('id')
        .eq('user_id', userId);

      const isFirstMethod = !existingMethods || existingMethods.length === 0;

      // Generate last_four if Virtual Account or Credit Card
      let last_four = null;
      if (method_type.toLowerCase().includes('card') || method_type.toLowerCase().includes('account')) {
        last_four = Math.floor(1000 + Math.random() * 9000).toString();
      }

      const { data: newMethod, error } = await supabaseAdmin
        .from('user_payment_methods')
        .insert({
          user_id: userId,
          method_type,
          provider,
          last_four,
          is_default: isFirstMethod,
          created_at: new Date()
        })
        .select()
        .single();

      if (error) throw error;

      console.log(`➕ Added payment method in Supabase for user ${userId}: ${provider} (${method_type})`);

      res.status(201).json({
        success: true,
        message: 'Payment method added successfully',
        data: newMethod
      });
    } catch (error) {
      console.error('Add payment method error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to add payment method: ' + error.message
      });
    }
  }

  /**
   * Remove a payment method from Supabase DB
   */
  async removePaymentMethod(req, res) {
    try {
      const userId = req.user.id;
      const { methodId } = req.params;

      // Fetch the target method first to see if it was default
      const { data: targetMethod, error: fetchErr } = await supabaseAdmin
        .from('user_payment_methods')
        .select('*')
        .eq('id', methodId)
        .eq('user_id', userId)
        .maybeSingle();

      if (fetchErr || !targetMethod) {
        return res.status(404).json({
          success: false,
          message: 'Payment method not found'
        });
      }

      const { error: deleteErr } = await supabaseAdmin
        .from('user_payment_methods')
        .delete()
        .eq('id', methodId)
        .eq('user_id', userId);

      if (deleteErr) throw deleteErr;

      // If removed method was default, promote another remaining method to default
      if (targetMethod.is_default) {
        const { data: remaining } = await supabaseAdmin
          .from('user_payment_methods')
          .select('id')
          .eq('user_id', userId)
          .limit(1);

        if (remaining && remaining.length > 0) {
          await supabaseAdmin
            .from('user_payment_methods')
            .update({ is_default: true, updated_at: new Date() })
            .eq('id', remaining[0].id);
        }
      }

      console.log(`🗑️ Removed payment method ${methodId} from Supabase for user ${userId}`);

      res.status(200).json({
        success: true,
        message: 'Payment method removed successfully'
      });
    } catch (error) {
      console.error('Remove payment method error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to remove payment method: ' + error.message
      });
    }
  }

  /**
   * Set payment method as default in Supabase DB
   */
  async setDefaultPaymentMethod(req, res) {
    try {
      const userId = req.user.id;
      const { methodId } = req.params;

      // Verify method exists for user
      const { data: methodExists } = await supabaseAdmin
        .from('user_payment_methods')
        .select('id')
        .eq('id', methodId)
        .eq('user_id', userId)
        .maybeSingle();

      if (!methodExists) {
        return res.status(404).json({
          success: false,
          message: 'Payment method not found'
        });
      }

      // Reset all user's payment methods to is_default = false
      await supabaseAdmin
        .from('user_payment_methods')
        .update({ is_default: false, updated_at: new Date() })
        .eq('user_id', userId);

      // Set target method is_default = true
      await supabaseAdmin
        .from('user_payment_methods')
        .update({ is_default: true, updated_at: new Date() })
        .eq('id', methodId)
        .eq('user_id', userId);

      console.log(`⭐ Set default payment method to ${methodId} in Supabase for user ${userId}`);

      res.status(200).json({
        success: true,
        message: 'Default payment method updated successfully'
      });
    } catch (error) {
      console.error('Set default payment method error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to set default payment method: ' + error.message
      });
    }
  }

  /**
   * Process payment for booking (DP or Pelunasan) using Wallet or Card/VA
   */
  async processPayment(req, res) {
    try {
      const userId = req.user.id;
      const { booking_id, amount, payment_type, use_wallet = true } = req.body;

      if (!booking_id || !amount || amount <= 0) {
        return res.status(400).json({
          success: false,
          message: 'booking_id dan amount yang valid wajib diisi'
        });
      }

      // Fetch booking
      const { data: booking, error: bookingErr } = await supabaseAdmin
        .from('bookings')
        .select('*')
        .eq('id', booking_id)
        .single();

      if (bookingErr || !booking) {
        return res.status(404).json({
          success: false,
          message: 'Booking tidak ditemukan'
        });
      }

      // 🛡️ PERIKSA KEPEMILIKAN PESANAN
      if (booking.user_id !== userId && req.user.role !== 'admin') {
        return res.status(403).json({
          success: false,
          message: 'Anda tidak memiliki otorisasi untuk membayar pesanan ini'
        });
      }

      const addDetails = booking.additional_details || {};
      const isPelunasan = payment_type === 'pelunasan' || payment_type === 'full';

      // 🛡️ Proteksi Double Payment (Idempotensi)
      if (isPelunasan && (addDetails.pelunasan_paid === true || addDetails.final_paid === true)) {
        return res.status(400).json({
          success: false,
          message: 'Pelunasan untuk pesanan ini sudah pernah diproses.'
        });
      }
      if (!isPelunasan && addDetails.dp_paid === true) {
        return res.status(400).json({
          success: false,
          message: 'DP untuk pesanan ini sudah pernah dibayar.'
        });
      }

      const payAmount = parseFloat(amount);

      // 🛡️ PERBAIKAN ISU A: Cegah eksploitasi pembayaran fiktif / free payment
      // Jika use_wallet bernilai false, jangan izinkan pengisian escrow otomatis tanpa payment gateway aktif
      if (use_wallet === false || use_wallet === 'false') {
        return res.status(400).json({
          success: false,
          message: 'Metode pembayaran non-wallet saat ini belum terhubung dengan gateway otomatis. Harap gunakan saldo wallet Anda untuk pembayaran instan.'
        });
      }

      // 1. Deduct wallet balance secara atomik dengan Optimistic Concurrency Control (OCC) & Retry
      // 🛡️ Pemotongan Saldo Atomik via PostgreSQL RPC / OCC CAS
      try {
        await atomicDeductBalance(userId, payAmount);
      } catch (deductErr) {
        if (deductErr.message === 'INSUFFICIENT_BALANCE') {
          return res.status(400).json({
            success: false,
            message: `Saldo wallet tidak mencukupi untuk melakukan pembayaran sebesar Rp ${payAmount.toLocaleString('id-ID')}`
          });
        }
        return res.status(400).json({
          success: false,
          message: 'Gagal memproses pemotongan saldo: ' + deductErr.message
        });
      }

      // Record mutation
      await supabaseAdmin.from('wallet_transactions').insert({
        user_id: userId,
        type: 'withdrawal',
        amount: payAmount,
        description: `Pembayaran ${payment_type || 'DP'} pesanan #${booking_id.substring(0, 8)}`,
        reference_id: booking_id
      });

      // 2. Hold payment in Escrow Vault (No direct driver payout during DP!)
      const updatedBooking = await escrowService.holdPaymentInEscrow({
        booking,
        payAmount,
        isPelunasan,
        paymentType: payment_type
      });

      // 3. If Pelunasan (order reaches final completed), release 90% Driver Payout EXACTLY ONCE
      if (isPelunasan && booking.driver_id) {
        await escrowService.releaseDriverPayout(
          booking_id, 
          updatedBooking, 
          'Pelunasan / Final Completed'
        );
      }

      res.status(200).json({
        success: true,
        message: `Pembayaran ${isPelunasan ? 'pelunasan' : 'DP'} sebesar Rp ${payAmount.toLocaleString('id-ID')} berhasil diproses! ${isPelunasan ? 'Dana telah dicairkan ke saldo driver.' : 'Dana diamankan di Escrow.'}`,
        data: updatedBooking
      });
    } catch (error) {
      console.error('Process payment error:', error);
      res.status(500).json({
        success: false,
        message: 'Gagal memproses pembayaran: ' + error.message
      });
    }
  }

  /**
   * Get wallet balance & transaction history
   */
  async getWalletHistory(req, res) {
    try {
      const userId = req.user.id;

      const { data: user } = await supabaseAdmin
        .from('users')
        .select('balance, points')
        .eq('id', userId)
        .single();

      const { data: transactions, error } = await supabaseAdmin
        .from('wallet_transactions')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });

      if (error) throw error;

      res.status(200).json({
        success: true,
        data: {
          balance: parseFloat(user?.balance || 0),
          points: user?.points || 0,
          transactions: transactions || []
        }
      });
    } catch (error) {
      console.error('Get wallet history error:', error);
      res.status(500).json({
        success: false,
        message: 'Gagal mengambil riwayat transaksi: ' + error.message
      });
    }
  }

  /**
   * Submit manual payment (DP / Pelunasan) with transfer proof
   */
  async submitManualPayment(req, res) {
    try {
      const userId = req.user.id;
      const { 
        booking_id, 
        type = 'DP', 
        amount, 
        proof_url, 
        bank_name = 'Bank BCA', 
        account_number = '-', 
        account_name = '', 
        notes = '' 
      } = req.body;

      if (!booking_id) {
        return res.status(400).json({
          success: false,
          message: 'booking_id wajib disertakan'
        });
      }

      const trxType = type.toUpperCase();
      if (trxType !== 'DP' && trxType !== 'PELUNASAN') {
        return res.status(400).json({
          success: false,
          message: 'Tipe pembayaran tidak valid. Hanya menerima "DP" atau "PELUNASAN"'
        });
      }

      // 1. Ensure user auth record exists for FK consistency
      await ensureAuthUser(userId, req.user.email);

      // 2. Fetch booking and verify ownership
      const { data: booking, error: fetchErr } = await supabaseAdmin
        .from('bookings')
        .select('*')
        .eq('id', booking_id)
        .single();

      if (fetchErr || !booking) {
        return res.status(404).json({
          success: false,
          message: 'Pesanan tidak ditemukan'
        });
      }

      if (booking.user_id !== userId) {
        return res.status(403).json({
          success: false,
          message: 'Anda tidak memiliki hak akses untuk membayar pesanan ini'
        });
      }

      // Determine nominal amount
      const totalPrice = parseFloat(booking.total_price || 0);
      let payAmount = parseFloat(amount || 0);
      if (payAmount <= 0) {
        if (trxType === 'DP') {
          payAmount = booking.dp_amount ? parseFloat(booking.dp_amount) : Math.round(totalPrice * 0.3);
        } else {
          const alreadyPaidDp = booking.additional_details?.dp_amount || Math.round(totalPrice * 0.3);
          payAmount = Math.max(0, totalPrice - alreadyPaidDp);
        }
      }

      const uniqueCode = Math.floor(Math.random() * 899) + 100;
      const totalPayable = payAmount + uniqueCode;

      // 3. Insert transaction into payment_transactions
      const trxPayload = {
        booking_id: booking.id,
        user_id: userId,
        type: trxType,
        amount: payAmount,
        unique_code: uniqueCode,
        total_payable: totalPayable,
        proof_url: proof_url || null,
        status: 'PENDING',
        sla_deadline: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
        admin_notes: JSON.stringify({
          bank_name,
          account_number,
          account_name: account_name || req.user.full_name || 'Client',
          notes: notes || `Pengajuan Pembayaran Manual ${trxType}`
        })
      };

      const { data: newTrx, error: insErr } = await supabaseAdmin
        .from('payment_transactions')
        .insert([trxPayload])
        .select()
        .single();

      if (insErr) {
        console.error('Insert payment_transactions error:', insErr);
        return res.status(500).json({
          success: false,
          message: 'Gagal mencatat transaksi pembayaran: ' + insErr.message
        });
      }

      // 4. Update booking additional_details
      const addDetails = { ...(booking.additional_details || {}) };
      if (trxType === 'DP') {
        addDetails.dp_payment_status = 'waiting_admin_approval';
        addDetails.dp_amount = payAmount;
        addDetails.dp_proof_url = proof_url || null;
      } else {
        addDetails.pelunasan_payment_status = 'waiting_admin_approval';
        addDetails.pelunasan_amount = payAmount;
        addDetails.pelunasan_proof_url = proof_url || null;
      }

      await supabaseAdmin
        .from('bookings')
        .update({
          additional_details: addDetails,
          updated_at: new Date().toISOString()
        })
        .eq('id', booking_id);

      res.status(201).json({
        success: true,
        message: `Bukti transfer ${trxType} sebesar Rp ${payAmount.toLocaleString('id-ID')} berhasil dikirim ke Admin. Menunggu verifikasi / ACC.`,
        data: newTrx
      });
    } catch (error) {
      console.error('Submit manual payment error:', error);
      res.status(500).json({
        success: false,
        message: 'Gagal mengirim pembayaran manual: ' + error.message
      });
    }
  }

  /**
   * Submit manual wallet top-up request with transfer proof
   */
  async submitManualTopup(req, res) {
    try {
      const userId = req.user.id;
      const { amount, proof_url, bank_name = 'Bank BCA', account_number = '-', account_name = '', notes = '' } = req.body;

      const numAmount = parseFloat(amount || 0);
      if (isNaN(numAmount) || numAmount < 10000) {
        return res.status(400).json({
          success: false,
          message: 'Nominal top up minimal Rp 10.000'
        });
      }

      await ensureAuthUser(userId, req.user.email);

      const uniqueCode = Math.floor(Math.random() * 899) + 100;
      const totalPayable = numAmount + uniqueCode;

      const { data: newTrx, error: insErr } = await supabaseAdmin
        .from('payment_transactions')
        .insert([{
          user_id: userId,
          type: 'TOPUP',
          amount: numAmount,
          unique_code: uniqueCode,
          total_payable: totalPayable,
          proof_url: proof_url || null,
          status: 'PENDING',
          sla_deadline: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
          admin_notes: JSON.stringify({
            bank_name,
            account_number,
            account_name: account_name || req.user.full_name || 'Client',
            notes: notes || 'Pengajuan Top-Up Saldo Dompet Manual'
          })
        }])
        .select()
        .single();

      if (insErr) {
        console.error('Insert topup payment_transactions error:', insErr);
        return res.status(500).json({
          success: false,
          message: 'Gagal mengirim pengajuan top-up: ' + insErr.message
        });
      }

      res.status(201).json({
        success: true,
        message: `Pengajuan Top-Up sebesar Rp ${numAmount.toLocaleString('id-ID')} berhasil dikirim. Menunggu verifikasi admin.`,
        data: newTrx
      });
    } catch (error) {
      console.error('Submit manual topup error:', error);
      res.status(500).json({
        success: false,
        message: 'Gagal memproses top-up manual: ' + error.message
      });
    }
  }

  /**
   * Get pending transactions for the current user
   */
  async getPendingPayments(req, res) {
    try {
      const userId = req.user.id;
      const { data: transactions, error } = await supabaseAdmin
        .from('payment_transactions')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });

      if (error) throw error;

      res.status(200).json({
        success: true,
        data: transactions || []
      });
    } catch (error) {
      console.error('Get pending payments error:', error);
      res.status(500).json({
        success: false,
        message: 'Gagal mengambil daftar transaksi: ' + error.message
      });
    }
  }

  /**
   * Create Xendit QRIS Code for a booking
   */
  async createQrisPayment(req, res) {
    try {
      const userId = req.user.id;
      const { booking_id, amount, payment_type } = req.body;

      if (!booking_id || !amount) {
        return res.status(400).json({
          success: false,
          message: 'booking_id dan amount wajib diisi'
        });
      }

      // Fetch booking to verify ownership
      const { data: booking, error: bookingErr } = await supabaseAdmin
        .from('bookings')
        .select('*')
        .eq('id', booking_id)
        .single();

      if (bookingErr || !booking) {
        return res.status(404).json({
          success: false,
          message: 'Booking tidak ditemukan'
        });
      }

      if (booking.user_id !== userId && req.user.role !== 'admin') {
        return res.status(403).json({
          success: false,
          message: 'Otorisasi pembayaran ditolak'
        });
      }

      const externalId = `booking_${booking_id}_${payment_type || 'dp'}_${Date.now()}`;
      const qrisData = await xenditService.createQrisCode({
        bookingId: booking_id,
        amount: parseFloat(amount),
        externalId
      });

      // Record transaction status as PENDING in payment_transactions
      await supabaseAdmin.from('payment_transactions').insert([{
        booking_id: booking_id,
        user_id: userId,
        type: (payment_type || 'DP').toUpperCase(),
        amount: parseFloat(amount),
        unique_code: 0,
        total_payable: parseFloat(amount),
        status: 'PENDING',
        sla_deadline: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
        admin_notes: JSON.stringify({
          payment_gateway: 'Xendit',
          method: 'QRIS',
          qris_id: qrisData.id,
          qris_status: 'PENDING_QRIS',
          qr_string: qrisData.qr_string
        })
      }]);

      res.status(200).json({
        success: true,
        message: 'QRIS berhasil dibuat',
        data: {
          qris_id: qrisData.id,
          qr_string: qrisData.qr_string,
          amount: qrisData.amount,
          status: qrisData.status,
          booking_id: booking_id,
          is_simulated: qrisData.is_simulated || false
        }
      });
    } catch (error) {
      console.error('Create QRIS payment error:', error);
      res.status(500).json({
        success: false,
        message: 'Gagal membuat QRIS: ' + error.message
      });
    }
  }

  /**
   * Handle Webhook Callback from Xendit when QRIS is paid
   */
  async handleXenditWebhook(req, res) {
    try {
      const callbackToken = req.headers['x-callback-token'];
      if (!xenditService.verifyWebhookToken(callbackToken)) {
        return res.status(403).json({ success: false, message: 'Invalid callback token' });
      }

      const event = req.body;
      console.log('🔔 Xendit Webhook Received:', JSON.stringify(event));

      const status = (event.status || event.qr_code?.status || event.data?.status || '').toUpperCase();
      const externalId = event.external_id || event.qr_code?.external_id || event.data?.external_id || '';
      // Hanya proses pembayaran yang benar-benar SUDAH DIBAYAR (COMPLETED atau PAID)
      // Status 'ACTIVE' TIDAK BOLEH diproses karena ACTIVE hanya berarti QR baru dibuat, belum dibayar!
      if (status === 'COMPLETED' || status === 'PAID') {
        const parts = externalId.split('_');
        const bookingId = parts[1];

        if (bookingId) {
          const { data: booking } = await supabaseAdmin
            .from('bookings')
            .select('*')
            .eq('id', bookingId)
            .maybeSingle();

          if (booking) {
            const isPelunasan = externalId.includes('_pelunasan_') || externalId.includes('_full_');

            // 🛡️ Idempotensi Webhook: Jika status pembayaran sudah tercatat, abaikan webhook duplikat dari Xendit
            const addDetails = booking.additional_details || {};
            if (isPelunasan && (addDetails.pelunasan_paid === true || addDetails.final_paid === true)) {
              console.log(`ℹ️ [Xendit Webhook] Pelunasan untuk Booking #${bookingId.substring(0, 8)} sudah pernah diproses. Melewatkan webhook duplikat.`);
              return res.status(200).json({ success: true, message: 'Webhook already processed' });
            }
            if (!isPelunasan && addDetails.dp_paid === true) {
              console.log(`ℹ️ [Xendit Webhook] DP untuk Booking #${bookingId.substring(0, 8)} sudah pernah diproses. Melewatkan webhook duplikat.`);
              return res.status(200).json({ success: true, message: 'Webhook already processed' });
            }

            // Ekstrak nominal pembayaran dari payload webhook (mendukung payload standar atau data wrapper)
            const rawAmount = event.amount || event.qr_code?.amount || event.data?.amount || event.data?.qr_code?.amount;
            let payAmount = parseFloat(rawAmount || 0);

            // Fallback jika payload webhook tidak menyertakan amount eksplisit
            if (payAmount <= 0) {
              const { data: pendingTrx } = await supabaseAdmin
                .from('payment_transactions')
                .select('amount')
                .eq('booking_id', bookingId)
                .eq('status', 'PENDING')
                .order('created_at', { ascending: false })
                .limit(1)
                .maybeSingle();

              if (pendingTrx && pendingTrx.amount) {
                payAmount = parseFloat(pendingTrx.amount);
              } else {
                const totPrice = parseFloat(booking.total_price || 0);
                const dpAmt = booking.dp_amount ? parseFloat(booking.dp_amount) : Math.round(totPrice * 0.3);
                payAmount = isPelunasan ? Math.max(0, totPrice - dpAmt) : dpAmt;
              }
            }

            // Process payment in escrow atomically
            const updatedBooking = await escrowService.holdPaymentInEscrow({
              booking,
              payAmount: payAmount,
              isPelunasan,
              paymentType: isPelunasan ? 'pelunasan' : 'dp'
            });

            if (isPelunasan && booking.driver_id) {
              await escrowService.releaseDriverPayout(bookingId, updatedBooking, 'Pelunasan QRIS Xendit');
            }

            // Sync payment_transactions record status to HELD_IN_ESCROW
            const trxNotes = JSON.stringify({
              payment_gateway: 'Xendit',
              method: 'QRIS',
              qris_status: 'PAID',
              xendit_event_id: event.id || event.qr_code?.id || event.data?.id,
              paid_at: event.paid_at || event.data?.paid_at || new Date().toISOString()
            });

            const { data: existingTrx } = await supabaseAdmin
              .from('payment_transactions')
              .update({
                status: 'HELD_IN_ESCROW',
                admin_notes: trxNotes,
                updated_at: new Date().toISOString()
              })
              .eq('booking_id', bookingId)
              .select();

            if (!existingTrx || existingTrx.length === 0) {
              await supabaseAdmin.from('payment_transactions').insert([{
                booking_id: bookingId,
                user_id: booking.user_id,
                type: isPelunasan ? 'PELUNASAN' : 'DP',
                amount: payAmount,
                unique_code: 0,
                total_payable: payAmount,
                status: 'HELD_IN_ESCROW',
                sla_deadline: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
                admin_notes: trxNotes
              }]);
            }

            console.log(`🎉 Xendit Webhook SUCCESS: Booking #${bookingId} updated to ${isPelunasan ? 'Pelunasan Paid' : 'DP Paid'} (Rp ${payAmount.toLocaleString('id-ID')} Escrow Held)`);
          }
        }
      }

      res.status(200).json({ success: true, message: 'Webhook processed' });
    } catch (error) {
      console.error('Xendit webhook error:', error);
      res.status(500).json({ success: false, message: error.message });
    }
  }

  /**
   * Simulate QRIS Payment Success (For Sandbox / Local Testing)
   */
  async simulateQrisPaid(req, res) {
    try {
      // Sandbox mode simulation: diaktifkan agar client & tester bisa melakukan simulasi pembayaran
      const isExplicitProduction = process.env.ENABLE_SANDBOX_SIMULATION === 'false';
      const isAdmin = req.user && req.user.role === 'admin';

      if (isExplicitProduction && !isAdmin) {
        return res.status(403).json({
          success: false,
          message: 'Akses ditolak. Fitur simulasi pembayaran sandbox dinonaktifkan di lingkungan produksi untuk pengguna non-admin.'
        });
      }

      const { booking_id, amount, payment_type = 'dp' } = req.body;

      if (!booking_id) {
        return res.status(400).json({ success: false, message: 'booking_id wajib diisi' });
      }

      const { data: booking, error: bookingErr } = await supabaseAdmin
        .from('bookings')
        .select('*')
        .eq('id', booking_id)
        .single();

      if (bookingErr || !booking) {
        return res.status(404).json({ success: false, message: 'Booking tidak ditemukan' });
      }

      // 🛡️ SECURITY GUARD 2: Periksa otorisasi (hanya pemilik pesanan atau admin yang berhak)
      if (booking.user_id !== req.user.id && !isAdmin) {
        return res.status(403).json({
          success: false,
          message: 'Anda tidak memiliki otorisasi untuk mengakses data pembayaran pesanan ini'
        });
      }

      const isPelunasan = payment_type === 'pelunasan' || payment_type === 'full';
      const payAmount = parseFloat(amount || (isPelunasan ? booking.total_price * 0.5 : booking.total_price * 0.5));

      // Process payment in escrow atomically
      const updatedBooking = await escrowService.holdPaymentInEscrow({
        booking,
        payAmount,
        isPelunasan,
        paymentType: isPelunasan ? 'pelunasan' : 'dp'
      });

      if (isPelunasan && booking.driver_id) {
        await escrowService.releaseDriverPayout(booking_id, updatedBooking, 'Pelunasan QRIS Simulasi Sandbox');
      }

      // Record transaction status as HELD_IN_ESCROW
      const trxNotes = JSON.stringify({
        payment_gateway: 'Xendit Sandbox',
        method: 'QRIS',
        qris_status: 'PAID',
        mode: 'Simulated Sandbox'
      });

      const { data: updatedTrx } = await supabaseAdmin
        .from('payment_transactions')
        .update({
          status: 'HELD_IN_ESCROW',
          admin_notes: trxNotes
        })
        .eq('booking_id', booking_id)
        .select();

      if (!updatedTrx || updatedTrx.length === 0) {
        await supabaseAdmin.from('payment_transactions').insert([{
          booking_id: booking_id,
          user_id: booking.user_id,
          type: isPelunasan ? 'PELUNASAN' : 'DP',
          amount: payAmount,
          unique_code: 0,
          total_payable: payAmount,
          status: 'HELD_IN_ESCROW',
          sla_deadline: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
          admin_notes: trxNotes
        }]);
      }

      console.log(`⚡ Simulated QRIS Payment Success for Booking #${booking_id} (${isPelunasan ? 'Pelunasan' : 'DP'})`);

      res.status(200).json({
        success: true,
        message: `Simulasi pembayaran QRIS (${isPelunasan ? 'Pelunasan' : 'DP'}) berhasil! Status pesanan kini aktif.`,
        data: updatedBooking
      });
    } catch (error) {
      console.error('Simulate QRIS paid error:', error);
      res.status(500).json({ success: false, message: error.message });
    }
  }
}

module.exports = new PaymentController();
