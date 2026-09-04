const fs = require('fs');
const file = 'src/controllers/authController.js';
let code = fs.readFileSync(file, 'utf8');
code = code.replace(/supabase\s*\.from\('users'\)/g, "supabaseAdmin.from('users')");
fs.writeFileSync(file, code);
console.log('Done!');
