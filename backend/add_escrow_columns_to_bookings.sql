-- ==============================================================================
-- TEMENIN AJAA - MIGRATION: ADD ESCROW_BALANCE & PAYOUT_STATUS TO BOOKINGS
-- ==============================================================================
-- Run this query in Supabase Dashboard -> SQL Editor -> Run

ALTER TABLE public.bookings 
ADD COLUMN IF NOT EXISTS escrow_balance NUMERIC(12,2) DEFAULT 0.00;

ALTER TABLE public.bookings 
ADD COLUMN IF NOT EXISTS payout_status TEXT DEFAULT 'held' 
CHECK (payout_status IN ('held', 'released', 'cancelled', 'refunded', 'forfeited'));

-- Index for performance on payout status lookups
CREATE INDEX IF NOT EXISTS idx_bookings_payout_status ON public.bookings(payout_status);

-- Update existing records if any
UPDATE public.bookings 
SET escrow_balance = COALESCE((additional_details->>'escrow_balance')::numeric, 0.00),
    payout_status = COALESCE(additional_details->>'payout_status', CASE WHEN status = 'completed' THEN 'released' ELSE 'held' END)
WHERE escrow_balance IS NULL OR payout_status IS NULL;
