-- ==============================================================================
-- TEMENIN AJAA - FIX DUAL TABLE DIVERGENCE & MISSING COLUMNS
-- Eksekusi file ini di: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================

-- 1. Tambahkan kolom pendukung ke payment_transactions jika belum ada
-- Termasuk processed_at, bank_name, account_number, account_name, recipient_id
ALTER TABLE public.payment_transactions 
    ADD COLUMN IF NOT EXISTS processed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS bank_name VARCHAR(50),
    ADD COLUMN IF NOT EXISTS account_number VARCHAR(50),
    ADD COLUMN IF NOT EXISTS account_name VARCHAR(100),
    ADD COLUMN IF NOT EXISTS recipient_id UUID,
    ADD COLUMN IF NOT EXISTS ocr_match_score INT DEFAULT 0;

-- 2. Migrasi data lama (jika ada) dan hapus objek fisik/view lama secara aman
DO $$
BEGIN
    -- Cek jika ada tabel fisik driver_withdrawals
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'driver_withdrawals' AND table_type = 'BASE TABLE'
    ) THEN
        -- Migrasikan data historis jika ada
        INSERT INTO public.payment_transactions (
            id,
            user_id,
            type,
            amount,
            total_payable,
            status,
            admin_notes,
            bank_name,
            account_number,
            account_name,
            processed_at,
            created_at
        )
        SELECT 
            dw.id,
            d.user_id,
            'WITHDRAWAL',
            dw.amount,
            dw.amount,
            UPPER(dw.status),
            COALESCE(dw.admin_notes, '') || ' [Metode: ' || COALESCE(dw.payment_method, '') || ']',
            dw.payment_method,
            dw.account_number,
            dw.account_name,
            dw.processed_at,
            dw.created_at
        FROM public.driver_withdrawals dw
        JOIN public.drivers d ON d.id = dw.driver_id
        ON CONFLICT (id) DO NOTHING;

        -- Hapus tabel fisik terpisah driver_withdrawals
        DROP TABLE public.driver_withdrawals CASCADE;
        RAISE NOTICE 'Tabel fisik driver_withdrawals berhasil dimigrasikan dan diganti dengan View.';
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_schema = 'public' AND table_name = 'driver_withdrawals'
    ) THEN
        DROP VIEW public.driver_withdrawals CASCADE;
    END IF;
END $$;

-- 3. Buat Compatibility View 'driver_withdrawals' yang merujuk langsung ke payment_transactions
CREATE OR REPLACE VIEW public.driver_withdrawals AS
SELECT 
    pt.id,
    COALESCE(d.id, pt.user_id) AS driver_id,
    pt.user_id,
    pt.amount,
    COALESCE(
        pt.bank_name,
        CASE 
            WHEN pt.admin_notes ~ '^[{\[].*[}\]]$' THEN (pt.admin_notes::json->>'bank_name')
            ELSE NULL 
        END, 
        'Transfer Bank'
    ) AS payment_method,
    COALESCE(
        pt.account_number,
        CASE 
            WHEN pt.admin_notes ~ '^[{\[].*[}\]]$' THEN (pt.admin_notes::json->>'account_number')
            ELSE NULL 
        END, 
        '-'
    ) AS account_number,
    COALESCE(
        pt.account_name,
        CASE 
            WHEN pt.admin_notes ~ '^[{\[].*[}\]]$' THEN (pt.admin_notes::json->>'account_name')
            ELSE NULL 
        END, 
        u.full_name
    ) AS account_name,
    LOWER(pt.status) AS status,
    pt.admin_notes,
    pt.processed_at,
    pt.created_at
FROM public.payment_transactions pt
LEFT JOIN public.drivers d ON d.user_id = pt.user_id
LEFT JOIN public.users u ON u.id = pt.user_id
WHERE UPPER(pt.type) = 'WITHDRAWAL';

-- 4. Perbarui View Ringkasan Statistik Admin Dashboard agar antrean penarikan dana akurat
CREATE OR REPLACE VIEW public.admin_dashboard_stats AS
SELECT 
    (SELECT COUNT(*) FROM public.users WHERE role = 'client') AS total_clients,
    (SELECT COUNT(*) FROM public.drivers) AS total_drivers,
    (SELECT COUNT(*) FROM public.drivers WHERE status = 'pending') AS pending_driver_verifications,
    (SELECT COUNT(*) FROM public.bookings) AS total_bookings,
    (SELECT COUNT(*) FROM public.bookings WHERE status = 'ongoing') AS active_ongoing_bookings,
    (SELECT COALESCE(SUM(total_price), 0) FROM public.bookings WHERE status = 'completed') AS total_revenue,
    (SELECT COUNT(*) FROM public.payment_transactions WHERE UPPER(type) = 'WITHDRAWAL' AND UPPER(status) = 'PENDING') AS pending_withdrawals;
