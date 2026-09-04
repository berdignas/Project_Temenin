-- ====================================================================
-- TEMENIN AJAA - SUPABASE MASTER DATABASE SCHEMA & SEED DATA
-- Version: 1.0.0
-- Description: Complete SQL schema for Supabase SQL Editor
-- Features: Users, Drivers/Partners, Bookings, Booking Items, Itineraries,
--           Addons, Timelines, Reviews, Vouchers, Rewards, RLS, Triggers
-- ====================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. CLEANUP (Drop tables if re-running)
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS timelines CASCADE;
DROP TABLE IF EXISTS addons CASCADE;
DROP TABLE IF EXISTS itineraries CASCADE;
DROP TABLE IF EXISTS booking_items CASCADE;
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS vouchers CASCADE;
DROP TABLE IF EXISTS rewards CASCADE;
DROP TABLE IF EXISTS drivers CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 3. USERS TABLE
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    phone TEXT,
    gender TEXT DEFAULT 'Pria',
    role TEXT DEFAULT 'client' CHECK (role IN ('client', 'driver', 'admin')),
    balance NUMERIC DEFAULT 0,
    points INTEGER DEFAULT 0,
    avatar_url TEXT,
    is_verified BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. DRIVERS / PARTNERS TABLE
CREATE TABLE drivers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    vehicle_type TEXT NOT NULL DEFAULT 'Motor',
    vehicle_name TEXT NOT NULL DEFAULT 'Vespa Primavera',
    plate_number TEXT NOT NULL DEFAULT 'B 1234 TA',
    price_per_hour NUMERIC DEFAULT 50000,
    rating NUMERIC(3,2) DEFAULT 5.00,
    total_rides INTEGER DEFAULT 0,
    driver_class TEXT DEFAULT 'Gold' CHECK (driver_class IN ('Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'VVIP')),
    is_available BOOLEAN DEFAULT true,
    status TEXT DEFAULT 'approved' CHECK (status IN ('pending', 'approved', 'rejected', 'suspended')),
    experience_years INTEGER DEFAULT 2,
    bio TEXT DEFAULT 'Mitra pendamping profesional Temenin Ajaa yang ramah dan siap membantu.',
    id_card_number TEXT,
    driver_license_number TEXT,
    vehicle_stnk TEXT,
    latitude NUMERIC DEFAULT -6.175392,
    longitude NUMERIC DEFAULT 106.827153,
    registration_date TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    approved_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. BOOKINGS TABLE
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_number TEXT UNIQUE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'ongoing', 'completed', 'cancelled')),
    service_type TEXT DEFAULT 'antar_jemput' CHECK (service_type IN ('antar_jemput', 'hangout', 'freedom_request')),
    pickup_location TEXT,
    dropoff_location TEXT,
    pickup_latitude NUMERIC,
    pickup_longitude NUMERIC,
    dropoff_latitude NUMERIC,
    dropoff_longitude NUMERIC,
    duration INTEGER DEFAULT 1, -- dalam jam / menit
    total_price NUMERIC NOT NULL DEFAULT 0,
    down_payment NUMERIC DEFAULT 0, -- DP 50%
    remaining_payment NUMERIC DEFAULT 0,
    is_weekend_applied BOOLEAN DEFAULT false,
    booking_date TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    additional_details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. BOOKING ITEMS TABLE
CREATE TABLE booking_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE NOT NULL,
    service_type TEXT NOT NULL,
    quantity INTEGER DEFAULT 1,
    unit_price NUMERIC DEFAULT 0,
    subtotal NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. ITINERARIES TABLE
CREATE TABLE itineraries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE NOT NULL,
    sequence INTEGER NOT NULL,
    location_name TEXT NOT NULL,
    latitude NUMERIC,
    longitude NUMERIC,
    arrival_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. ADDONS TABLE
CREATE TABLE addons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE NOT NULL,
    addon_code TEXT NOT NULL,
    quantity INTEGER DEFAULT 1,
    price NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 9. TIMELINES TABLE
CREATE TABLE timelines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE NOT NULL,
    event TEXT NOT NULL,
    actor TEXT NOT NULL CHECK (actor IN ('customer', 'partner', 'system', 'admin')),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 10. REVIEWS TABLE
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE NOT NULL,
    customer_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE NOT NULL,
    rating NUMERIC(2,1) NOT NULL CHECK (rating >= 1.0 AND rating <= 5.0),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 11. VOUCHERS TABLE
CREATE TABLE vouchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    description TEXT,
    discount_percent NUMERIC DEFAULT 10,
    max_discount NUMERIC DEFAULT 50000,
    min_spend NUMERIC DEFAULT 100000,
    expiry_date TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 12. REWARDS TABLE
CREATE TABLE rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    points_cost INTEGER NOT NULL,
    stock INTEGER DEFAULT 100,
    icon_name TEXT DEFAULT 'card_giftcard',
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 13. INDEXES
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_drivers_user_id ON drivers(user_id);
CREATE INDEX idx_drivers_is_available ON drivers(is_available);
CREATE INDEX idx_bookings_booking_number ON bookings(booking_number);
CREATE INDEX idx_bookings_user_id ON bookings(user_id);
CREATE INDEX idx_bookings_driver_id ON bookings(driver_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_timelines_booking_id ON timelines(booking_id);

-- 14. FUNCTIONS & TRIGGERS
-- Automatic updated_at timestamp function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = timezone('utc'::text, now());
   RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_modtime BEFORE UPDATE ON users FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER update_drivers_modtime BEFORE UPDATE ON drivers FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER update_bookings_modtime BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- Function to auto-generate Booking Number (TA-YYYYMMDD-XXXXXX)
CREATE OR REPLACE FUNCTION generate_booking_number()
RETURNS TRIGGER AS $$
DECLARE
    date_str TEXT;
    seq_num TEXT;
BEGIN
    date_str := to_char(now(), 'YYYYMMDD');
    seq_num := lpad((floor(random() * 899999 + 100000))::text, 6, '0');
    IF NEW.booking_number IS NULL OR NEW.booking_number = '' THEN
        NEW.booking_number := 'TA-' || date_str || '-' || seq_num;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_booking_number BEFORE INSERT ON bookings FOR EACH ROW EXECUTE PROCEDURE generate_booking_number();

-- 15. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE drivers DISABLE ROW LEVEL SECURITY;
ALTER TABLE bookings DISABLE ROW LEVEL SECURITY;
ALTER TABLE booking_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE itineraries DISABLE ROW LEVEL SECURITY;
ALTER TABLE addons DISABLE ROW LEVEL SECURITY;
ALTER TABLE timelines DISABLE ROW LEVEL SECURITY;
ALTER TABLE reviews DISABLE ROW LEVEL SECURITY;
ALTER TABLE vouchers DISABLE ROW LEVEL SECURITY;
ALTER TABLE rewards DISABLE ROW LEVEL SECURITY;

-- 16. SEED DATA

-- Client User
INSERT INTO users (id, email, password_hash, full_name, phone, role, balance, points, is_verified)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'client@temeninajaa.com', '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', 'Jessica Sastrowardoyo', '+62 811-9999-100', 'client', 250000, 2450, true)
ON CONFLICT (email) DO UPDATE SET full_name = EXCLUDED.full_name, balance = EXCLUDED.balance, points = EXCLUDED.points;

-- Driver Users (12 Total Drivers)
INSERT INTO users (id, email, password_hash, full_name, phone, role, balance, points, is_verified)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'raka@temeninajaa.com', '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', 'Raka Wijaya', '+62 812-3456-0001', 'driver', 0, 120, true),
  ('11111111-2222-1111-1111-111111111111', 'siti@temeninajaa.com', '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', 'Siti Aminah', '+62 812-3456-0002', 'driver', 0, 85, true),
  ('22222222-1111-2222-2222-111111111111', 'arya@temeninajaa.com', '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', 'Arya Perkasa', '+62 812-3456-0003', 'driver', 0, 320, true),
  ('22222222-2222-2222-2222-111111111111', 'eko@temeninajaa.com', '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', 'Eko Prasetyo', '+62 812-3456-0004', 'driver', 0, 190, true),
  ('33333333-1111-3333-3333-111111111111', 'dian@temeninajaa.com', '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', 'Dian Sastro', '+62 812-3456-0005', 'driver', 0, 450, true),
  ('33333333-2222-3333-3333-111111111111', 'bambang@temeninajaa.com', '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', 'Bambang Wijaya', '+62 812-3456-0006', 'driver', 0, 290, true),
  ('44444444-1111-4444-4444-111111111111', 'putra@temeninajaa.com', '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', 'Putra Ramadhan', '+62 812-3456-0007', 'driver', 0, 280, true),
  ('44444444-2222-4444-4444-111111111111', 'rian@temeninajaa.com', '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', 'Rian Aditama', '+62 812-3456-0008', 'driver', 0, 340, true),
  ('55555555-1111-5555-5555-111111111111', 'diki@temeninajaa.com', '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', 'Diki Pratama', '+62 812-3456-0009', 'driver', 0, 450, true),
  ('55555555-2222-5555-5555-111111111111', 'fiona@temeninajaa.com', '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', 'Fiona Lestari', '+62 812-3456-0010', 'driver', 0, 210, true),
  ('66666666-1111-6666-6666-111111111111', 'adrian@temeninajaa.com', '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', 'Adrian Wijaya', '+62 812-3456-0011', 'driver', 0, 320, true),
  ('66666666-2222-6666-6666-111111111111', 'jessica@temeninajaa.com', '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', 'Jessica Mila', '+62 812-3456-0012', 'driver', 0, 550, true)
ON CONFLICT (email) DO UPDATE SET full_name = EXCLUDED.full_name, role = 'driver';

-- Driver Profiles
INSERT INTO drivers (id, user_id, vehicle_type, vehicle_name, plate_number, price_per_hour, rating, total_rides, driver_class, is_available, status, experience_years)
VALUES
  ('11111111-1111-1111-1111-222222222222', '11111111-1111-1111-1111-111111111111', 'Motor', 'Honda Beat', 'B 1234 RW', 50000, 4.5, 120, 'Bronze', true, 'approved', 2),
  ('11111111-2222-1111-1111-222222222222', '11111111-2222-1111-1111-111111111111', 'Motor', 'Yamaha Mio', 'B 1234 SA', 40000, 4.6, 85, 'Silver', true, 'approved', 1),
  ('22222222-1111-2222-2222-222222222222', '22222222-1111-2222-2222-111111111111', 'Motor', 'Honda Vario 160', 'B 1234 AP', 60000, 4.6, 320, 'Gold', true, 'approved', 4),
  ('22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-111111111111', 'Motor', 'Yamaha Gear', 'B 1234 EP', 50000, 4.7, 190, 'Gold', true, 'approved', 2),
  ('33333333-1111-3333-3333-222222222222', '33333333-1111-3333-3333-111111111111', 'Motor', 'Vespa Primavera', 'B 1234 DS', 80000, 4.9, 450, 'Platinum', true, 'approved', 5),
  ('33333333-2222-3333-3333-222222222222', '33333333-2222-3333-3333-111111111111', 'Motor', 'Honda PCX 160', 'B 1234 BW', 70000, 4.8, 290, 'Platinum', true, 'approved', 3),
  ('44444444-1111-4444-4444-222222222222', '44444444-1111-4444-4444-111111111111', 'Motor', 'Honda PCX 160', 'B 1234 PR', 100000, 4.8, 280, 'Diamond', true, 'approved', 3),
  ('44444444-2222-4444-4444-222222222222', '44444444-2222-4444-4444-111111111111', 'Motor', 'Yamaha XMAX', 'B 1234 RA', 90000, 4.9, 340, 'Diamond', true, 'approved', 4),
  ('55555555-1111-5555-5555-222222222222', '55555555-1111-5555-5555-111111111111', 'Motor', 'Yamaha NMAX', 'B 1234 DP', 120000, 4.7, 450, 'VVIP', true, 'approved', 6),
  ('55555555-2222-5555-5555-222222222222', '55555555-2222-5555-5555-111111111111', 'Motor', 'Vespa GTS 300', 'B 1234 FL', 120000, 4.9, 210, 'VVIP', true, 'approved', 3),
  ('66666666-1111-6666-6666-222222222222', '66666666-1111-6666-6666-111111111111', 'Motor', 'Kawasaki Ninja ZX-25R', 'B 1234 AW', 150000, 4.9, 320, 'VVIP', true, 'approved', 5),
  ('66666666-2222-6666-6666-222222222222', '66666666-2222-6666-6666-111111111111', 'Mobil', 'Mini Cooper (Premium)', 'B 1234 JM', 200000, 5.0, 550, 'VVIP', true, 'approved', 7)
ON CONFLICT (user_id) DO UPDATE 
SET vehicle_name = EXCLUDED.vehicle_name, plate_number = EXCLUDED.plate_number, price_per_hour = EXCLUDED.price_per_hour;

-- Seed Vouchers
INSERT INTO vouchers (code, description, discount_percent, max_discount, min_spend, is_active)
VALUES
  ('TEMENINBARU', 'Diskon 20% khusus pengguna baru Temenin Ajaa', 20, 30000, 50000, true),
  ('WEEKENDSERU', 'Voucher Hangout akhir pekan diskon 15%', 15, 50000, 100000, true),
  ('DIAMONDFEST', 'Cashback 20% khusus Diamond Member', 20, 100000, 150000, true)
ON CONFLICT (code) DO NOTHING;

-- Seed Rewards
INSERT INTO rewards (name, description, points_cost, stock, icon_name)
VALUES
  ('Voucher Diskon Rp 25.000', 'Potongan Rp 25.000 untuk semua layanan Ride dan Hangout', 500, 50, 'confirmation_number'),
  ('Gratis Add-On Helm Ekstra', 'Bebas biaya sewa helm ekstra steril', 200, 100, 'card_giftcard'),
  ('Voucher Diskon Rp 50.000', 'Potongan Rp 50.000 khusus layanan Hangout VVIP', 900, 30, 'stars')
ON CONFLICT DO NOTHING;

-- Seed Sample Bookings
INSERT INTO bookings (id, booking_number, user_id, driver_id, status, service_type, pickup_location, dropoff_location, duration, total_price, down_payment, remaining_payment)
VALUES
  ('77777777-1111-7777-7777-111111111111', 'TA-20260817-000123', '00000000-0000-0000-0000-000000000001', '33333333-1111-3333-3333-222222222222', 'ongoing', 'antar_jemput', 'Central Park Mall', 'Grand Indonesia', 1, 150000, 75000, 75000)
ON CONFLICT (booking_number) DO NOTHING;
