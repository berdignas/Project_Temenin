-- ==============================================================================
-- TEMENIN AJAA - ADMIN FINANCE, ESCROW & REVENUE SPLIT SCHEMA
-- ==============================================================================
-- Memperbaiki konflik saldo ganda (users.balance vs public.wallets).
-- Single source of truth untuk seluruh saldo adalah: public.users.balance.
-- ==============================================================================

-- 1. Migrasi & View Wallets (Single Source of Truth: public.users.balance)
-- Menghilangkan tabel fisik duplikat public.wallets yang menyebabkan konflik saldo.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'wallets' AND table_type = 'BASE TABLE'
    ) THEN
        -- Transfer saldo tertinggal di tabel wallets lama jika ada ke users.balance
        UPDATE public.users u
        SET balance = u.balance + w.balance
        FROM public.wallets w
        WHERE u.id = w.user_id AND w.balance > 0;

        DROP TABLE public.wallets CASCADE;
    END IF;
END $$;

-- View Kompatibilitas Wallets -> membaca langsung dari users.balance
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

-- 2. Table Payment Transactions (DP, Pelunasan, TopUp, Withdrawal, Forfeit)
CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    recipient_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    type VARCHAR(30) NOT NULL CHECK (type IN ('DP', 'PELUNASAN', 'TOPUP', 'WITHDRAWAL', 'FORFEIT_DISBURSEMENT')),
    amount DECIMAL(12,2) NOT NULL,
    unique_code INT DEFAULT 0,
    total_payable DECIMAL(12,2) NOT NULL,
    proof_url TEXT,
    bank_name VARCHAR(50),
    account_number VARCHAR(50),
    account_name VARCHAR(100),
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING' 
        CHECK (status IN ('PENDING', 'HELD_IN_ESCROW', 'APPROVED', 'REJECTED', 'FORFEITED', 'DISBURSED')),
    sla_deadline TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
    ocr_match_score INT DEFAULT 0,
    admin_notes TEXT,
    admin_verified_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Table Revenue Split Logs (Audit Trail 50-50 Forfeit & Service Fee Split)
CREATE TABLE IF NOT EXISTS public.revenue_split_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
    transaction_id UUID REFERENCES public.payment_transactions(id) ON DELETE SET NULL,
    total_amount DECIMAL(12,2) NOT NULL,
    driver_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    driver_share DECIMAL(12,2) NOT NULL,
    driver_percentage DECIMAL(5,2) NOT NULL,
    system_share DECIMAL(12,2) NOT NULL,
    system_percentage DECIMAL(5,2) NOT NULL,
    split_type VARCHAR(30) NOT NULL CHECK (split_type IN ('NORMAL_COMPLETION', 'DP_CANCEL_FORFEIT')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexing for Admin Performance & SLA Queries
CREATE INDEX IF NOT EXISTS idx_payment_transactions_status ON public.payment_transactions(status);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_sla ON public.payment_transactions(sla_deadline);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_type ON public.payment_transactions(type);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_user ON public.payment_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_booking ON public.payment_transactions(booking_id);

-- Function to Auto-Execute DP Forfeit (50% Driver / 50% System)
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

    -- Calculate 50-50 Split for DP Cancellation
    v_driver_share := ROUND(v_trx.amount * 0.50, 2);
    v_system_share := v_trx.amount - v_driver_share;

    -- Update Transaction Status
    UPDATE public.payment_transactions 
    SET status = 'FORFEITED',
        processed_at = NOW(),
        admin_verified_by = p_admin_id,
        admin_notes = COALESCE(admin_notes || ' | ', '') || 'DP Hangus karena pembatalan tiba-tiba. Split 50% Driver / 50% Kas Platform.'
    WHERE id = p_transaction_id;

    -- Cari user_id driver dari recipient_id atau melalui booking -> drivers
    v_driver_user_id := v_trx.recipient_id;
    IF v_driver_user_id IS NULL AND v_trx.booking_id IS NOT NULL THEN
        SELECT d.user_id INTO v_driver_user_id
        FROM public.bookings b
        JOIN public.drivers d ON d.id = b.driver_id
        WHERE b.id = v_trx.booking_id;
    END IF;

    -- Credit 50% ke Saldo Driver Asli (public.users.balance) & Catat Buku Besar (wallet_transactions)
    IF v_driver_user_id IS NOT NULL THEN
        -- 1. Tambah saldo aktif driver di users.balance
        UPDATE public.users 
        SET balance = balance + v_driver_share,
            updated_at = NOW()
        WHERE id = v_driver_user_id;

        -- 2. Catat riwayat mutasi resmi ke wallet_transactions
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

        -- 3. Catat audit trail revenue split
        INSERT INTO public.revenue_split_logs (
            booking_id, transaction_id, total_amount, driver_id,
            driver_share, driver_percentage, system_share, system_percentage, split_type
        ) VALUES (
            v_trx.booking_id, p_transaction_id, v_trx.amount, v_driver_user_id,
            v_driver_share, 50.00, v_system_share, 50.00, 'DP_CANCEL_FORFEIT'
        );
    END IF;

    -- Update status pesanan jika terkait booking
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
