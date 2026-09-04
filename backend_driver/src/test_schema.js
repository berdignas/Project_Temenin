const { supabase } = require('./config/supabase');
require('dotenv').config();

async function inspectSchema() {
  try {
    const { data, error } = await supabase
      .from('drivers')
      .select('*')
      .limit(1);
    
    if (error) {
      console.error('Error fetching driver:', error);
      return;
    }
    console.log('Driver row keys:', Object.keys(data[0] || {}));
    
    const { data: userData, error: userError } = await supabase
      .from('users')
      .select('*')
      .limit(1);
    if (userError) {
      console.error('Error fetching user:', userError);
      return;
    }
    console.log('User row keys:', Object.keys(userData[0] || {}));
  } catch (err) {
    console.error('Unexpected error:', err);
  }
}

inspectSchema();
