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
-- 5. TABEL DOMPET & PENARIKAN SALDO (WALLET & WITHDRAWALS)
-- ============================================================================
DROP TABLE IF EXISTS driver_withdrawals CASCADE;
CREATE TABLE driver_withdrawals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    payment_method TEXT NOT NULL, -- 'BCA', 'Mandiri', 'DANA', 'OVO', 'ShopeePay'
    account_number TEXT NOT NULL,
    account_name TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    admin_notes TEXT,
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Log Mutasi Saldo
DROP TABLE IF EXISTS wallet_transactions CASCADE;
CREATE TABLE wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('topup', 'trip_income', 'withdrawal', 'commission_deduction')),
    amount NUMERIC(10,2) NOT NULL,
    description TEXT,
    reference_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
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
-- 10. ROW LEVEL SECURITY (RLS) & PUBLIC STORAGE BUCKETS
-- ============================================================================
-- Nonaktifkan RLS sementara untuk backend Node.js & akses Supabase Flutter bebas hambatan
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE drivers DISABLE ROW LEVEL SECURITY;
ALTER TABLE bookings DISABLE ROW LEVEL SECURITY;
ALTER TABLE booking_negotiations DISABLE ROW LEVEL SECURITY;
ALTER TABLE driver_withdrawals DISABLE ROW LEVEL SECURITY;
ALTER TABLE reviews DISABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE community_posts DISABLE ROW LEVEL SECURITY;
ALTER TABLE community_comments DISABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes DISABLE ROW LEVEL SECURITY;
ALTER TABLE community_stories DISABLE ROW LEVEL SECURITY;
ALTER TABLE booking_messages DISABLE ROW LEVEL SECURITY;
ALTER TABLE otp_codes DISABLE ROW LEVEL SECURITY;

-- Membuat Storage Bucket Publik 'community-media' untuk Upload Gambar & File Biner
INSERT INTO storage.buckets (id, name, public) 
VALUES ('community-media', 'community-media', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Kebijakan Akses Storage Bucket Publik
CREATE POLICY "Public Read Community Media" ON storage.objects FOR SELECT USING (bucket_id = 'community-media');
CREATE POLICY "Public Insert Community Media" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'community-media');
CREATE POLICY "Public Update Community Media" ON storage.objects FOR UPDATE USING (bucket_id = 'community-media');

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
    (SELECT COUNT(*) FROM driver_withdrawals WHERE status = 'pending') AS pending_withdrawals;

-- ============================================================================
-- 12. TABEL EVENT TERDEKAT & PROMO (MANAGEMENT ADMIN)
-- ============================================================================
CREATE TABLE IF NOT EXISTS app_events (
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

ALTER TABLE app_events DISABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS app_promos (
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

ALTER TABLE app_promos DISABLE ROW LEVEL SECURITY;


-- SELESAI! Seluruh database Temenin Ajaa kini 100% Siap Digunakan.
