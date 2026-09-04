const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function run() {
  try {
    const { data: data2, error: error2 } = await supabase
      .from('bookings')
      .select('count')
      .limit(1);
    if (error2) {
      console.error('error querying bookings:', error2);
    } else {
      console.log('Bookings table query successful, count returned:', data2);
    }

    // Try to list tables via postgres query if possible, or query a mock table
    const { data: msgData, error: msgError } = await supabase
      .from('messages')
      .select('*')
      .limit(1);
    if (msgError) {
      console.log('messages table error (probably does not exist):', msgError.message);
    } else {
      console.log('messages table exists!', msgData);
    }
  } catch (e) {
    console.error(e);
  }
}

run();
