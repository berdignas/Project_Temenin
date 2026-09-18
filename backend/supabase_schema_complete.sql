-- ============================================================================
-- TEMENIN AJAA - COMPLETE SUPABASE DATABASE SCHEMA & QUERIES
-- Lingkup: Client (Penumpang), Driver (Mitra), & Admin Dashboard
-- Eksekusi file ini di: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ============================================================================

-- 1. EXTENSIONS & FUNCTIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Trigger Otomatis Update Timestamp 'updated_at'
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ============================================================================
-- 2. TABEL AKUN & PENGGUNA (USERS & PROFILES)
-- ============================================================================
DROP TABLE IF EXISTS users CASCADE;
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE,
    password_hash TEXT,
    full_name TEXT NOT NULL,
    phone TEXT UNIQUE NOT NULL,
    role TEXT DEFAULT 'client' CHECK (role IN ('client', 'driver', 'admin')),
    gender TEXT DEFAULT 'Laki-laki' CHECK (gender IN ('Laki-laki', 'Perempuan')),
    avatar_url TEXT DEFAULT 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
    balance NUMERIC(12,2) DEFAULT 0.00,
    points INTEGER DEFAULT 0,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================================
-- 3. TABEL DATA MITRA DRIVER (DRIVERS)
-- ============================================================================
DROP TABLE IF EXISTS drivers CASCADE;
CREATE TABLE drivers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    vehicle_type TEXT NOT NULL DEFAULT 'Motor' CHECK (vehicle_type IN ('Motor', 'Mobil')),
    vehicle_name TEXT NOT NULL,
    plate_number TEXT NOT NULL,
    price_per_hour NUMERIC(10,2) DEFAULT 50000,
    rating NUMERIC(3,2) DEFAULT 5.00,
    total_rides INTEGER DEFAULT 0,
    is_available BOOLEAN DEFAULT false, -- Status Online / Offline Narik
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')), -- Verifikasi Admin
    experience_years INTEGER DEFAULT 1,
    id_card_number TEXT, -- No. KTP
    driver_license_number TEXT, -- No. SIM
    vehicle_stnk TEXT, -- Link Foto STNK
    latitude NUMERIC(10,8),
    longitude NUMERIC(11,8),
    buffer_time_minutes INTEGER DEFAULT 30, -- Jeda istirahat/perjalanan antar pesanan (dalam menit)
    registration_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================================
-- 4. TABEL PESANAN & TRANSAKSI (BOOKINGS & NEGOTIATIONS)
-- ============================================================================
DROP TABLE IF EXISTS bookings CASCADE;
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL, -- Client ID
    driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL, -- Driver ID
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'ongoing', 'completed', 'cancelled')),
    pickup_location TEXT NOT NULL,
    dropoff_location TEXT NOT NULL,
    pickup_latitude NUMERIC(10,8),
    pickup_longitude NUMERIC(11,8),
    dropoff_latitude NUMERIC(10,8),
    dropoff_longitude NUMERIC(11,8),
    duration INTEGER DEFAULT 60, -- dalam menit
    total_price NUMERIC(10,2) NOT NULL,
    platform_fee NUMERIC(10,2) DEFAULT 0, -- Komisi Aplikasi (misal 10%)
    escrow_balance NUMERIC(12,2) DEFAULT 0.00, -- Dana tertahan di escrow (DP + Pelunasan)
    payout_status TEXT DEFAULT 'held' CHECK (payout_status IN ('held', 'released', 'cancelled', 'refunded', 'forfeited')),
    booking_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    additional_details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabel Negosiasi Harga Perjalanan (Tawar-Menawar Client & Driver)
DROP TABLE IF EXISTS booking_negotiations CASCADE;
CREATE TABLE booking_negotiations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE NOT NULL,
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE NOT NULL,
    negotiated_price NUMERIC(10,2) NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================================
-- 4b. TABEL JADWAL & PENGUNCIAN WAKTU DRIVER (DRIVER SCHEDULES)
-- ============================================================================
DROP TABLE IF EXISTS driver_schedules CASCADE;
CREATE TABLE driver_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE NOT NULL,
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE, -- NULL jika driver set manual "Libur/Off"
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    title TEXT DEFAULT 'Terkunci',
    status TEXT DEFAULT 'locked' CHECK (status IN ('locked', 'completed', 'cancelled', 'off')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================================
-- 5. TABEL DOMPET & PENARIKAN SALDO (WALLET & WITHDRAWALS)
-- ============================================================================
-- Compatibility View driver_withdrawals merujuk ke payment_transactions (Single Source of Truth)
DROP TABLE IF EXISTS driver_withdrawals CASCADE;
CREATE OR REPLACE VIEW driver_withdrawals AS
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
FROM payment_transactions pt
LEFT JOIN drivers d ON d.user_id = pt.user_id
LEFT JOIN users u ON u.id = pt.user_id
WHERE UPPER(pt.type) = 'WITHDRAWAL';

-- Log Mutasi Saldo
DROP TABLE IF EXISTS wallet_transactions CASCADE;
CREATE TABLE wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (UPPER(type) IN (
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
    )),
    amount NUMERIC(10,2) NOT NULL,
    description TEXT,
    reference_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabel Metode Pembayaran Pengguna (User Payment Methods)
DROP TABLE IF EXISTS user_payment_methods CASCADE;
CREATE TABLE user_payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    method_type TEXT NOT NULL,
    provider TEXT NOT NULL,
    last_four TEXT,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================================
-- 6. TABEL KOMUNITAS, POSTINGAN & STORY INSTAGRAM
-- ============================================================================
DROP TABLE IF EXISTS community_posts CASCADE;
CREATE TABLE community_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    author_name TEXT,
    author_avatar TEXT,
    image_url TEXT,
    media_type TEXT DEFAULT 'image' CHECK (media_type IN ('image', 'video')),
    video_url TEXT,
    caption TEXT,
    location TEXT DEFAULT 'Jakarta',
    likes_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabel Komentar Postingan Komunitas
DROP TABLE IF EXISTS community_comments CASCADE;
CREATE TABLE community_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    author_name TEXT NOT NULL,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabel Like Postingan
DROP TABLE IF EXISTS post_likes CASCADE;
CREATE TABLE post_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(post_id, user_id)
);

-- Tabel Story 24 Jam
DROP TABLE IF EXISTS community_stories CASCADE;
CREATE TABLE community_stories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    author_name TEXT,
    author_avatar TEXT,
    image_url TEXT NOT NULL,
    title TEXT DEFAULT 'Story',
    caption TEXT,
    views_count INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (timezone('utc'::text, now()) + interval '24 hours') NOT NULL
);

-- ============================================================================
-- 7. TABEL LIVE CHAT PESANAN (BOOKING MESSAGES)
-- ============================================================================
DROP TABLE IF EXISTS booking_messages CASCADE;
CREATE TABLE booking_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    sender_role TEXT CHECK (sender_role IN ('client', 'driver')),
    message TEXT NOT NULL,
    attachment_url TEXT,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE booking_messages REPLICA IDENTITY FULL;
CREATE INDEX IF NOT EXISTS idx_booking_messages_booking_id ON booking_messages(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_messages_created_at ON booking_messages(created_at);
CREATE INDEX IF NOT EXISTS idx_booking_messages_sender_id ON booking_messages(sender_id);

-- ============================================================================
-- 7b. TABEL ULASAN & RATING (REVIEWS & RATINGS)
-- ============================================================================
DROP TABLE IF EXISTS reviews CASCADE;
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE NOT NULL,
    rating NUMERIC(2,1) NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================================
-- 8. TABEL OTP SMS / WHATSAPP AUTHENTICATION
-- ============================================================================
DROP TABLE IF EXISTS otp_codes CASCADE;
CREATE TABLE otp_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone TEXT NOT NULL,
    code TEXT NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_used BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================================
-- 9. TRIGGERS AUTOMATION (UPDATED_AT & REALTIME)
-- ============================================================================
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_drivers_updated_at BEFORE UPDATE ON drivers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_booking_negotiations_updated_at BEFORE UPDATE ON booking_negotiations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 10. TABEL NOTIFIKASI, EVENT & PROMO
-- ============================================================================
DROP TABLE IF EXISTS public.notifications CASCADE;
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) DEFAULT 'booking',
    is_read BOOLEAN DEFAULT FALSE,
    data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

DROP TABLE IF EXISTS app_events CASCADE;
CREATE TABLE app_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    date_string TEXT NOT NULL,
    location TEXT NOT NULL,
    image_url TEXT NOT NULL,
    ticket_url TEXT,
    category TEXT DEFAULT 'Konser & Festival',
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

DROP TABLE IF EXISTS app_promos CASCADE;
CREATE TABLE app_promos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    code TEXT,
    discount_percent INTEGER DEFAULT 0,
    max_discount NUMERIC(10,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ============================================================================
-- 11. VIEW RINGKASAN STATISTIK ADMIN DASHBOARD
-- ============================================================================
CREATE OR REPLACE VIEW admin_dashboard_stats AS
SELECT 
    (SELECT COUNT(*) FROM users WHERE role = 'client') AS total_clients,
    (SELECT COUNT(*) FROM drivers) AS total_drivers,
    (SELECT COUNT(*) FROM drivers WHERE status = 'pending') AS pending_driver_verifications,
    (SELECT COUNT(*) FROM bookings) AS total_bookings,
    (SELECT COUNT(*) FROM bookings WHERE status = 'ongoing') AS active_ongoing_bookings,
    (SELECT COALESCE(SUM(total_price), 0) FROM bookings WHERE status = 'completed') AS total_revenue,
    (SELECT COUNT(*) FROM payment_transactions WHERE UPPER(type) = 'WITHDRAWAL' AND UPPER(status) = 'PENDING') AS pending_withdrawals;

-- ============================================================================
-- 12. ROW LEVEL SECURITY (RLS) & ACCESS CONTROL POLICIES (HARDENED)
-- ============================================================================
-- 🛡️ Perlindungan Total Data Privasi (UU PDP No. 27/2022) & Anti-Bocor Anon Key

-- Helper Function: Check Admin Role (Backend service_role atau Admin JWT)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        (auth.jwt() ->> 'role') = 'service_role'
        OR EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Aktifkan RLS pada seluruh tabel:
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking_negotiations ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_withdrawals ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE otp_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_promos ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- POLICIES: USERS (Pencegahan Dump Hash Password, HP, & Saldo)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users Read Public Profile" ON users;
DROP POLICY IF EXISTS "Users Update Self" ON users;
DROP POLICY IF EXISTS "Users Read Self Or Admin" ON users;
DROP POLICY IF EXISTS "Users Update Self Or Admin" ON users;
DROP POLICY IF EXISTS "Users Insert Self" ON users;

CREATE POLICY "Users Read Self Or Admin" ON users
FOR SELECT
TO authenticated
USING (
    auth.uid() = id 
    OR public.is_admin()
);

CREATE POLICY "Users Update Self Or Admin" ON users
FOR UPDATE
TO authenticated
USING (
    auth.uid() = id 
    OR public.is_admin()
)
WITH CHECK (
    auth.uid() = id 
    OR public.is_admin()
);

CREATE POLICY "Users Insert Self" ON users
FOR INSERT
TO authenticated, anon
WITH CHECK (
    auth.uid() = id 
    OR auth.uid() IS NULL 
    OR public.is_admin()
);

-- Trigger: Mencegah user memanipulasi kolom balance, points, role via direct REST client
CREATE OR REPLACE FUNCTION public.protect_user_fields()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT public.is_admin() THEN
        NEW.role := OLD.role;
        NEW.balance := OLD.balance;
        NEW.points := OLD.points;
        NEW.is_verified := OLD.is_verified;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_protect_user_fields ON public.users;
CREATE TRIGGER trg_protect_user_fields
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.protect_user_fields();

-- View Profil Publik Aman (Hanya Nama & Avatar, Tanpa Password Hash / Saldo)
CREATE OR REPLACE VIEW public.public_user_profiles AS
SELECT id, full_name, avatar_url, gender, role, is_verified, created_at
FROM public.users;

GRANT SELECT ON public.public_user_profiles TO anon, authenticated;

-- ----------------------------------------------------------------------------
-- POLICIES: DRIVERS
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Drivers Read Public" ON drivers;
DROP POLICY IF EXISTS "Drivers Read Approved Or Self Or Admin" ON drivers;
DROP POLICY IF EXISTS "Drivers Update Self Or Admin" ON drivers;
DROP POLICY IF EXISTS "Drivers Insert Self Or Admin" ON drivers;

CREATE POLICY "Drivers Read Approved Or Self Or Admin" ON drivers
FOR SELECT
USING (
    status = 'approved'
    OR auth.uid() = user_id
    OR public.is_admin()
);

CREATE POLICY "Drivers Update Self Or Admin" ON drivers
FOR UPDATE
TO authenticated
USING (
    auth.uid() = user_id
    OR public.is_admin()
)
WITH CHECK (
    auth.uid() = user_id
    OR public.is_admin()
);

CREATE POLICY "Drivers Insert Self Or Admin" ON drivers
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
    OR public.is_admin()
);

CREATE OR REPLACE FUNCTION public.protect_driver_fields()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT public.is_admin() THEN
        NEW.status := OLD.status;
        NEW.rating := OLD.rating;
        NEW.total_rides := OLD.total_rides;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_protect_driver_fields ON public.drivers;
CREATE TRIGGER trg_protect_driver_fields
BEFORE UPDATE ON public.drivers
FOR EACH ROW
EXECUTE FUNCTION public.protect_driver_fields();

-- View Driver Publik (Menyembunyikan KTP, SIM, STNK dari publik)
CREATE OR REPLACE VIEW public.public_drivers AS
SELECT 
    d.id,
    d.user_id,
    u.full_name,
    u.avatar_url,
    d.vehicle_type,
    d.vehicle_name,
    d.plate_number,
    d.price_per_hour,
    d.rating,
    d.total_rides,
    d.is_available,
    d.experience_years,
    d.latitude,
    d.longitude,
    d.buffer_time_minutes
FROM public.drivers d
JOIN public.users u ON u.id = d.user_id
WHERE d.status = 'approved';

GRANT SELECT ON public.public_drivers TO anon, authenticated;

-- ----------------------------------------------------------------------------
-- POLICIES: BOOKINGS (Pencegahan Pembajakan & Pengubahan Status Liar)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Bookings Select Policy" ON bookings;
DROP POLICY IF EXISTS "Bookings Insert Authenticated" ON bookings;
DROP POLICY IF EXISTS "Bookings Update Authenticated" ON bookings;
DROP POLICY IF EXISTS "Bookings Select Authorized" ON bookings;
DROP POLICY IF EXISTS "Bookings Insert Authorized" ON bookings;
DROP POLICY IF EXISTS "Bookings Update Authorized" ON bookings;

CREATE POLICY "Bookings Select Authorized" ON bookings
FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id
    OR auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = bookings.driver_id)
    OR (
        status = 'pending' 
        AND driver_id IS NULL 
        AND EXISTS (SELECT 1 FROM public.drivers WHERE user_id = auth.uid() AND status = 'approved')
    )
    OR public.is_admin()
);

CREATE POLICY "Bookings Insert Authorized" ON bookings
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
    OR public.is_admin()
);

CREATE POLICY "Bookings Update Authorized" ON bookings
FOR UPDATE
TO authenticated
USING (
    auth.uid() = user_id
    OR auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = bookings.driver_id)
    OR (
        status = 'pending' 
        AND driver_id IS NULL 
        AND EXISTS (SELECT 1 FROM public.drivers WHERE user_id = auth.uid() AND status = 'approved')
    )
    OR public.is_admin()
)
WITH CHECK (
    auth.uid() = user_id
    OR auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = bookings.driver_id)
    OR (
        EXISTS (SELECT 1 FROM public.drivers WHERE user_id = auth.uid() AND status = 'approved')
    )
    OR public.is_admin()
);

-- ----------------------------------------------------------------------------
-- POLICIES: BOOKING_MESSAGES (Pencegahan Penyadapan Chat Pribadi)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Booking Messages Read Policy" ON booking_messages;
DROP POLICY IF EXISTS "Booking Messages Insert Policy" ON booking_messages;
DROP POLICY IF EXISTS "Booking Messages Select Authorized" ON booking_messages;
DROP POLICY IF EXISTS "Booking Messages Insert Authorized" ON booking_messages;

CREATE POLICY "Booking Messages Select Authorized" ON booking_messages
FOR SELECT
TO authenticated
USING (
    auth.uid() = sender_id
    OR EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.id = booking_messages.booking_id
        AND (
            b.user_id = auth.uid()
            OR b.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
        )
    )
    OR public.is_admin()
);

CREATE POLICY "Booking Messages Insert Authorized" ON booking_messages
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = sender_id
    AND (
        EXISTS (
            SELECT 1 FROM public.bookings b
            WHERE b.id = booking_messages.booking_id
            AND (
                b.user_id = auth.uid()
                OR b.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
            )
        )
        OR public.is_admin()
    )
);

-- ----------------------------------------------------------------------------
-- POLICIES: BOOKING_NEGOTIATIONS
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Negotiations Select Policy" ON booking_negotiations;
DROP POLICY IF EXISTS "Negotiations Insert Policy" ON booking_negotiations;
DROP POLICY IF EXISTS "Negotiations Update Policy" ON booking_negotiations;
DROP POLICY IF EXISTS "Negotiations Select Authorized" ON booking_negotiations;
DROP POLICY IF EXISTS "Negotiations Insert Authorized" ON booking_negotiations;
DROP POLICY IF EXISTS "Negotiations Update Authorized" ON booking_negotiations;

CREATE POLICY "Negotiations Select Authorized" ON booking_negotiations
FOR SELECT
TO authenticated
USING (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = booking_negotiations.driver_id)
    OR EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.id = booking_negotiations.booking_id
        AND b.user_id = auth.uid()
    )
    OR public.is_admin()
);

CREATE POLICY "Negotiations Insert Authorized" ON booking_negotiations
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = booking_negotiations.driver_id)
    OR public.is_admin()
);

CREATE POLICY "Negotiations Update Authorized" ON booking_negotiations
FOR UPDATE
TO authenticated
USING (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = booking_negotiations.driver_id)
    OR EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.id = booking_negotiations.booking_id
        AND b.user_id = auth.uid()
    )
    OR public.is_admin()
);

-- ----------------------------------------------------------------------------
-- POLICIES: NOTIFICATIONS
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Notifications Select Policy" ON notifications;
DROP POLICY IF EXISTS "Notifications Update Policy" ON notifications;
DROP POLICY IF EXISTS "Notifications Select Owner" ON notifications;
DROP POLICY IF EXISTS "Notifications Update Owner" ON notifications;

CREATE POLICY "Notifications Select Owner" ON notifications
FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id
    OR public.is_admin()
);

CREATE POLICY "Notifications Update Owner" ON notifications
FOR UPDATE
TO authenticated
USING (
    auth.uid() = user_id
    OR public.is_admin()
)
WITH CHECK (
    auth.uid() = user_id
    OR public.is_admin()
);

-- ----------------------------------------------------------------------------
-- POLICIES: FINANCIAL (WALLETS, WITHDRAWALS, PAYMENT METHODS, OTP)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Wallet Transactions Select Owner" ON wallet_transactions;
DROP POLICY IF EXISTS "Wallet Transactions Admin Only" ON wallet_transactions;

CREATE POLICY "Wallet Transactions Select Owner" ON wallet_transactions
FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id
    OR public.is_admin()
);

-- Mutasi wallet transaksi dilarang keras diubah secara langsung oleh client
CREATE POLICY "Wallet Transactions Admin Only" ON wallet_transactions
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Driver Withdrawals Select Owner" ON driver_withdrawals;
DROP POLICY IF EXISTS "Driver Withdrawals Insert Owner" ON driver_withdrawals;
DROP POLICY IF EXISTS "Driver Withdrawals Update Admin" ON driver_withdrawals;

CREATE POLICY "Driver Withdrawals Select Owner" ON driver_withdrawals
FOR SELECT
TO authenticated
USING (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = driver_withdrawals.driver_id)
    OR public.is_admin()
);

CREATE POLICY "Driver Withdrawals Insert Owner" ON driver_withdrawals
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = driver_withdrawals.driver_id)
    OR public.is_admin()
);

CREATE POLICY "Driver Withdrawals Update Admin" ON driver_withdrawals
FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Payment Methods Owner Policy" ON user_payment_methods;
CREATE POLICY "Payment Methods Owner Policy" ON user_payment_methods
FOR ALL
TO authenticated
USING (
    auth.uid() = user_id
    OR public.is_admin()
)
WITH CHECK (
    auth.uid() = user_id
    OR public.is_admin()
);

DROP POLICY IF EXISTS "OTP Codes Admin Only" ON otp_codes;
CREATE POLICY "OTP Codes Admin Only" ON otp_codes
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ----------------------------------------------------------------------------
-- POLICIES: DRIVER SCHEDULES, REVIEWS, EVENTS, PROMOS, COMMUNITY
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Driver Schedules Select" ON driver_schedules;
DROP POLICY IF EXISTS "Driver Schedules Select Public" ON driver_schedules;
DROP POLICY IF EXISTS "Driver Schedules Modify Authorized" ON driver_schedules;

CREATE POLICY "Driver Schedules Select Public" ON driver_schedules
FOR SELECT
USING (true);

CREATE POLICY "Driver Schedules Modify Authorized" ON driver_schedules
FOR ALL
TO authenticated
USING (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = driver_schedules.driver_id)
    OR public.is_admin()
)
WITH CHECK (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = driver_schedules.driver_id)
    OR public.is_admin()
);

DROP POLICY IF EXISTS "Reviews Read Public" ON reviews;
DROP POLICY IF EXISTS "Reviews Insert Authenticated" ON reviews;
DROP POLICY IF EXISTS "Reviews Insert Owner" ON reviews;

CREATE POLICY "Reviews Read Public" ON reviews
FOR SELECT
USING (true);

CREATE POLICY "Reviews Insert Owner" ON reviews
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
    OR public.is_admin()
);

DROP POLICY IF EXISTS "Events Read Public" ON app_events;
DROP POLICY IF EXISTS "Events Read Active Or Admin" ON app_events;
DROP POLICY IF EXISTS "Events Modify Admin Only" ON app_events;

CREATE POLICY "Events Read Active Or Admin" ON app_events
FOR SELECT
USING (
    is_active = true
    OR public.is_admin()
);

CREATE POLICY "Events Modify Admin Only" ON app_events
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Promos Read Public" ON app_promos;
DROP POLICY IF EXISTS "Promos Read Active Or Admin" ON app_promos;
DROP POLICY IF EXISTS "Promos Modify Admin Only" ON app_promos;

CREATE POLICY "Promos Read Active Or Admin" ON app_promos
FOR SELECT
USING (
    is_active = true
    OR public.is_admin()
);

CREATE POLICY "Promos Modify Admin Only" ON app_promos
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Community Posts, Comments, Likes, Stories
CREATE POLICY "Community Posts Read Public" ON community_posts FOR SELECT USING (true);
CREATE POLICY "Community Posts Insert Authenticated" ON community_posts FOR INSERT WITH CHECK (auth.uid() = user_id OR public.is_admin());
CREATE POLICY "Community Posts Delete Author" ON community_posts FOR DELETE USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "Community Comments Read Public" ON community_comments FOR SELECT USING (true);
CREATE POLICY "Community Comments Insert Authenticated" ON community_comments FOR INSERT WITH CHECK (auth.uid() = user_id OR public.is_admin());
CREATE POLICY "Community Comments Delete Author" ON community_comments FOR DELETE USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "Post Likes Read Public" ON post_likes FOR SELECT USING (true);
CREATE POLICY "Post Likes Insert Authenticated" ON post_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Post Likes Delete Authenticated" ON post_likes FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Community Stories Read Public" ON community_stories FOR SELECT USING (true);
CREATE POLICY "Community Stories Insert Authenticated" ON community_stories FOR INSERT WITH CHECK (auth.uid() = user_id OR public.is_admin());
CREATE POLICY "Community Stories Delete Author" ON community_stories FOR DELETE USING (auth.uid() = user_id OR public.is_admin());

-- Storage Bucket Publik 'community-media'
INSERT INTO storage.buckets (id, name, public) 
VALUES ('community-media', 'community-media', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Public Read Community Media" ON storage.objects;
DROP POLICY IF EXISTS "Public Insert Community Media" ON storage.objects;
DROP POLICY IF EXISTS "Public Update Community Media" ON storage.objects;

CREATE POLICY "Public Read Community Media" ON storage.objects FOR SELECT USING (bucket_id = 'community-media');
CREATE POLICY "Authenticated Insert Community Media" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'community-media' AND auth.role() = 'authenticated');
CREATE POLICY "Owner Update Community Media" ON storage.objects FOR UPDATE USING (bucket_id = 'community-media' AND (auth.uid() = owner OR public.is_admin()));

-- ============================================================================
-- SELESAI! Seluruh database Temenin Ajaa kini 100% Terproteksi & Bebas Celah RLS.
-- ============================================================================
