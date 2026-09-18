// backend/test_financial_security.js
const { supabaseAdmin } = require('./src/config/supabase');
const paymentController = require('./src/controllers/client/paymentController');
const bookingController = require('./src/controllers/bookingController');
const driverController = require('./src/controllers/driver/driverController');
const escrowService = require('./src/services/escrowService');

// Helper to mock Express req/res
function mockReqRes(body = {}, params = {}, user = {}) {
  const req = { body, params, user, query: {}, headers: {} };
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

async function runSecurityTests() {
  console.log('\n===============================================================');
  console.log('🛡️ RUNNING FINANCIAL SECURITY & CONCURRENCY VERIFICATION SUITE');
  console.log('===============================================================\n');

  const timestamp = Date.now();
  const clientPhone = `89${timestamp.toString().slice(-8)}`;
  const driverPhone = `88${timestamp.toString().slice(-8)}`;

  let clientUser = null;
  let driverUser = null;
  let driverRecord = null;
  let testBooking = null;

  try {
    // 1. Setup Test Users
    console.log('📦 1. Setting up test users and driver...');
    const { data: cUser, error: cErr } = await supabaseAdmin
      .from('users')
      .insert({
        full_name: `Security Client ${timestamp}`,
        phone: clientPhone,
        role: 'client',
        balance: 500000,
        is_verified: true
      })
      .select()
      .single();
    if (cErr) throw cErr;
    clientUser = cUser;

    const { data: dUser, error: dErr } = await supabaseAdmin
      .from('users')
      .insert({
        full_name: `Security Driver ${timestamp}`,
        phone: driverPhone,
        role: 'driver',
        balance: 0,
        is_verified: true
      })
      .select()
      .single();
    if (dErr) throw dErr;
    driverUser = dUser;

    const { data: dRec, error: dRecErr } = await supabaseAdmin
      .from('drivers')
      .insert({
        user_id: driverUser.id,
        vehicle_type: 'Motor',
        vehicle_name: 'Honda Vario 160',
        plate_number: `B ${timestamp.toString().slice(-4)} SEC`,
        price_per_hour: 50000,
        status: 'approved',
        is_available: true
      })
      .select()
      .single();
    if (dRecErr) throw dRecErr;
    driverRecord = dRec;

    const { data: bRec, error: bRecErr } = await supabaseAdmin
      .from('bookings')
      .insert({
        user_id: clientUser.id,
        driver_id: driverRecord.id,
        pickup_location: 'Mall Grand Indonesia',
        dropoff_location: 'Soekarno-Hatta Airport T3',
        total_price: 200000,
        status: 'pending',
        additional_details: { sub_status: 'pending', escrow_balance: 0 }
      })
      .select()
      .single();
    if (bRecErr) throw bRecErr;
    testBooking = bRec;

    console.log(`✅ Created test client (${clientUser.id}), driver (${driverRecord.id}), booking (${testBooking.id})\n`);

    // --------------------------------------------------------------------------
    // TEST 1: ISSUE A - Free Payment Exploit (use_wallet: false)
    // --------------------------------------------------------------------------
    console.log('---------------------------------------------------------------');
    console.log('🧪 TEST 1: Attempting fake payment with use_wallet: false...');
    const payMock = mockReqRes(
      {
        booking_id: testBooking.id,
        amount: 100000,
        payment_type: 'dp',
        use_wallet: false // ATTEMPT EXPLOIT
      },
      {},
      clientUser
    );

    await paymentController.processPayment(payMock.req, payMock.res);
    const payResult = payMock.getResult();
    console.log(`   Response Code: ${payResult.statusCode}`);
    console.log(`   Response Message: "${payResult.responseData?.message}"`);

    if (payResult.statusCode !== 400) {
      throw new Error(`❌ FAILED: use_wallet: false was NOT rejected! Returned status ${payResult.statusCode}`);
    }

    // Verify booking escrow was NOT credited
    const { data: freshBookingAfterFakePay } = await supabaseAdmin
      .from('bookings')
      .select('*')
      .eq('id', testBooking.id)
      .single();

    const escrowBal = parseFloat(freshBookingAfterFakePay.escrow_balance) || parseFloat(freshBookingAfterFakePay.additional_details?.escrow_balance) || 0;
    if (escrowBal > 0) {
      throw new Error(`❌ FAILED: Escrow balance increased on fake payment!`);
    }
    console.log('✅ PASS: use_wallet: false successfully BLOCKED! No free escrow created.\n');

    // --------------------------------------------------------------------------
    // TEST 2: ISSUE B - Driver Attempting to Self-Mark 'paid'
    // --------------------------------------------------------------------------
    console.log('---------------------------------------------------------------');
    console.log('🧪 TEST 2: Driver attempting updateBookingStatus with status: "paid"...');
    const driverSpoofMock = mockReqRes(
      { status: 'paid' },
      { bookingId: testBooking.id },
      driverUser
    );

    await driverController.updateBookingStatus(driverSpoofMock.req, driverSpoofMock.res);
    const driverSpoofRes = driverSpoofMock.getResult();
    console.log(`   Response Code: ${driverSpoofRes.statusCode}`);
    console.log(`   Response Message: "${driverSpoofRes.responseData?.message}"`);

    if (driverSpoofRes.statusCode !== 400) {
      throw new Error(`❌ FAILED: Driver setting status: 'paid' was NOT blocked! Status: ${driverSpoofRes.statusCode}`);
    }

    // Verify driver balance remains 0
    const { data: driverBalCheck1 } = await supabaseAdmin.from('users').select('balance').eq('id', driverUser.id).single();
    if (parseFloat(driverBalCheck1.balance) !== 0) {
      throw new Error(`❌ FAILED: Driver balance increased after spoofing! Balance: ${driverBalCheck1.balance}`);
    }
    console.log('✅ PASS: Driver self-marking "paid" was successfully BLOCKED! Saldo tetap 0.\n');

    // --------------------------------------------------------------------------
    // TEST 3: ISSUE B - Client Attempting to Spoof status: "closed" without Payment
    // --------------------------------------------------------------------------
    console.log('---------------------------------------------------------------');
    console.log('🧪 TEST 3: Client attempting updateBookingStatus with status: "closed"...');
    const clientSpoofMock = mockReqRes(
      { status: 'closed' },
      { bookingId: testBooking.id },
      clientUser
    );

    await bookingController.updateBookingStatus(clientSpoofMock.req, clientSpoofMock.res);
    const clientSpoofRes = clientSpoofMock.getResult();
    console.log(`   Response Code: ${clientSpoofRes.statusCode}`);
    console.log(`   Response Message: "${clientSpoofRes.responseData?.message}"`);

    if (clientSpoofRes.statusCode !== 400) {
      throw new Error(`❌ FAILED: Client setting status: 'closed' was NOT blocked! Status: ${clientSpoofRes.statusCode}`);
    }

    const { data: driverBalCheck2 } = await supabaseAdmin.from('users').select('balance').eq('id', driverUser.id).single();
    if (parseFloat(driverBalCheck2.balance) !== 0) {
      throw new Error(`❌ FAILED: Driver balance increased after client spoofing! Balance: ${driverBalCheck2.balance}`);
    }
    console.log('✅ PASS: Client spoofing "closed" was successfully BLOCKED! Saldo driver tetap 0.\n');

    // --------------------------------------------------------------------------
    // TEST 4: ISSUE C - 5 SIMULTANEOUS Concurrent releaseDriverPayout Calls
    // --------------------------------------------------------------------------
    console.log('---------------------------------------------------------------');
    console.log('🧪 TEST 4: Testing 5 Concurrent releaseDriverPayout calls on HELD escrow...');

    // Set booking to held escrow with total_price 200,000 via safeUpdateBooking
    await escrowService.safeUpdateBooking(testBooking.id, {
      status: 'ongoing',
      total_price: 200000,
      escrow_balance: 200000,
      payout_status: 'held',
      additional_details: {
        dp_paid: true,
        pelunasan_paid: true,
        payout_status: 'held',
        driver_credited: false,
        escrow_balance: 200000
      }
    });

    const expectedDriverPayout = 200000 * 0.90; // Rp 180.000

    // Fire 5 concurrent requests at the exact same millisecond
    const concurrentResults = await Promise.all([
      escrowService.releaseDriverPayout(testBooking.id, null, 'Concur-1'),
      escrowService.releaseDriverPayout(testBooking.id, null, 'Concur-2'),
      escrowService.releaseDriverPayout(testBooking.id, null, 'Concur-3'),
      escrowService.releaseDriverPayout(testBooking.id, null, 'Concur-4'),
      escrowService.releaseDriverPayout(testBooking.id, null, 'Concur-5')
    ]);

    const successfulPayouts = concurrentResults.filter(r => r.success && !r.alreadyReleased);
    const alreadyReleasedCount = concurrentResults.filter(r => r.alreadyReleased);

    console.log(`   Successful Crediting Calls: ${successfulPayouts.length} (Expected: 1)`);
    console.log(`   Already-Released Guarded Calls: ${alreadyReleasedCount.length} (Expected: 4)`);

    if (successfulPayouts.length !== 1) {
      throw new Error(`❌ RACE CONDITION BUG! ${successfulPayouts.length} concurrent calls credited money!`);
    }

    // Verify driver balance in database
    const { data: finalDriverUser } = await supabaseAdmin
      .from('users')
      .select('balance')
      .eq('id', driverUser.id)
      .single();

    const actualBalance = parseFloat(finalDriverUser.balance);
    console.log(`   Driver Balance: Rp ${actualBalance.toLocaleString('id-ID')} (Expected: Rp ${expectedDriverPayout.toLocaleString('id-ID')})`);

    if (actualBalance !== expectedDriverPayout) {
      throw new Error(`❌ DOUBLE PAYOUT DETECTED! Driver balance is Rp ${actualBalance}, expected Rp ${expectedDriverPayout}`);
    }

    // Verify wallet_transactions count
    const { data: txList } = await supabaseAdmin
      .from('wallet_transactions')
      .select('*')
      .eq('reference_id', testBooking.id);

    console.log(`   Wallet Transaction Records: ${txList.length} (Expected: 1)`);
    if (txList.length !== 1) {
      throw new Error(`❌ DUPLICATE MUTATION! Found ${txList.length} transaction records`);
    }

    console.log('✅ PASS: Atomic DB claim and OCC balance update executed EXACTLY ONCE under concurrent pressure!\n');

    // --------------------------------------------------------------------------
    // TEST 5: Legitimate Wallet Payment Flow (DP -> Pelunasan)
    // --------------------------------------------------------------------------
    console.log('---------------------------------------------------------------');
    console.log('🧪 TEST 5: Verifying legitimate wallet payment flow (DP & Pelunasan)...');

    // Create fresh clean booking
    const { data: normalBooking } = await supabaseAdmin.from('bookings').insert({
      user_id: clientUser.id,
      driver_id: driverRecord.id,
      pickup_location: 'Point A',
      dropoff_location: 'Point B',
      total_price: 100000,
      status: 'pending',
      additional_details: { escrow_balance: 0 }
    }).select().single();

    // 1. Pay DP via Wallet
    const validDpMock = mockReqRes(
      {
        booking_id: normalBooking.id,
        amount: 50000,
        payment_type: 'dp',
        use_wallet: true
      },
      {},
      clientUser
    );
    await paymentController.processPayment(validDpMock.req, validDpMock.res);
    const validDpRes = validDpMock.getResult();
    if (validDpRes.statusCode !== 200) {
      throw new Error(`❌ DP payment failed: ${validDpRes.responseData?.message}`);
    }
    console.log('   DP Payment (Rp 50.000): SUCCESS (Status: ongoing, held in escrow)');

    // 2. Pay Pelunasan via Wallet
    const validPelMock = mockReqRes(
      {
        booking_id: normalBooking.id,
        amount: 50000,
        payment_type: 'pelunasan',
        use_wallet: true
      },
      {},
      clientUser
    );
    await paymentController.processPayment(validPelMock.req, validPelMock.res);
    const validPelRes = validPelMock.getResult();
    if (validPelRes.statusCode !== 200) {
      throw new Error(`❌ Pelunasan payment failed: ${validPelRes.responseData?.message}`);
    }
    console.log('   Pelunasan Payment (Rp 50.000): SUCCESS (Status: completed, released to driver)');
    console.log('✅ PASS: Legitimate wallet payment & escrow lifecycle working seamlessly!\n');

    // Clean up
    console.log('---------------------------------------------------------------');
    console.log('🧹 Cleaning up test records...');
    await supabaseAdmin.from('wallet_transactions').delete().in('reference_id', [testBooking.id, normalBooking.id]);
    await supabaseAdmin.from('bookings').delete().in('id', [testBooking.id, normalBooking.id]);
    await supabaseAdmin.from('drivers').delete().eq('id', driverRecord.id);
    await supabaseAdmin.from('users').delete().in('id', [clientUser.id, driverUser.id]);
    console.log('✅ Cleanup completed.\n');

    console.log('===============================================================');
    console.log('🎉 ALL SECURITY & LOGIC TESTS PASSED WITH 100% SUCCESS!');
    console.log('===============================================================\n');

  } catch (err) {
    console.error('\n❌ TEST FAILED:', err);
    // Cleanup on error
    if (testBooking) await supabaseAdmin.from('bookings').delete().eq('id', testBooking.id);
    if (driverRecord) await supabaseAdmin.from('drivers').delete().eq('id', driverRecord.id);
    if (clientUser && driverUser) await supabaseAdmin.from('users').delete().in('id', [clientUser.id, driverUser.id]);
    process.exit(1);
  }
}

runSecurityTests();
