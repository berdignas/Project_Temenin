// backend/test_escrow_payout.js
const { supabaseAdmin } = require('./src/config/supabase');
const paymentController = require('./src/controllers/client/paymentController');
const adminController = require('./src/controllers/adminController');
const escrowService = require('./src/services/escrowService');

// Helper to simulate express req/res
function mockReqRes(body = {}, params = {}, user = {}) {
  const req = { body, params, user, query: {} };
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
    }
  };

  return { req, res, getResult: () => ({ statusCode, responseData }) };
}

async function runTests() {
  console.log('====================================================');
  console.log('🧪 RUNNING ESCROW & ANTI-DOUBLE PAYOUT TEST SUITE');
  console.log('====================================================\n');

  try {
    // 1. Create a test client and driver in DB
    const testTimestamp = Date.now();
    const clientPhone = `899${testTimestamp.toString().slice(-8)}`;
    const driverPhone = `888${testTimestamp.toString().slice(-8)}`;

    console.log('1. Setting up test client and driver...');
    const { data: clientUser, error: clientErr } = await supabaseAdmin
      .from('users')
      .insert({
        full_name: `Test Client ${testTimestamp}`,
        phone: clientPhone,
        role: 'client',
        balance: 500000, // Rp 500.000 initial balance
        is_verified: true
      })
      .select()
      .single();

    if (clientErr) throw new Error('Failed to create test client: ' + clientErr.message);

    const { data: driverUser, error: driverUserErr } = await supabaseAdmin
      .from('users')
      .insert({
        full_name: `Test Driver ${testTimestamp}`,
        phone: driverPhone,
        role: 'driver',
        balance: 0, // Rp 0 initial balance
        is_verified: true
      })
      .select()
      .single();

    if (driverUserErr) throw new Error('Failed to create test driver user: ' + driverUserErr.message);

    const { data: driver, error: driverErr } = await supabaseAdmin
      .from('drivers')
      .insert({
        user_id: driverUser.id,
        vehicle_type: 'Motor',
        vehicle_name: 'Honda Vario',
        plate_number: `B ${testTimestamp.toString().slice(-4)} TST`,
        status: 'approved',
        price_per_hour: 50000
      })
      .select()
      .single();

    if (driverErr) throw new Error('Failed to create driver record: ' + driverErr.message);

    console.log(`✅ Test Client created: ${clientUser.id} (Initial Balance: Rp ${clientUser.balance})`);
    console.log(`✅ Test Driver created: ${driver.id} (Driver User: ${driverUser.id}, Initial Balance: Rp ${driverUser.balance})\n`);

    // 2. Create a test booking (Total Price: Rp 200.000, DP: Rp 60.000 (30%), Pelunasan: Rp 140.000 (70%))
    const totalPrice = 200000;
    const dpAmount = 60000;
    const pelunasanAmount = 140000;
    const expectedDriverIncome = totalPrice * 0.90; // Rp 180.000

    console.log(`2. Creating test booking (Total Price: Rp ${totalPrice.toLocaleString('id-ID')})...`);
    const { data: booking, error: bookingErr } = await supabaseAdmin
      .from('bookings')
      .insert({
        user_id: clientUser.id,
        driver_id: driver.id,
        pickup_location: 'Stasiun Gambir',
        dropoff_location: 'Monas',
        total_price: totalPrice,
        duration: 120,
        status: 'pending',
        additional_details: { sub_status: 'pending' }
      })
      .select()
      .single();

    if (bookingErr) throw new Error('Failed to create booking: ' + bookingErr.message);
    console.log(`✅ Booking created: ${booking.id}\n`);

    // 3. STEP 1: Client pays DP (Rp 60.000)
    console.log('----------------------------------------------------');
    console.log('📌 STEP 1: Client Pays DP (Rp 60.000)...');
    const dpMock = mockReqRes(
      { booking_id: booking.id, amount: dpAmount, payment_type: 'dp', use_wallet: true },
      {},
      { id: clientUser.id, role: 'client' }
    );
    await paymentController.processPayment(dpMock.req, dpMock.res);
    const dpRes = dpMock.getResult();
    console.log('DP Payment Response:', dpRes.statusCode, dpRes.responseData.message);

    if (dpRes.statusCode !== 200) {
      throw new Error('DP payment failed: ' + JSON.stringify(dpRes.responseData));
    }

    // Verify Client Balance (should be 500.000 - 60.000 = 440.000)
    const { data: clientAfterDp } = await supabaseAdmin.from('users').select('balance').eq('id', clientUser.id).single();
    console.log(`Client Balance after DP: Rp ${clientAfterDp.balance} (Expected: 440000)`);
    if (parseFloat(clientAfterDp.balance) !== 440000) {
      throw new Error(`❌ Client balance mismatch after DP: Expected 440000, got ${clientAfterDp.balance}`);
    }

    // Verify Driver Balance (MUST STILL BE 0! NOT MULTIPLIED!)
    const { data: driverAfterDp } = await supabaseAdmin.from('users').select('balance').eq('id', driverUser.id).single();
    console.log(`Driver Balance after DP: Rp ${driverAfterDp.balance} (Expected: 0)`);
    if (parseFloat(driverAfterDp.balance) !== 0) {
      throw new Error(`❌ BUG DETECTED: Driver balance was credited during DP! Value: ${driverAfterDp.balance}`);
    }
    console.log('✅ PASS: DP held in escrow. Driver balance untouched (Rp 0).\n');

    // 4. STEP 2: Client pays Pelunasan (Rp 140.000)
    console.log('----------------------------------------------------');
    console.log('📌 STEP 2: Client Pays Pelunasan (Rp 140.000)...');
    const pelMock = mockReqRes(
      { booking_id: booking.id, amount: pelunasanAmount, payment_type: 'pelunasan', use_wallet: true },
      {},
      { id: clientUser.id, role: 'client' }
    );
    await paymentController.processPayment(pelMock.req, pelMock.res);
    const pelRes = pelMock.getResult();
    console.log('Pelunasan Payment Response:', pelRes.statusCode, pelRes.responseData.message);

    if (pelRes.statusCode !== 200) {
      throw new Error('Pelunasan payment failed: ' + JSON.stringify(pelRes.responseData));
    }

    // Verify Client Balance (should be 440.000 - 140.000 = 300.000)
    const { data: clientAfterPel } = await supabaseAdmin.from('users').select('balance').eq('id', clientUser.id).single();
    console.log(`Client Balance after Pelunasan: Rp ${clientAfterPel.balance} (Expected: 300000)`);
    if (parseFloat(clientAfterPel.balance) !== 300000) {
      throw new Error(`❌ Client balance mismatch after Pelunasan: Expected 300000, got ${clientAfterPel.balance}`);
    }

    // Verify Driver Balance (MUST BE EXACTLY 90% OF TOTAL PRICE: Rp 180.000)
    const { data: driverAfterPel } = await supabaseAdmin.from('users').select('balance').eq('id', driverUser.id).single();
    console.log(`Driver Balance after Pelunasan: Rp ${driverAfterPel.balance} (Expected: ${expectedDriverIncome})`);
    if (parseFloat(driverAfterPel.balance) !== expectedDriverIncome) {
      throw new Error(`❌ Driver balance mismatch after Pelunasan: Expected ${expectedDriverIncome}, got ${driverAfterPel.balance}`);
    }
    console.log(`✅ PASS: Driver credited exactly 90% (Rp ${expectedDriverIncome.toLocaleString('id-ID')}) upon completion.\n`);

    // 5. STEP 3: Admin marks booking status as 'completed' in dashboard
    console.log('----------------------------------------------------');
    console.log("📌 STEP 3: Admin marks booking as 'completed' via adminController.updateBookingStatus...");
    const adminMock = mockReqRes(
      { status: 'completed' },
      { id: booking.id },
      { id: 'admin-id', role: 'admin' }
    );
    await adminController.updateBookingStatus(adminMock.req, adminMock.res);
    const adminRes = adminMock.getResult();
    console.log('Admin Status Update Response:', adminRes.statusCode, adminRes.responseData.message);

    // Verify Driver Balance (MUST STILL BE EXACTLY Rp 180.000, NO DOUBLE PAYOUT!)
    const { data: driverAfterAdmin } = await supabaseAdmin.from('users').select('balance').eq('id', driverUser.id).single();
    console.log(`Driver Balance after Admin completed: Rp ${driverAfterAdmin.balance} (Expected: ${expectedDriverIncome})`);
    if (parseFloat(driverAfterAdmin.balance) !== expectedDriverIncome) {
      throw new Error(`❌ DOUBLE PAYOUT BUG DETECTED! Driver balance increased to ${driverAfterAdmin.balance} (Expected: ${expectedDriverIncome})`);
    }
    console.log('✅ PASS: Admin updateBookingStatus did NOT duplicate driver payout!\n');

    // 6. STEP 4: Admin updates booking via adminController.updateBooking
    console.log('----------------------------------------------------');
    console.log("📌 STEP 4: Admin updates booking details with status='paid' via adminController.updateBooking...");
    const editMock = mockReqRes(
      { status: 'paid', pickup_location: 'Stasiun Gambir Updated' },
      { id: booking.id },
      { id: 'admin-id', role: 'admin' }
    );
    await adminController.updateBooking(editMock.req, editMock.res);
    const editRes = editMock.getResult();
    console.log('Admin Edit Booking Response:', editRes.statusCode, editRes.responseData.message);

    // Verify Driver Balance (MUST STILL BE EXACTLY Rp 180.000, NO TRIPLE PAYOUT!)
    const { data: driverAfterEdit } = await supabaseAdmin.from('users').select('balance').eq('id', driverUser.id).single();
    console.log(`Driver Balance after Admin edit: Rp ${driverAfterEdit.balance} (Expected: ${expectedDriverIncome})`);
    if (parseFloat(driverAfterEdit.balance) !== expectedDriverIncome) {
      throw new Error(`❌ TRIPLE PAYOUT BUG DETECTED! Driver balance increased to ${driverAfterEdit.balance} (Expected: ${expectedDriverIncome})`);
    }
    console.log('✅ PASS: Admin updateBooking did NOT duplicate driver payout!\n');

    // 7. STEP 5: Test Multiple Concurrent Payout Calls
    console.log('----------------------------------------------------');
    console.log('📌 STEP 5: Testing 5 Concurrent releaseDriverPayout calls...');
    const concurrentResults = await Promise.all([
      escrowService.releaseDriverPayout(booking.id, null, 'Concurrent Test 1'),
      escrowService.releaseDriverPayout(booking.id, null, 'Concurrent Test 2'),
      escrowService.releaseDriverPayout(booking.id, null, 'Concurrent Test 3'),
      escrowService.releaseDriverPayout(booking.id, null, 'Concurrent Test 4'),
      escrowService.releaseDriverPayout(booking.id, null, 'Concurrent Test 5')
    ]);

    const { data: driverAfterConcurrent } = await supabaseAdmin.from('users').select('balance').eq('id', driverUser.id).single();
    console.log(`Driver Balance after Concurrent Calls: Rp ${driverAfterConcurrent.balance} (Expected: ${expectedDriverIncome})`);
    if (parseFloat(driverAfterConcurrent.balance) !== expectedDriverIncome) {
      throw new Error(`❌ CONCURRENCY BUG! Driver balance changed to ${driverAfterConcurrent.balance}`);
    }
    console.log('✅ PASS: Idempotency confirmed under concurrent calls!\n');

    // 8. Cleanup Test Data
    console.log('----------------------------------------------------');
    console.log('🧹 Cleaning up test artifacts from database...');
    await supabaseAdmin.from('wallet_transactions').delete().eq('reference_id', booking.id);
    await supabaseAdmin.from('bookings').delete().eq('id', booking.id);
    await supabaseAdmin.from('drivers').delete().eq('id', driver.id);
    await supabaseAdmin.from('users').delete().in('id', [clientUser.id, driverUser.id]);
    console.log('✅ Cleanup finished successfully.\n');

    console.log('====================================================');
    console.log('🎉 ALL TESTS PASSED! BUG SUCCESSFULLY FIXED & VERIFIED!');
    console.log('====================================================');
  } catch (error) {
    console.error('\n❌ TEST FAILED WITH ERROR:', error);
    process.exit(1);
  }
}

runTests();
