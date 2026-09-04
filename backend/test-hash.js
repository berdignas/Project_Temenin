const { supabase } = require('./src/config/supabase');

async function testConnection() {
  console.log('Testing Supabase connection...');
  
  // Test query
  const { data, error } = await supabase
    .from('users')
    .select('*')
    .limit(1);
  
  if (error) {
    console.error('❌ Connection failed:', error.message);
    console.error('Error details:', error);
  } else {
    console.log('✅ Connection successful!');
    console.log('Users found:', data?.length || 0);
  }
  
  // Check environment variables
  console.log('\n📋 Environment check:');
  console.log('SUPABASE_URL:', process.env.SUPABASE_URL ? '✅ Set' : '❌ Missing');
  console.log('SUPABASE_ANON_KEY:', process.env.SUPABASE_ANON_KEY ? '✅ Set' : '❌ Missing');
}

testConnection();