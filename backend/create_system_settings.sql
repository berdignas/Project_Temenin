-- ============================================================================
-- TEMENIN AJAA - SYSTEM SETTINGS & PRICING CONFIGURATION SCHEMA
-- Eksekusi file ini di: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.system_settings (
    id TEXT PRIMARY KEY DEFAULT 'pricing_config',
    price_per_km NUMERIC(10,2) NOT NULL DEFAULT 5000,
    price_per_km_sporty NUMERIC(10,2) NOT NULL DEFAULT 7500,
    min_ride_price NUMERIC(10,2) NOT NULL DEFAULT 15000,
    base_hourly_price NUMERIC(10,2) NOT NULL DEFAULT 50000,
    min_hourly_price NUMERIC(10,2) NOT NULL DEFAULT 35000,
    sleep_call_package_price NUMERIC(10,2) NOT NULL DEFAULT 45000,
    virtual_counseling_hourly_price NUMERIC(10,2) NOT NULL DEFAULT 35000,
    gaming_buddy_per_match_price NUMERIC(10,2) NOT NULL DEFAULT 15000,
    commission_rate NUMERIC(5,2) NOT NULL DEFAULT 10,
    allow_negotiation_flexible_only BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Seed initial row if not exists
INSERT INTO public.system_settings (
    id,
    price_per_km,
    price_per_km_sporty,
    min_ride_price,
    base_hourly_price,
    min_hourly_price,
    sleep_call_package_price,
    virtual_counseling_hourly_price,
    gaming_buddy_per_match_price,
    commission_rate,
    allow_negotiation_flexible_only
) VALUES (
    'pricing_config',
    5000,
    7500,
    15000,
    50000,
    35000,
    45000,
    35000,
    15000,
    10,
    true
)
ON CONFLICT (id) DO NOTHING;
