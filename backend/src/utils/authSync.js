// backend/src/utils/authSync.js
const { supabaseAdmin } = require('../config/supabase');

/**
 * Ensures a user exists in auth.users with the exact same id
 * This prevents foreign key constraint violations on payment_transactions
 */
async function ensureAuthUser(userId, email) {
  if (!userId) return;
  try {
    const cleanEmail = email || `${userId}@temenin.aja`;
    await supabaseAdmin.auth.admin.createUser({
      id: userId,
      email: cleanEmail,
      email_confirm: true
    });
  } catch (err) {
    // If user already exists in auth.users, ignore
  }
}

module.exports = { ensureAuthUser };
