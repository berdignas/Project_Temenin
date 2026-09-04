const { supabaseAdmin } = require('./src/config/supabase');

const users = [
  { id: '11111111-1111-1111-1111-111111111111', email: 'raka@temeninajaa.com', password_hash: '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', full_name: 'Raka Wijaya', phone: '+62 812-3456-0001', role: 'driver', balance: 0, points: 120, is_verified: true },
  { id: '11111111-2222-1111-1111-111111111111', email: 'siti@temeninajaa.com', password_hash: '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', full_name: 'Siti Aminah', phone: '+62 812-3456-0002', role: 'driver', balance: 0, points: 85, is_verified: true },
  { id: '22222222-1111-2222-2222-111111111111', email: 'arya@temeninajaa.com', password_hash: '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', full_name: 'Arya Perkasa', phone: '+62 812-3456-0003', role: 'driver', balance: 0, points: 320, is_verified: true },
  { id: '22222222-2222-2222-2222-111111111111', email: 'eko@temeninajaa.com', password_hash: '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', full_name: 'Eko Prasetyo', phone: '+62 812-3456-0004', role: 'driver', balance: 0, points: 190, is_verified: true },
  { id: '33333333-1111-3333-3333-111111111111', email: 'dian@temeninajaa.com', password_hash: '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', full_name: 'Dian Sastro', phone: '+62 812-3456-0005', role: 'driver', balance: 0, points: 450, is_verified: true },
  { id: '33333333-2222-3333-3333-111111111111', email: 'bambang@temeninajaa.com', password_hash: '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', full_name: 'Bambang Wijaya', phone: '+62 812-3456-0006', role: 'driver', balance: 0, points: 290, is_verified: true },
  { id: '44444444-1111-4444-4444-111111111111', email: 'putra@temeninajaa.com', password_hash: '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', full_name: 'Putra Ramadhan', phone: '+62 812-3456-0007', role: 'driver', balance: 0, points: 280, is_verified: true },
  { id: '44444444-2222-4444-4444-111111111111', email: 'rian@temeninajaa.com', password_hash: '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', full_name: 'Rian Aditama', phone: '+62 812-3456-0008', role: 'driver', balance: 0, points: 340, is_verified: true },
  { id: '55555555-1111-5555-5555-111111111111', email: 'diki@temeninajaa.com', password_hash: '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', full_name: 'Diki Pratama', phone: '+62 812-3456-0009', role: 'driver', balance: 0, points: 450, is_verified: true },
  { id: '55555555-2222-5555-5555-111111111111', email: 'fiona@temeninajaa.com', password_hash: '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', full_name: 'Fiona Lestari', phone: '+62 812-3456-0010', role: 'driver', balance: 0, points: 210, is_verified: true },
  { id: '66666666-1111-6666-6666-111111111111', email: 'adrian@temeninajaa.com', password_hash: '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', full_name: 'Adrian Wijaya', phone: '+62 812-3456-0011', role: 'driver', balance: 0, points: 320, is_verified: true },
  { id: '66666666-2222-6666-6666-111111111111', email: 'jessica@temeninajaa.com', password_hash: '$2a$10$X.v.fN0p0d25uS4i4jYhEuP8gQ6K2d9h.E64sH9f1c7O.t.V3Kj.q', full_name: 'Jessica Mila', phone: '+62 812-3456-0012', role: 'driver', balance: 0, points: 550, is_verified: true }
];

const drivers = [
  { id: '11111111-1111-1111-1111-222222222222', user_id: '11111111-1111-1111-1111-111111111111', vehicle_type: 'Motor', vehicle_name: 'Honda Beat', plate_number: 'B 1234 RW', price_per_hour: 50000, rating: 4.5, total_rides: 120, is_available: true, status: 'approved', experience_years: 2 },
  { id: '11111111-2222-1111-1111-222222222222', user_id: '11111111-2222-1111-1111-111111111111', vehicle_type: 'Motor', vehicle_name: 'Yamaha Mio', plate_number: 'B 1234 SA', price_per_hour: 40000, rating: 4.6, total_rides: 85, is_available: true, status: 'approved', experience_years: 1 },
  { id: '22222222-1111-2222-2222-222222222222', user_id: '22222222-1111-2222-2222-111111111111', vehicle_type: 'Motor', vehicle_name: 'Honda Vario 160', plate_number: 'B 1234 AP', price_per_hour: 60000, rating: 4.6, total_rides: 320, is_available: true, status: 'approved', experience_years: 4 },
  { id: '22222222-2222-2222-2222-222222222222', user_id: '22222222-2222-2222-2222-111111111111', vehicle_type: 'Motor', vehicle_name: 'Yamaha Gear', plate_number: 'B 1234 EP', price_per_hour: 50000, rating: 4.7, total_rides: 190, is_available: true, status: 'approved', experience_years: 2 },
  { id: '33333333-1111-3333-3333-222222222222', user_id: '33333333-1111-3333-3333-111111111111', vehicle_type: 'Motor', vehicle_name: 'Vespa Primavera', plate_number: 'B 1234 DS', price_per_hour: 80000, rating: 4.9, total_rides: 450, is_available: true, status: 'approved', experience_years: 5 },
  { id: '33333333-2222-3333-3333-222222222222', user_id: '33333333-2222-3333-3333-111111111111', vehicle_type: 'Motor', vehicle_name: 'Honda PCX 160', plate_number: 'B 1234 BW', price_per_hour: 70000, rating: 4.8, total_rides: 290, is_available: true, status: 'approved', experience_years: 3 },
  { id: '44444444-1111-4444-4444-222222222222', user_id: '44444444-1111-4444-4444-111111111111', vehicle_type: 'Motor', vehicle_name: 'Honda PCX 160', plate_number: 'B 1234 PR', price_per_hour: 100000, rating: 4.8, total_rides: 280, is_available: true, status: 'approved', experience_years: 3 },
  { id: '44444444-2222-4444-4444-222222222222', user_id: '44444444-2222-4444-4444-111111111111', vehicle_type: 'Motor', vehicle_name: 'Yamaha XMAX', plate_number: 'B 1234 RA', price_per_hour: 90000, rating: 4.9, total_rides: 340, is_available: true, status: 'approved', experience_years: 4 },
  { id: '55555555-1111-5555-5555-222222222222', user_id: '55555555-1111-5555-5555-111111111111', vehicle_type: 'Motor', vehicle_name: 'Yamaha NMAX', plate_number: 'B 1234 DP', price_per_hour: 120000, rating: 4.7, total_rides: 450, is_available: true, status: 'approved', experience_years: 6 },
  { id: '55555555-2222-5555-5555-222222222222', user_id: '55555555-2222-5555-5555-111111111111', vehicle_type: 'Motor', vehicle_name: 'Vespa GTS 300', plate_number: 'B 1234 FL', price_per_hour: 120000, rating: 4.9, total_rides: 210, is_available: true, status: 'approved', experience_years: 3 },
  { id: '66666666-1111-6666-6666-222222222222', user_id: '66666666-1111-6666-6666-111111111111', vehicle_type: 'Motor', vehicle_name: 'Kawasaki Ninja ZX-25R', plate_number: 'B 1234 AW', price_per_hour: 150000, rating: 4.9, total_rides: 320, is_available: true, status: 'approved', experience_years: 5 },
  { id: '66666666-2222-6666-6666-222222222222', user_id: '66666666-2222-6666-6666-111111111111', vehicle_type: 'Mobil', vehicle_name: 'Mini Cooper (Premium)', plate_number: 'B 1234 JM', price_per_hour: 200000, rating: 5.0, total_rides: 550, is_available: true, status: 'approved', experience_years: 7 }
];

temenin_ajaa_company22

async function seed() {
  console.log('Seeding users...');
  const { data: userDatas, error: userError } = await supabaseAdmin
    .from('users')
    .upsert(users);
  
  if (userError) {
    console.error('Failed to seed users:', userError);
    return;
  }
  console.log('Seeded users successfully!');

  console.log('Seeding drivers...');
  const { data: driverDatas, error: driverError } = await supabaseAdmin
    .from('drivers')
    .upsert(drivers);

  if (driverError) {
    console.error('Failed to seed drivers:', driverError);
    return;
  }
  console.log('Seeded drivers successfully!');
  console.log('Seed completed successfully!');
}

seed();
