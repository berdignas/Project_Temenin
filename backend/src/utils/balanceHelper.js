// backend/src/utils/balanceHelper.js
const { supabaseAdmin } = require('../config/supabase');

/**
 * Atomic Balance Increment (Deposit / Top-Up / Trip Payout / Refund)
 * Prevents race conditions and lost updates using PostgreSQL row lock via RPC.
 * Falls back to Optimistic Concurrency Control (CAS) loop if RPC is not yet loaded in DB.
 */
async function atomicIncrementBalance(userId, amount) {
  const numAmount = parseFloat(amount);
  if (!userId || isNaN(numAmount) || numAmount <= 0) {
    throw new Error('Invalid userId or amount for balance increment');
  }

  // 1. Try Supabase RPC function (PostgreSQL Atomic UPDATE RETURNING)
  try {
    const { data: rpcBal, error: rpcErr } = await supabaseAdmin.rpc('increment_user_balance', {
      p_user_id: userId,
      p_amount: numAmount
    });

    if (!rpcErr && rpcBal !== null && rpcBal !== undefined) {
      return parseFloat(rpcBal);
    }
  } catch (rpcEx) {
    // RPC may not exist in database yet, proceed to OCC CAS fallback
  }

  // 2. OCC (Optimistic Concurrency Control) Compare-And-Swap Loop Fallback
  const maxAttempts = 5;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const { data: user, error: fetchErr } = await supabaseAdmin
      .from('users')
      .select('balance')
      .eq('id', userId)
      .single();

    if (fetchErr || !user) {
      throw new Error(`User not found for balance increment: ${fetchErr?.message || 'Unknown'}`);
    }

    const currentBal = parseFloat(user.balance || 0);
    const targetBal = currentBal + numAmount;

    const { data: updated, error: updErr } = await supabaseAdmin
      .from('users')
      .update({
        balance: targetBal,
        updated_at: new Date().toISOString()
      })
      .eq('id', userId)
      .eq('balance', currentBal)
      .select('balance')
      .maybeSingle();

    if (!updErr && updated) {
      return parseFloat(updated.balance);
    }

    // Jittered backoff before retry
    await new Promise(r => setTimeout(r, 20 + Math.random() * 30));
  }

  throw new Error('Gagal memperbarui saldo secara atomik karena aktivitas bersamaan. Silakan coba kembali.');
}

/**
 * Atomic Balance Deduction (Payment / Withdrawal)
 * Prevents race conditions and double-spending using PostgreSQL row lock via RPC.
 * Strictly verifies balance >= amount before deducting.
 */
async function atomicDeductBalance(userId, amount) {
  const numAmount = parseFloat(amount);
  if (!userId || isNaN(numAmount) || numAmount <= 0) {
    throw new Error('Invalid userId or amount for balance deduction');
  }

  // 1. Try Supabase RPC function (PostgreSQL Atomic UPDATE with balance >= amount check)
  try {
    const { data: rpcBal, error: rpcErr } = await supabaseAdmin.rpc('deduct_user_balance', {
      p_user_id: userId,
      p_amount: numAmount
    });

    if (rpcErr) {
      if (rpcErr.message && rpcErr.message.includes('INSUFFICIENT_BALANCE')) {
        throw new Error('INSUFFICIENT_BALANCE');
      }
      // If error is other than not found, don't silently fallback if it was a rejection
      if (!rpcErr.message.includes('function') && !rpcErr.message.includes('not find')) {
        throw rpcErr;
      }
    } else if (rpcBal !== null && rpcBal !== undefined) {
      return parseFloat(rpcBal);
    }
  } catch (rpcEx) {
    if (rpcEx.message === 'INSUFFICIENT_BALANCE') {
      throw rpcEx;
    }
    // Proceed to OCC CAS fallback
  }

  // 2. OCC Compare-And-Swap Loop Fallback
  const maxAttempts = 5;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const { data: user, error: fetchErr } = await supabaseAdmin
      .from('users')
      .select('balance')
      .eq('id', userId)
      .single();

    if (fetchErr || !user) {
      throw new Error(`User not found for balance deduction: ${fetchErr?.message || 'Unknown'}`);
    }

    const currentBal = parseFloat(user.balance || 0);
    if (currentBal < numAmount) {
      throw new Error('INSUFFICIENT_BALANCE');
    }

    const targetBal = currentBal - numAmount;

    const { data: updated, error: updErr } = await supabaseAdmin
      .from('users')
      .update({
        balance: targetBal,
        updated_at: new Date().toISOString()
      })
      .eq('id', userId)
      .eq('balance', currentBal)
      .gte('balance', numAmount)
      .select('balance')
      .maybeSingle();

    if (!updErr && updated) {
      return parseFloat(updated.balance);
    }

    // Jittered backoff before retry
    await new Promise(r => setTimeout(r, 20 + Math.random() * 30));
  }

  throw new Error('Gagal memproses pemotongan saldo secara atomik karena aktivitas bersamaan.');
}

/**
 * Atomic Points Deduction (Redeem Rewards)
 * Prevents double-spending of reward points via PostgreSQL RPC or OCC CAS.
 */
async function atomicDeductPoints(userId, points) {
  const intPoints = parseInt(points, 10);
  if (!userId || isNaN(intPoints) || intPoints <= 0) {
    throw new Error('Invalid userId or points for points deduction');
  }

  // 1. Try Supabase RPC function
  try {
    const { data: rpcPoints, error: rpcErr } = await supabaseAdmin.rpc('deduct_user_points', {
      p_user_id: userId,
      p_points: intPoints
    });

    if (rpcErr) {
      if (rpcErr.message && rpcErr.message.includes('INSUFFICIENT_POINTS')) {
        throw new Error('INSUFFICIENT_POINTS');
      }
      if (!rpcErr.message.includes('function') && !rpcErr.message.includes('not find')) {
        throw rpcErr;
      }
    } else if (rpcPoints !== null && rpcPoints !== undefined) {
      return parseInt(rpcPoints, 10);
    }
  } catch (rpcEx) {
    if (rpcEx.message === 'INSUFFICIENT_POINTS') {
      throw rpcEx;
    }
  }

  // 2. OCC Compare-And-Swap Loop Fallback
  const maxAttempts = 5;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const { data: user, error: fetchErr } = await supabaseAdmin
      .from('users')
      .select('points')
      .eq('id', userId)
      .single();

    if (fetchErr || !user) {
      throw new Error(`User not found for points deduction: ${fetchErr?.message || 'Unknown'}`);
    }

    const currentPoints = parseInt(user.points || 0, 10);
    if (currentPoints < intPoints) {
      throw new Error('INSUFFICIENT_POINTS');
    }

    const targetPoints = currentPoints - intPoints;

    const { data: updated, error: updErr } = await supabaseAdmin
      .from('users')
      .update({
        points: targetPoints,
        updated_at: new Date().toISOString()
      })
      .eq('id', userId)
      .eq('points', currentPoints)
      .gte('points', intPoints)
      .select('points')
      .maybeSingle();

    if (!updErr && updated) {
      return parseInt(updated.points, 10);
    }

    await new Promise(r => setTimeout(r, 20 + Math.random() * 30));
  }

  throw new Error('Gagal memproses penukaran poin karena aktivitas bersamaan.');
}

/**
 * Atomic Points Increment (Earn Rewards)
 */
async function atomicIncrementPoints(userId, points) {
  const intPoints = parseInt(points, 10);
  if (!userId || isNaN(intPoints) || intPoints <= 0) {
    throw new Error('Invalid userId or points for points increment');
  }

  // 1. Try Supabase RPC function
  try {
    const { data: rpcPoints, error: rpcErr } = await supabaseAdmin.rpc('increment_user_points', {
      p_user_id: userId,
      p_points: intPoints
    });

    if (!rpcErr && rpcPoints !== null && rpcPoints !== undefined) {
      return parseInt(rpcPoints, 10);
    }
  } catch (rpcEx) {}

  // 2. OCC Compare-And-Swap Loop Fallback
  const maxAttempts = 5;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const { data: user, error: fetchErr } = await supabaseAdmin
      .from('users')
      .select('points')
      .eq('id', userId)
      .single();

    if (fetchErr || !user) {
      throw new Error(`User not found for points increment: ${fetchErr?.message || 'Unknown'}`);
    }

    const currentPoints = parseInt(user.points || 0, 10);
    const targetPoints = currentPoints + intPoints;

    const { data: updated, error: updErr } = await supabaseAdmin
      .from('users')
      .update({
        points: targetPoints,
        updated_at: new Date().toISOString()
      })
      .eq('id', userId)
      .eq('points', currentPoints)
      .select('points')
      .maybeSingle();

    if (!updErr && updated) {
      return parseInt(updated.points, 10);
    }

    await new Promise(r => setTimeout(r, 20 + Math.random() * 30));
  }

  throw new Error('Gagal menambahkan poin secara atomik.');
}

module.exports = {
  atomicIncrementBalance,
  atomicDeductBalance,
  atomicDeductPoints,
  atomicIncrementPoints
};
