-- SQL Schema for Temenin Ajaa Project
-- Copy and run this script in the Supabase Dashboard -> SQL Editor (New Query)

-- 1. Enable UUID Extension (required for uuid generation)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Drop existing tables if they exist to prevent conflicts (CAUTION: This deletes existing data in these tables)
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS drivers CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 3. Create 'users' table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE,
    password_hash TEXT,
    full_name TEXT NOT NULL,
    phone TEXT UNIQUE,
    role TEXT DEFAULT 'client', -- 'client' or 'driver' or 'admin'
    balance NUMERIC DEFAULT 0,
    points INTEGER DEFAULT 0,
    avatar_url TEXT,
    gender TEXT DEFAULT 'Laki-laki',
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Create 'drivers' table
CREATE TABLE drivers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    vehicle_type TEXT NOT NULL,
    vehicle_name TEXT NOT NULL,
    plate_number TEXT NOT NULL,
    price_per_hour NUMERIC DEFAULT 50000,
    rating NUMERIC(3,2) DEFAULT 5.00,
    total_rides INTEGER DEFAULT 0,
    is_available BOOLEAN DEFAULT true,
    status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    experience_years INTEGER DEFAULT 0,
    id_card_number TEXT,
    driver_license_number TEXT,
    vehicle_stnk TEXT,
    registration_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    approved_at TIMESTAMP WITH TIME ZONE,
    latitude NUMERIC,
    longitude NUMERIC,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Create 'bookings' table
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'pending', -- 'pending', 'ongoing', 'completed', 'cancelled'
    pickup_location TEXT,
    dropoff_location TEXT,
    pickup_latitude NUMERIC,
    pickup_longitude NUMERIC,
    dropoff_latitude NUMERIC,
    dropoff_longitude NUMERIC,
    duration INTEGER, -- in minutes
    total_price NUMERIC,
    booking_date TIMESTAMP WITH TIME ZONE,
    additional_details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. Create 'booking_negotiations' table for negotiation (negosiasi harga)
CREATE TABLE booking_negotiations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE NOT NULL,
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE NOT NULL,
    negotiated_price NUMERIC NOT NULL,
    status TEXT DEFAULT 'pending', -- 'pending', 'accepted', 'rejected'
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. Create 'community_posts' table
CREATE TABLE community_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    image_url TEXT,
    caption TEXT,
    likes_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. Create 'post_likes' table to track likes properly
CREATE TABLE post_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(post_id, user_id)
);

-- 9. Create 'community_stories' table
CREATE TABLE community_stories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    image_url TEXT NOT NULL,
    caption TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (timezone('utc'::text, now()) + interval '24 hours') NOT NULL
);

-- 9.5 Create 'otp_codes' table
CREATE TABLE otp_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone TEXT NOT NULL,
    code TEXT NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_used BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 10. Setup RLS (Row Level Security) - Disable temporarily for simple backend access or set permissive rules
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE drivers DISABLE ROW LEVEL SECURITY;
ALTER TABLE bookings DISABLE ROW LEVEL SECURITY;
ALTER TABLE booking_negotiations DISABLE ROW LEVEL SECURITY;
ALTER TABLE community_posts DISABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes DISABLE ROW LEVEL SECURITY;
ALTER TABLE community_stories DISABLE ROW LEVEL SECURITY;
ALTER TABLE otp_codes DISABLE ROW LEVEL SECURITY;

