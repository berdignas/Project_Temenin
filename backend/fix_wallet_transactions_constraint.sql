-- ==============================================================================
-- FIX WALLET TRANSACTIONS CHECK CONSTRAINT MIGRATION
-- Eksekusi file ini di: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================
-- Memperbaiki error: "new row for relation wallet_transactions violates check constraint"
-- Skema lama hanya mengizinkan: ('topup', 'trip_income', 'withdrawal', 'commission_deduction')
-- Skema baru mengizinkan seluruh tipe mutasi valid yang digunakan oleh sistem:
--   - TOPUP, TOPUP_ADMIN
--   - TRIP_INCOME
--   - WITHDRAWAL, WITHDRAWAL_PENDING, WITHDRAWAL_COMPLETED
--   - REFUND, REFUND_WITHDRAWAL
--   - COMMISSION_DEDUCTION
--   - DP_FORFEIT_COMPENSATION
--   - PAYMENT, BOOKING_PAYMENT
-- Evaluasi menggunakan UPPER(type) sehingga aman baik format huruf kecil maupun besar.
-- ==============================================================================

DO $$
BEGIN
    -- 1. Hapus check constraint lama jika ada
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_schema = 'public' 
          AND table_name = 'wallet_transactions' 
          AND constraint_name = 'wallet_transactions_type_check'
    ) THEN
        ALTER TABLE public.wallet_transactions 
        DROP CONSTRAINT wallet_transactions_type_check;
    END IF;

    -- 2. Pasang constraint baru yang komprehensif dan case-insensitive
    ALTER TABLE public.wallet_transactions 
    ADD CONSTRAINT wallet_transactions_type_check 
    CHECK (UPPER(type) IN (
        'TOPUP',
        'TOPUP_ADMIN',
        'TRIP_INCOME',
        'WITHDRAWAL',
        'WITHDRAWAL_PENDING',
        'WITHDRAWAL_COMPLETED',
        'REFUND',
        'REFUND_WITHDRAWAL',
        'COMMISSION_DEDUCTION',
        'DP_FORFEIT_COMPENSATION',
        'PAYMENT',
        'BOOKING_PAYMENT'
    ));

    RAISE NOTICE 'Berhasil memperbarui constraint wallet_transactions_type_check!';
END $$;
