const { createClient } = require('@supabase/supabase-js');
const bcrypt = require('bcryptjs');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabaseAdmin = createClient(supabaseUrl, supabaseKey);

const dummyDrivers = [
  {
    name: 'Dian Sastrowardoyo',
    vehicle: 'Mini Cooper S Cabrio',
    type: 'VVIP',
    image: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=400&auto=format&fit=crop',
    price: 200000,
    gender: 'Perempuan',
    phone: '08111111111',
  },
  {
    name: 'Kevin Sanjaya',
    vehicle: 'Kendaraan Sean Wotherspoon',
    type: 'Gold',
    image: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=400&auto=format&fit=crop',
    price: 70000,
    gender: 'Laki-laki',
    phone: '08222222222',
  },
  {
    name: 'Sarah Connor',
    vehicle: 'Harley Davidson Sportster',
    type: 'Bronze',
    image: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=400&auto=format&fit=crop',
    price: 40000,
    gender: 'Perempuan',
    phone: '08333333333',
  }
];

async function seedDrivers() {
  console.log('Seeding drivers to Supabase...');
  
  for (const drv of dummyDrivers) {
    // 1. Check if user exists
    const { data: existingUser } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('phone', drv.phone)
      .maybeSingle();
      
    if (existingUser) {
      console.log(`Driver ${drv.name} already exists. Skipping.`);
      continue;
    }

    const salt = await bcrypt.genSalt(10);
    const password_hash = await bcrypt.hash('password123', salt);

    // 2. Create User
    const { data: user, error: userError } = await supabaseAdmin
      .from('users')
      .insert({
        email: `${drv.phone}@temenin.aja`,
        password_hash: password_hash,
        full_name: drv.name,
        phone: drv.phone,
        gender: drv.gender,
        avatar_url: drv.image,
        role: 'driver',
        is_verified: true,
      })
      .select()
      .single();

    if (userError) {
      console.error(`Error creating user ${drv.name}:`, userError.message);
      continue;
    }

    // 3. Create Driver
    const { error: driverError } = await supabaseAdmin
      .from('drivers')
      .insert({
        user_id: user.id,
        vehicle_type: drv.type,
        vehicle_name: drv.vehicle,
        plate_number: `B ${Math.floor(Math.random() * 9000) + 1000} XYZ`,
        price_per_hour: drv.price,
        rating: 4.9,
        status: 'approved',
        is_available: true,
      });

    if (driverError) {
      console.error(`Error creating driver profile for ${drv.name}:`, driverError.message);
    } else {
      console.log(`Successfully added driver: ${drv.name}`);
    }
  }
  
  console.log('Done!');
  process.exit(0);
}

seedDrivers();
