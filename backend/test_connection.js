const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function check() {
  const { data, error } = await supabase.from('users').select('*').limit(1);
  if (data && data.length > 0) {
    const user = data[0];
    console.log('User raw fields and types:');
    for (const key of Object.keys(user)) {
      console.log(`- ${key}: value=${user[key]}, type=${typeof user[key]}`);
    }
  }
}

check();
