// backend/src/config/supabase.js

// Polyfill WebSocket globally for Node.js < 22 Supabase compatibility
try {
  global.WebSocket = require('ws');
} catch (e) {
  console.warn('⚠️ ws package is not installed/loaded:', e.message);
}

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Client untuk operasi umum
const supabase = createClient(
  supabaseUrl,
  supabaseAnonKey,
  {
    auth: {
      persistSession: false
    }
  }
);

// Client admin untuk operasi khusus
const supabaseAdmin = createClient(
  supabaseUrl,
  supabaseServiceKey,
  {
    auth: {
      persistSession: false
    }
  }
);

// 🔴 TAMBAHKAN: Fungsi query wrapper untuk kompatibilitas
const query = async (text, params) => {
  try {
    // Parse SQL query sederhana untuk menentukan table dan action
    // Ini adalah wrapper sederhana, untuk production sebaiknya gunakan ORM
    console.log('📝 Executing query:', text.substring(0, 100), params);
    
    // Untuk SELECT queries
    if (text.trim().toUpperCase().startsWith('SELECT')) {
      // Extract table name from query (sederhana)
      const fromMatch = text.match(/FROM\s+(\w+)/i);
      const tableName = fromMatch ? fromMatch[1] : null;
      
      if (!tableName) {
        throw new Error('Could not determine table name from query');
      }
      
      // Build Supabase query
      let supabaseQuery = supabase.from(tableName).select('*');
      
      // Handle WHERE clause sederhana
      const whereMatch = text.match(/WHERE\s+(\w+)\s*=\s*\$(\d+)/i);
      if (whereMatch && params) {
        const column = whereMatch[1];
        const paramIndex = parseInt(whereMatch[2]) - 1;
        const value = params[paramIndex];
        supabaseQuery = supabaseQuery.eq(column, value);
      }
      
      const { data, error } = await supabaseQuery;
      
      if (error) throw error;
      return { rows: data, rowCount: data.length };
    }
    
    // Untuk UPDATE queries
    if (text.trim().toUpperCase().startsWith('UPDATE')) {
      const tableMatch = text.match(/UPDATE\s+(\w+)/i);
      const tableName = tableMatch ? tableMatch[1] : null;
      
      if (!tableName) {
        throw new Error('Could not determine table name from query');
      }
      
      // Extract SET clause
      const setMatch = text.match(/SET\s+(\w+)\s*=\s*\$(\d+)/i);
      if (!setMatch || !params) {
        throw new Error('Could not parse UPDATE query');
      }
      
      const column = setMatch[1];
      const paramIndex = parseInt(setMatch[2]) - 1;
      const value = params[paramIndex];
      
      // Extract WHERE clause
      const whereMatch = text.match(/WHERE\s+(\w+)\s*=\s*\$(\d+)/i);
      let userId = null;
      if (whereMatch && params) {
        const whereParamIndex = parseInt(whereMatch[2]) - 1;
        userId = params[whereParamIndex];
      }
      
      const { data, error } = await supabase
        .from(tableName)
        .update({ [column]: value, updated_at: new Date() })
        .eq('id', userId)
        .select();
      
      if (error) throw error;
      return { rows: data, rowCount: data.length };
    }
    
    throw new Error('Query type not supported in wrapper');
    
  } catch (error) {
    console.error('Query error:', error);
    throw error;
  }
};

module.exports = {
  supabase,
  supabaseAdmin,
  query 
};