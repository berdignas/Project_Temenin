// scripts/migrateUsers.js
const { supabase, supabaseAdmin } = require('../config/supabase');
const bcrypt = require('bcryptjs');

async function migrateExistingUsers() {
  // Ambil semua user dari Supabase Auth
  const { data: authUsers, error } = await supabaseAdmin.auth.admin.listUsers();
  
  if (error) {
    console.error('Error fetching auth users:', error);
    return;
  }
  
  for (const authUser of authUsers.users) {
    // Cek apakah user sudah ada di tabel users
    const { data: existingUser } = await supabase
      .from('users')
      .select('id')
      .eq('id', authUser.id)
      .maybeSingle();
    
    if (!existingUser) {
      // Generate random password hash (user harus reset password)
      const tempPassword = Math.random().toString(36).slice(-8);
      const password_hash = await bcrypt.hash(tempPassword, 10);
      
      // Insert ke tabel users
      const { error: insertError } = await supabase
        .from('users')
        .insert({
          id: authUser.id,
          email: authUser.email,
          password_hash: password_hash,
          full_name: authUser.user_metadata?.full_name || '',
          phone: authUser.user_metadata?.phone || '',
          is_verified: authUser.email_confirmed_at ? true : false,
          created_at: authUser.created_at
        });
      
      if (insertError) {
        console.error(`Error inserting user ${authUser.email}:`, insertError);
      } else {
        console.log(`✅ Migrated user: ${authUser.email}`);
      }
    }
  }
}

migrateExistingUsers();