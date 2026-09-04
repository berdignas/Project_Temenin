-- Seed Driver Users and Profiles (12 Total Drivers)
-- Run this in the Supabase SQL Editor
-- All accounts have the password: password123

-- 1. Insert Users (role = 'driver')
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
ON CONFLICT (email) DO UPDATE 
SET full_name = EXCLUDED.full_name, role = 'driver';

-- 2. Insert Drivers
INSERT INTO drivers (id, user_id, vehicle_type, vehicle_name, plate_number, price_per_hour, rating, total_rides, is_available, status, experience_years)
VALUES
  ('11111111-1111-1111-1111-222222222222', '11111111-1111-1111-1111-111111111111', 'Motor', 'Honda Beat', 'B 1234 RW', 50000, 4.5, 120, true, 'approved', 2),
  ('11111111-2222-1111-1111-222222222222', '11111111-2222-1111-1111-111111111111', 'Motor', 'Yamaha Mio', 'B 1234 SA', 40000, 4.6, 85, true, 'approved', 1),
  ('22222222-1111-2222-2222-222222222222', '22222222-1111-2222-2222-111111111111', 'Motor', 'Honda Vario 160', 'B 1234 AP', 60000, 4.6, 320, true, 'approved', 4),
  ('22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-111111111111', 'Motor', 'Yamaha Gear', 'B 1234 EP', 50000, 4.7, 190, true, 'approved', 2),
  ('33333333-1111-3333-3333-222222222222', '33333333-1111-3333-3333-111111111111', 'Motor', 'Vespa Primavera', 'B 1234 DS', 80000, 4.9, 450, true, 'approved', 5),
  ('33333333-2222-3333-3333-222222222222', '33333333-2222-3333-3333-111111111111', 'Motor', 'Honda PCX 160', 'B 1234 BW', 70000, 4.8, 290, true, 'approved', 3),
  ('44444444-1111-4444-4444-222222222222', '44444444-1111-4444-4444-111111111111', 'Motor', 'Honda PCX 160', 'B 1234 PR', 100000, 4.8, 280, true, 'approved', 3),
  ('44444444-2222-4444-4444-222222222222', '44444444-2222-4444-4444-111111111111', 'Motor', 'Yamaha XMAX', 'B 1234 RA', 90000, 4.9, 340, true, 'approved', 4),
  ('55555555-1111-5555-5555-222222222222', '55555555-1111-5555-5555-111111111111', 'Motor', 'Yamaha NMAX', 'B 1234 DP', 120000, 4.7, 450, true, 'approved', 6),
  ('55555555-2222-5555-5555-222222222222', '55555555-2222-5555-5555-111111111111', 'Motor', 'Vespa GTS 300', 'B 1234 FL', 120000, 4.9, 210, true, 'approved', 3),
  ('66666666-1111-6666-6666-222222222222', '66666666-1111-6666-6666-111111111111', 'Motor', 'Kawasaki Ninja ZX-25R', 'B 1234 AW', 150000, 4.9, 320, true, 'approved', 5),
  ('66666666-2222-6666-6666-222222222222', '66666666-2222-6666-6666-111111111111', 'Mobil', 'Mini Cooper (Premium)', 'B 1234 JM', 200000, 5.0, 550, true, 'approved', 7)
ON CONFLICT (user_id) DO UPDATE 
SET vehicle_name = EXCLUDED.vehicle_name, plate_number = EXCLUDED.plate_number, price_per_hour = EXCLUDED.price_per_hour;
