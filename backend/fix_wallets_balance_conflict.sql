-- ==============================================================================
-- TEMENIN AJAA - FIX DUAL WALLET TABLE CONFLICT (users.balance vs public.wallets)
-- Eksekusi file ini di: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================
-- Memperbaiki masalah: Dana hasil pembagian penalti/forfeit masuk ke tabel fisik
-- public.wallets yang tidak pernah dibaca oleh siapapun, sementara saldo aktif
-- driver di public.users.balance tetap 0.
-- ==============================================================================

-- 1. Migrasikan saldo yang mungkin sempat tertinggal di tabel wallets fisik lama
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'wallets' AND table_type = 'BASE TABLE'
    ) THEN
        -- Tambahkan saldo tertahan dari tabel wallets ke users.balance
        UPDATE public.users u
        SET balance = u.balance + w.balance,
            updated_at = NOW()
        FROM public.wallets w
        WHERE u.id = w.user_id AND w.balance > 0;

        -- Hapus tabel fisik ganda
        DROP TABLE public.wallets CASCADE;
        RAISE NOTICE 'Tabel fisik public.wallets berhasil dimigrasikan ke users.balance dan dihapus.';
    END IF;
END $$;

-- 2. Buat View Kompatibilitas 'public.wallets' yang merujuk langsung ke public.users
CREATE OR REPLACE VIEW public.wallets AS
SELECT 
    id,
    id AS user_id,
    role,
    balance,
    0.00::DECIMAL(12,2) AS escrow_held,
    created_at,
    updated_at
FROM public.users;

-- 3. Perbarui fungsi execute_dp_forfeit agar menyalurkan dana langsung ke users.balance & wallet_transactions
CREATE OR REPLACE FUNCTION public.execute_dp_forfeit(
    p_transaction_id UUID,
    p_admin_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_trx RECORD;
    v_driver_share DECIMAL(12,2);
    v_system_share DECIMAL(12,2);
    v_driver_user_id UUID;
BEGIN
    SELECT * INTO v_trx FROM public.payment_transactions WHERE id = p_transaction_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Transaksi tidak ditemukan');
    END IF;

    IF v_trx.status = 'FORFEITED' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Transaksi sudah berstatus FORFEITED');
    END IF;

    -- Hitung bagi hasil 50% Driver dan 50% Platform Fee
    v_driver_share := ROUND(v_trx.amount * 0.50, 2);
    v_system_share := v_trx.amount - v_driver_share;

    -- Update status transaksi pembayaran
    UPDATE public.payment_transactions 
    SET status = 'FORFEITED',
        processed_at = NOW(),
        admin_verified_by = p_admin_id,
        admin_notes = COALESCE(admin_notes || ' | ', '') || 'DP Hangus karena pembatalan sepihak. Bagi hasil 50% Driver / 50% Kas Platform.'
    WHERE id = p_transaction_id;

    -- Cari user_id driver dari recipient_id atau via booking -> drivers
    v_driver_user_id := v_trx.recipient_id;
    IF v_driver_user_id IS NULL AND v_trx.booking_id IS NOT NULL THEN
        SELECT d.user_id INTO v_driver_user_id
        FROM public.bookings b
        JOIN public.drivers d ON d.id = b.driver_id
        WHERE b.id = v_trx.booking_id;
    END IF;

    -- Kreditkan hak bagi hasil 50% langsung ke users.balance dan catat ke buku besar
    IF v_driver_user_id IS NOT NULL THEN
        -- a) Update saldo pengguna/driver asli
        UPDATE public.users 
        SET balance = balance + v_driver_share,
            updated_at = NOW()
        WHERE id = v_driver_user_id;

        -- b) Masukkan riwayat mutasi resmi ke wallet_transactions
        INSERT INTO public.wallet_transactions (
            user_id,
            type,
            amount,
            description,
            reference_id,
            created_at
        ) VALUES (
            v_driver_user_id,
            'DP_FORFEIT_COMPENSATION',
            v_driver_share,
            'Kompensasi pembatalan sepihak pesanan (50% DP Forfeit)',
            COALESCE(v_trx.booking_id::text, p_transaction_id::text),
            NOW()
        );

        -- c) Catat audit log pembagian hasil jika tabel revenue_split_logs ada
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = 'revenue_split_logs'
        ) THEN
            INSERT INTO public.revenue_split_logs (
                booking_id, transaction_id, total_amount, driver_id,
                driver_share, driver_percentage, system_share, system_percentage, split_type
            ) VALUES (
                v_trx.booking_id, p_transaction_id, v_trx.amount, v_driver_user_id,
                v_driver_share, 50.00, v_system_share, 50.00, 'DP_CANCEL_FORFEIT'
            );
        END IF;
    END IF;

    -- Update status pesanan jika terhubung ke booking
    IF v_trx.booking_id IS NOT NULL THEN
        UPDATE public.bookings
        SET payout_status = 'forfeited',
            escrow_balance = 0,
            updated_at = NOW()
        WHERE id = v_trx.booking_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'DP berhasil dieksekusi hangus dengan pembagian 50% Driver dan 50% Sistem',
        'driver_share', v_driver_share,
        'system_share', v_system_share
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
