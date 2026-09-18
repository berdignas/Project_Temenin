// backend/test_manual_finance_flow.js
require('dotenv').config();
const { supabaseAdmin } = require('./src/config/supabase');
const escrowService = require('./src/services/escrowService');
const adminController = require('./src/controllers/adminController');
const paymentController = require('./src/controllers/client/paymentController');
const driverController = require('./src/controllers/driver/driverController');
const { ensureAuthUser } = require('./src/utils/authSync');

// Mock Express req & res
function createMockReqRes({ user, body = {}, params = {}, query = {} }) {
  const req = { user, body, params, query };
  let statusCode = 200;
  let responseData = null;

  const res = {
    status(code) {
      statusCode = code;
      return this;
    },
    json(data) {
      responseData = data;
      return this;
    },
    send(data) {
      responseData = data;
      return this;
    },
    getStatusCode: () => statusCode,
    getData: () => responseData
  };

  return { req, res };
}

async function runTests() {
  console.log('====================================================');
  console.log('🚀 TESTING MANUAL PAYMENT & WITHDRAWAL APPROVAL FLOW');
  console.log('====================================================\n');

  let testClientUser = null;
  let testDriverUser = null;
  let testDriverRecord = null;
  let testAdminUser = null;
  let testBooking = null;

  try {
    // ==========================================
    // SETUP TEST ENTITIES
    // ==========================================
    console.log('📌 Setting up test users & records in Supabase...');

    // 1. Client user
    const { data: client, error: cErr } = await supabaseAdmin
      .from('users')
      .insert([{
        email: `test_client_fin_${Date.now()}@temenin.aja`,
        password_hash: '$2a$10$dummyhashformanualflowtestclient123456',
        full_name: 'Client Manual Tester',
        phone: `0812${Math.floor(Math.random() * 89999999 + 10000000)}`,
        role: 'client',
        balance: 50000,
        is_verified: true
      }])
      .select()
      .single();
    if (cErr) throw cErr;
    testClientUser = client;
    await ensureAuthUser(client.id, client.email);

    // 2. Driver user
    const { data: driverUser, error: duErr } = await supabaseAdmin
      .from('users')
      .insert([{
        email: `test_driver_fin_${Date.now()}@temenin.aja`,
        password_hash: '$2a$10$dummyhashformanualflowtestdriver123456',
        full_name: 'Driver Mitra Tester',
        phone: `0813${Math.floor(Math.random() * 89999999 + 10000000)}`,
        role: 'driver',
        balance: 100000, // Initial balance 100k
        is_verified: true
      }])
      .select()
      .single();
    if (duErr) throw duErr;
    testDriverUser = driverUser;
    await ensureAuthUser(driverUser.id, driverUser.email);

    // 3. Driver record
    const { data: driverRec, error: drErr } = await supabaseAdmin
      .from('drivers')
      .insert([{
        user_id: driverUser.id,
        vehicle_type: 'Motor',
        vehicle_name: 'Honda Vario',
        plate_number: 'B 9999 FIN',
        price_per_hour: 50000,
        status: 'approved',
        is_available: true
      }])
      .select()
      .single();
    if (drErr) throw drErr;
    testDriverRecord = driverRec;

    // 4. Admin user
    const { data: adminUser, error: aErr } = await supabaseAdmin
      .from('users')
      .insert([{
        email: `test_admin_fin_${Date.now()}@temenin.aja`,
        password_hash: '$2a$10$dummyhashformanualflowtestadmin1234567',
        full_name: 'Super Admin Finance',
        phone: `0814${Math.floor(Math.random() * 89999999 + 10000000)}`,
        role: 'admin',
        balance: 0,
        is_verified: true
      }])
      .select()
      .single();
    if (aErr) throw aErr;
    testAdminUser = adminUser;
    await ensureAuthUser(adminUser.id, adminUser.email);

    // 5. Create Test Booking (Total: Rp 100.000, DP: Rp 30.000, Pelunasan: Rp 70.000)
    const { data: booking, error: bErr } = await supabaseAdmin
      .from('bookings')
      .insert([{
        user_id: testClientUser.id,
        driver_id: testDriverRecord.id,
        status: 'pending',
        pickup_location: 'Plaza Indonesia',
        dropoff_location: 'Grand Indonesia',
        total_price: 100000,
        additional_details: {
          service_category: 'OFFLINE',
          dp_amount: 30000,
          pelunasan_amount: 70000,
          escrow_balance: 0,
          payout_status: 'pending'
        }
      }])
      .select()
      .single();
    if (bErr) throw bErr;
    testBooking = booking;

    console.log('✅ Setup complete!');
    console.log(`   Client: ${testClientUser.id} (Saldo: ${testClientUser.balance})`);
    console.log(`   Driver: ${testDriverUser.id} (Saldo: ${testDriverUser.balance})`);
    console.log(`   Booking: ${testBooking.id} (Total: ${testBooking.total_price})\n`);

    // ==========================================
    // TEST 1: CLIENT SUBMITS MANUAL DP PAYMENT
    // ==========================================
    console.log('🧪 TEST 1: Client submits manual DP payment (30k)...');
    {
      const { req, res } = createMockReqRes({
        user: testClientUser,
        body: {
          booking_id: testBooking.id,
          type: 'DP',
          amount: 30000,
          bank_name: 'Bank BCA',
          account_number: '1234567890',
          account_name: testClientUser.full_name,
          proof_url: 'https://example.com/receipt_dp.jpg',
          notes: 'Transfer via BCA Mobile'
        }
      });

      await paymentController.submitManualPayment(req, res);

      const status = res.getStatusCode();
      const body = res.getData();

      if (status !== 201 || !body.success) {
        throw new Error(`TEST 1 FAILED: Expected 201, got ${status}: ${JSON.stringify(body)}`);
      }

      // Verify DB record
      const { data: trx } = await supabaseAdmin
        .from('payment_transactions')
        .select('*')
        .eq('id', body.data.id)
        .single();

      if (!trx || trx.status !== 'PENDING' || trx.type !== 'DP' || parseFloat(trx.amount) !== 30000) {
        throw new Error(`TEST 1 FAILED: Invalid transaction in DB: ${JSON.stringify(trx)}`);
      }

      console.log(`   ✅ Test 1 Passed! Transaction created with ID: ${trx.id}, status: PENDING\n`);
      testBooking.dpTrxId = trx.id;
    }

    // ==========================================
    // TEST 2: ADMIN ACC / APPROVES DP
    // ==========================================
    console.log('🧪 TEST 2: Admin ACC / Approves DP transaction...');
    {
      const { req, res } = createMockReqRes({
        user: testAdminUser,
        params: { id: testBooking.dpTrxId },
        body: { notes: 'Bukti transfer DP valid & dana masuk rek BCA PT' }
      });

      await adminController.approveTransaction(req, res);

      const status = res.getStatusCode();
      const body = res.getData();

      if (status !== 200 || !body.success) {
        throw new Error(`TEST 2 FAILED: Expected 200, got ${status}: ${JSON.stringify(body)}`);
      }

      // Check transaction status
      const { data: trx } = await supabaseAdmin
        .from('payment_transactions')
        .select('*')
        .eq('id', testBooking.dpTrxId)
        .single();

      if (trx.status !== 'HELD_IN_ESCROW') {
        throw new Error(`TEST 2 FAILED: Expected transaction status HELD_IN_ESCROW, got ${trx.status}`);
      }

      // Check booking status
      const { data: updatedBk } = await supabaseAdmin
        .from('bookings')
        .select('*')
        .eq('id', testBooking.id)
        .single();

      if (updatedBk.status !== 'ongoing' || !updatedBk.additional_details?.dp_paid) {
        throw new Error(`TEST 2 FAILED: Expected booking ongoing & dp_paid: true, got ${JSON.stringify(updatedBk)}`);
      }

      if (parseFloat(updatedBk.additional_details?.escrow_balance || 0) !== 30000) {
        throw new Error(`TEST 2 FAILED: Expected escrow_balance 30000, got ${updatedBk.additional_details?.escrow_balance}`);
      }

      console.log(`   ✅ Test 2 Passed! DP Approved. Dana Rp 30.000 masuk ke Escrow Vault, Booking ongoing.\n`);
    }

    // ==========================================
    // TEST 3: CLIENT SUBMITS MANUAL PELUNASAN (70k)
    // ==========================================
    console.log('🧪 TEST 3: Client submits manual Pelunasan (70k)...');
    {
      const { req, res } = createMockReqRes({
        user: testClientUser,
        body: {
          booking_id: testBooking.id,
          type: 'PELUNASAN',
          amount: 70000,
          bank_name: 'Bank Mandiri',
          account_number: '987654321',
          account_name: testClientUser.full_name,
          proof_url: 'https://example.com/receipt_pelunasan.jpg',
          notes: 'Pelunasan sisa tagihan 70rb'
        }
      });

      await paymentController.submitManualPayment(req, res);

      const status = res.getStatusCode();
      const body = res.getData();

      if (status !== 201 || !body.success) {
        throw new Error(`TEST 3 FAILED: Expected 201, got ${status}: ${JSON.stringify(body)}`);
      }

      testBooking.pelunasanTrxId = body.data.id;
      console.log(`   ✅ Test 3 Passed! Pelunasan Transaction ID: ${testBooking.pelunasanTrxId}, status: PENDING\n`);
    }

    // ==========================================
    // TEST 4: ADMIN ACC / SETTLES PELUNASAN (REVENUE SPLIT 90%)
    // ==========================================
    console.log('🧪 TEST 4: Admin ACC / Settles Pelunasan (90% Driver Share)...');
    {
      const initialDriverBal = parseFloat(testDriverUser.balance); // 100k

      const { req, res } = createMockReqRes({
        user: testAdminUser,
        params: { id: testBooking.pelunasanTrxId },
        body: { notes: 'Pelunasan verified. Release 90% payout to driver.' }
      });

      await adminController.settlePelunasanSplit(req, res);

      const status = res.getStatusCode();
      const body = res.getData();

      if (status !== 200 || !body.success) {
        throw new Error(`TEST 4 FAILED: Expected 200, got ${status}: ${JSON.stringify(body)}`);
      }

      // Check transaction
      const { data: trx } = await supabaseAdmin
        .from('payment_transactions')
        .select('*')
        .eq('id', testBooking.pelunasanTrxId)
        .single();

      if (trx.status !== 'APPROVED') {
        throw new Error(`TEST 4 FAILED: Expected transaction APPROVED, got ${trx.status}`);
      }

      // Check booking completed
      const { data: b } = await supabaseAdmin
        .from('bookings')
        .select('*')
        .eq('id', testBooking.id)
        .single();

      if (b.status !== 'completed' || !b.additional_details?.pelunasan_paid) {
        throw new Error(`TEST 4 FAILED: Booking should be completed with pelunasan_paid`);
      }

      // Check driver balance (Total 100k * 90% = +90k => 100k + 90k = 190k)
      const { data: drv } = await supabaseAdmin
        .from('users')
        .select('balance')
        .eq('id', testDriverUser.id)
        .single();

      const expectedDriverBal = initialDriverBal + 90000;
      if (parseFloat(drv.balance) !== expectedDriverBal) {
        throw new Error(`TEST 4 FAILED: Expected driver balance ${expectedDriverBal}, got ${drv.balance}`);
      }

      console.log(`   ✅ Test 4 Passed! Booking completed. Driver balance credited 90% (now Rp ${drv.balance}).\n`);
      testDriverUser.balance = parseFloat(drv.balance);
    }

    // ==========================================
    // TEST 5: DRIVER WITHDRAWAL - REJECT OVER-LIMIT
    // ==========================================
    console.log('🧪 TEST 5: Driver attempts withdrawal exceeding balance (Over-limit check)...');
    {
      const excessiveAmount = 999999999; // 999 Million
      const { req, res } = createMockReqRes({
        user: testDriverUser,
        body: {
          amount: excessiveAmount,
          bank_name: 'Bank BCA',
          account_number: '8820192831',
          account_name: testDriverUser.full_name
        }
      });

      await driverController.requestWithdrawal(req, res);

      const status = res.getStatusCode();
      const body = res.getData();

      if (status !== 400 || body.success !== false) {
        throw new Error(`TEST 5 FAILED: Expected 400 Bad Request, got ${status}: ${JSON.stringify(body)}`);
      }

      // Verify driver balance was untouched
      const { data: drv } = await supabaseAdmin.from('users').select('balance').eq('id', testDriverUser.id).single();
      if (parseFloat(drv.balance) !== testDriverUser.balance) {
        throw new Error(`TEST 5 FAILED: Driver balance altered on rejected withdrawal!`);
      }

      console.log(`   ✅ Test 5 Passed! Over-limit withdrawal rejected (400) with message: "${body.message}". Saldo aman.\n`);
    }

    // ==========================================
    // TEST 6: DRIVER WITHDRAWAL - VALID & ATOMIC DEDUCTION
    // ==========================================
    console.log('🧪 TEST 6: Driver submits valid withdrawal (Rp 50.000) & instant atomic deduction...');
    let withdrawTrxId = null;
    {
      const withdrawAmount = 50000;
      const initialBal = testDriverUser.balance; // 190k

      const { req, res } = createMockReqRes({
        user: testDriverUser,
        body: {
          amount: withdrawAmount,
          bank_name: 'Bank BCA',
          account_number: '8820192831',
          account_name: testDriverUser.full_name,
          notes: 'Tarik komisi mingguan'
        }
      });

      await driverController.requestWithdrawal(req, res);

      const status = res.getStatusCode();
      const body = res.getData();

      if (status !== 201 || !body.success) {
        throw new Error(`TEST 6 FAILED: Expected 201, got ${status}: ${JSON.stringify(body)}`);
      }

      withdrawTrxId = body.data.transaction.id;

      // Verify driver balance was AUTOMATICALLY DEDUCTED
      const { data: drv } = await supabaseAdmin.from('users').select('balance').eq('id', testDriverUser.id).single();
      const expectedBal = initialBal - withdrawAmount; // 190k - 50k = 140k

      if (parseFloat(drv.balance) !== expectedBal) {
        throw new Error(`TEST 6 FAILED: Expected balance ${expectedBal}, got ${drv.balance}`);
      }

      console.log(`   ✅ Test 6 Passed! Penarikan diajukan (ID: ${withdrawTrxId}). Saldo otomatis terpotong dari Rp ${initialBal} ke Rp ${drv.balance}.\n`);
      testDriverUser.balance = parseFloat(drv.balance);
    }

    // ==========================================
    // TEST 7: ADMIN ACC / DISBURSES WITHDRAWAL
    // ==========================================
    console.log('🧪 TEST 7: Admin confirms disbursement / transfer...');
    {
      const { req, res } = createMockReqRes({
        user: testAdminUser,
        params: { id: withdrawTrxId },
        body: { notes: 'Dana Rp 50.000 berhasil ditransfer ke BCA 8820192831' }
      });

      await adminController.disbursePayout(req, res);

      const status = res.getStatusCode();
      const body = res.getData();

      if (status !== 200 || !body.success) {
        throw new Error(`TEST 7 FAILED: Expected 200, got ${status}: ${JSON.stringify(body)}`);
      }

      const { data: trx } = await supabaseAdmin
        .from('payment_transactions')
        .select('*')
        .eq('id', withdrawTrxId)
        .single();

      if (trx.status !== 'DISBURSED') {
        throw new Error(`TEST 7 FAILED: Expected status DISBURSED, got ${trx.status}`);
      }

      console.log(`   ✅ Test 7 Passed! Admin approved disbursement, status is now DISBURSED.\n`);
    }

    // ==========================================
    // TEST 8: DRIVER WITHDRAWAL - ADMIN REJECT & INSTANT REFUND
    // ==========================================
    console.log('🧪 TEST 8: Driver withdrawal rejected by Admin -> Automatic refund to wallet...');
    {
      const withdrawAmount = 30000;
      const initialBal = testDriverUser.balance; // 140k

      // 1. Driver requests withdrawal
      const { req: reqW, res: resW } = createMockReqRes({
        user: testDriverUser,
        body: {
          amount: withdrawAmount,
          bank_name: 'Bank Mandiri',
          account_number: '111222333',
          account_name: 'Nama Salah',
          notes: 'Test penarikan ditolak'
        }
      });

      await driverController.requestWithdrawal(reqW, resW);
      const rejectedTrxId = resW.getData().data.transaction.id;

      // Balance was deducted to 110k
      const { data: drvAfterReq } = await supabaseAdmin.from('users').select('balance').eq('id', testDriverUser.id).single();
      if (parseFloat(drvAfterReq.balance) !== initialBal - withdrawAmount) {
        throw new Error(`TEST 8 FAILED: Expected deducted balance ${initialBal - withdrawAmount}`);
      }

      // 2. Admin rejects this transaction
      const { req: reqR, res: resR } = createMockReqRes({
        user: testAdminUser,
        params: { id: rejectedTrxId },
        body: { notes: 'Nama rekening tidak cocok dengan nama akun driver' }
      });

      await adminController.rejectTransaction(reqR, resR);

      const status = resR.getStatusCode();
      const body = resR.getData();

      if (status !== 200 || !body.success) {
        throw new Error(`TEST 8 FAILED: Expected 200, got ${status}: ${JSON.stringify(body)}`);
      }

      // Check transaction is REJECTED
      const { data: trx } = await supabaseAdmin
        .from('payment_transactions')
        .select('*')
        .eq('id', rejectedTrxId)
        .single();

      if (trx.status !== 'REJECTED') {
        throw new Error(`TEST 8 FAILED: Expected REJECTED, got ${trx.status}`);
      }

      // Check driver balance was REFUNDED back to 140k!
      const { data: drvAfterRefund } = await supabaseAdmin.from('users').select('balance').eq('id', testDriverUser.id).single();
      if (parseFloat(drvAfterRefund.balance) !== initialBal) {
        throw new Error(`TEST 8 FAILED: Balance not refunded! Expected ${initialBal}, got ${drvAfterRefund.balance}`);
      }

      console.log(`   ✅ Test 8 Passed! Transaksi ditolak Admin, dana Rp 30.000 otomatis di-refund kembali ke dompet driver (Saldo: Rp ${drvAfterRefund.balance}).\n`);
    }

    // ==========================================
    // TEST 9: ADMIN GET TRANSACTIONS CMS LIST
    // ==========================================
    console.log('🧪 TEST 9: Admin GET /finance/transactions verification...');
    {
      const { req, res } = createMockReqRes({
        user: testAdminUser,
        query: {}
      });

      await adminController.getTransactions(req, res);

      const status = res.getStatusCode();
      const body = res.getData();

      if (status !== 200 || !body.success || !Array.isArray(body.data)) {
        throw new Error(`TEST 9 FAILED: Expected array of transactions`);
      }

      console.log(`   ✅ Test 9 Passed! Admin CMS successfully loaded ${body.data.length} transactions.\n`);
    }

    console.log('====================================================');
    console.log('🎉 ALL 9 TEST SUITES PASSED WITH 100% SUCCESS!');
    console.log('====================================================');

  } catch (err) {
    console.error('\n❌ TEST RUN FAILED:', err);
    process.exit(1);
  } finally {
    // Clean up test data
    console.log('\n🧹 Cleaning up test artifacts from database...');
    try {
      if (testBooking?.id) {
        await supabaseAdmin.from('payment_transactions').delete().eq('booking_id', testBooking.id);
        await supabaseAdmin.from('bookings').delete().eq('id', testBooking.id);
      }
      if (testDriverUser?.id) {
        await supabaseAdmin.from('payment_transactions').delete().eq('user_id', testDriverUser.id);
        await supabaseAdmin.from('wallet_transactions').delete().eq('user_id', testDriverUser.id);
        if (testDriverRecord?.id) {
          await supabaseAdmin.from('drivers').delete().eq('id', testDriverRecord.id);
        }
        await supabaseAdmin.from('users').delete().eq('id', testDriverUser.id);
        try { await supabaseAdmin.auth.admin.deleteUser(testDriverUser.id); } catch {}
      }
      if (testClientUser?.id) {
        await supabaseAdmin.from('payment_transactions').delete().eq('user_id', testClientUser.id);
        await supabaseAdmin.from('wallet_transactions').delete().eq('user_id', testClientUser.id);
        await supabaseAdmin.from('users').delete().eq('id', testClientUser.id);
        try { await supabaseAdmin.auth.admin.deleteUser(testClientUser.id); } catch {}
      }
      if (testAdminUser?.id) {
        await supabaseAdmin.from('users').delete().eq('id', testAdminUser.id);
        try { await supabaseAdmin.auth.admin.deleteUser(testAdminUser.id); } catch {}
      }
      console.log('✅ Cleanup completed cleanly.');
    } catch (cleanupErr) {
      console.warn('Cleanup warning:', cleanupErr.message);
    }
  }
}

runTests();
