const bcrypt = require('bcryptjs');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function createAdmin() {
  const email = 'admin@temenin.aja';
  const password = 'password123';
  const salt = await bcrypt.genSalt(10);
  const password_hash = await bcrypt.hash(password, salt);

  const { data: user, error } = await supabaseAdmin.from('users')
    .insert([
      {
        email: email,
        password_hash: password_hash,
        full_name: 'Super Admin',
        role: 'admin',
        is_verified: true,
        created_at: new Date(),
        updated_at: new Date()
      }
    ])
    .select()
    .single();

  if (error) {
    console.error('Error:', error);
  } else {
    console.log('Admin user created successfully:', user);
  }
}

createAdmin();
