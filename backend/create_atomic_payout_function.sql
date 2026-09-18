-- ==============================================================================
-- TEMENIN AJAA - ATOMIC ESCROW DRIVER PAYOUT WITH ROW-LEVEL LOCKING (POSTGRESQL)
-- Eksekusi di Supabase Dashboard -> SQL Editor -> Run
-- Menjamin eksekusi transaksi tunggal (BEGIN...COMMIT), aman dari race condition multi-instance (FOR UPDATE),
-- dan menjamin driver balance + booking status + audit log dieksekusi secara atomik.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.process_driver_payout_atomic(
    p_booking_id UUID,
    p_trigger_source TEXT DEFAULT 'System'
) RETURNS JSONB AS $$
DECLARE
    v_booking RECORD;
    v_driver RECORD;
    v_total_price NUMERIC(12,2);
    v_current_escrow NUMERIC(12,2);
    v_driver_income NUMERIC(12,2);
    v_platform_fee NUMERIC(12,2);
    v_is_pelunasan BOOLEAN;
    v_add_details JSONB;
    v_new_driver_balance NUMERIC(12,2);
BEGIN
    -- 1. ROW-LEVEL LOCK: SELECT FOR UPDATE on bookings
    -- Mengunci baris booking secara eksklusif di level database PostgreSQL
    -- Instance lain di Docker / PM2 cluster akan antre (block) sampai transaksi ini selesai.
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Booking not found'
        );
    END IF;

    v_add_details := COALESCE(v_booking.additional_details, '{}'::jsonb);

    -- 2. FAST IDEMPOTENCY CHECK (Aman di dalam baris yang terkunci)
    IF v_booking.payout_status = 'released' OR (v_add_details->>'driver_credited')::boolean = true THEN
        RETURN jsonb_build_object(
            'success', true,
            'already_released', true,
            'message', 'Payout has already been released to driver'
        );
    END IF;

    -- 3. VALIDASI DRIVER TERSEDIA
    IF v_booking.driver_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'No driver assigned to this booking'
        );
    END IF;

    -- 4. VALIDASI STATUS BATAL
    IF v_booking.status = 'cancelled' THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Pesanan telah dibatalkan, bagi hasil driver tidak dapat dicairkan'
        );
    END IF;

    -- 5. VERIFIKASI STATUS PELUNASAN (Anti Kebocoran Dana DP)
    v_is_pelunasan := (
        (v_add_details->>'pelunasan_paid')::boolean = true OR
        (v_add_details->>'final_paid')::boolean = true OR
        v_booking.sub_status IN ('paid', 'closed') OR
        (v_add_details->>'sub_status') IN ('paid', 'closed')
    );

    IF NOT v_is_pelunasan THEN
        RETURN jsonb_build_object(
            'success', false,
            'status', 'held',
            'reason', 'WAITING_PELUNASAN',
            'message', 'Pelunasan belum diselesaikan oleh klien. Dana bagi hasil driver tetap aman tertahan di escrow hingga pelunasan lunas.'
        );
    END IF;

    -- 6. KALKULASI DANA & VALIDASI KECUKUPAN ESCROW (Anti Defisit Kas)
    v_total_price := COALESCE(v_booking.total_price, v_booking.escrow_balance, (v_add_details->>'escrow_balance')::numeric, 0);
    v_current_escrow := COALESCE(v_booking.escrow_balance, (v_add_details->>'escrow_balance')::numeric, 0);
    v_driver_income := ROUND(v_total_price * 0.90, 2);
    v_platform_fee := ROUND(v_total_price * 0.10, 2);

    IF v_driver_income <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Nilai bagi hasil driver tidak valid (<= 0)'
        );
    END IF;

    IF v_current_escrow < (v_driver_income - 1) THEN
        RETURN jsonb_build_object(
            'success', false,
            'status', 'held',
            'reason', 'INSUFFICIENT_ESCROW',
            'message', 'Saldo escrow tidak mencukupi untuk pembayaran bagi hasil driver. Pencairan dibatalkan.'
        );
    END IF;

    -- 7. FETCH DRIVER ACCOUNT & AMBIL USER_ID
    SELECT id, user_id INTO v_driver
    FROM public.drivers
    WHERE id = v_booking.driver_id;

    IF NOT FOUND OR v_driver.user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Driver record not found'
        );
    END IF;

    -- 8. EKSEKUSI TRANSAKSI ATOMIK SECARA BERSAMAAN (ALL-OR-NOTHING):
    -- a) Update Saldo Driver (users.balance) dengan Row-Level Lock
    UPDATE public.users
    SET balance = COALESCE(balance, 0) + v_driver_income,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_driver.user_id
    RETURNING balance INTO v_new_driver_balance;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Driver user account not found for ID %', v_driver.user_id;
    END IF;

    -- b) Update Booking: payout_status = released, escrow_balance = 0
    v_add_details := jsonb_set(v_add_details, '{driver_credited}', 'true'::jsonb);
    v_add_details := jsonb_set(v_add_details, '{payout_status}', '"released"'::jsonb);
    v_add_details := jsonb_set(v_add_details, '{payout_amount}', to_jsonb(v_driver_income));
    v_add_details := jsonb_set(v_add_details, '{payout_at}', to_jsonb(timezone('utc'::text, now())::text));
    v_add_details := jsonb_set(v_add_details, '{payout_trigger}', to_jsonb(p_trigger_source));

    UPDATE public.bookings
    SET payout_status = 'released',
        escrow_balance = 0,
        additional_details = v_add_details,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    -- c) Insert Mutasi Wallet (wallet_transactions)
    INSERT INTO public.wallet_transactions (
        user_id,
        type,
        amount,
        description,
        reference_id,
        created_at
    ) VALUES (
        v_driver.user_id,
        'trip_income',
        v_driver_income,
        'Pendapatan pesanan #' || SUBSTRING(p_booking_id::text, 1, 8) || ' (' || p_trigger_source || ')',
        p_booking_id,
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'already_released', false,
        'driver_income', v_driver_income,
        'driver_user_id', v_driver.user_id,
        'new_balance', v_new_driver_balance,
        'message', 'Bagi hasil sebesar Rp ' || v_driver_income::text || ' berhasil dicairkan ke saldo driver'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
