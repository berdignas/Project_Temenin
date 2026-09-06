// controllers/authController.js
const { supabase, supabaseAdmin } = require('../config/supabase');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const register = async (req, res) => {
  try {
    const { email, password, full_name, phone, avatar_url } = req.body;

    // Check if phone registration
    if (phone && !email) {
      const cleanPhone = phone.trim();
      if (!full_name) {
        return res.status(400).json({
          success: false,
          message: 'Nama lengkap harus diisi'
        });
      }

      // Cek apakah nomor HP sudah terdaftar
      const { data: existingUserByPhone, error: checkPhoneError } = await supabaseAdmin.from('users')
        .select('phone')
        .eq('phone', cleanPhone)
        .maybeSingle();

      if (existingUserByPhone) {
        return res.status(400).json({
          success: false,
          message: 'Nomor HP sudah terdaftar'
        });
      }

      const generatedEmail = `${cleanPhone}@temenin.aja`;
      const salt = await bcrypt.genSalt(10);
      const password_hash = await bcrypt.hash('phone_auth_secure_pass', salt);

      // Buat user di tabel users
      const { data: user, error: dbError } = await supabaseAdmin.from('users')
        .insert([
          {
            email: generatedEmail,
            password_hash: password_hash,
            full_name: full_name.trim(),
            phone: cleanPhone,
            avatar_url: avatar_url || null,
            balance: 150000, // Bonus saldo pendaftaran
            points: 500, // Bonus poin
            is_verified: true,
            created_at: new Date(),
            updated_at: new Date()
          }
        ])
        .select()
        .single();

      if (dbError) {
        console.error('DB Error:', dbError);
        return res.status(400).json({
          success: false,
          message: 'Gagal mendaftar: ' + dbError.message
        });
      }

      // Buat token JWT
      const token = jwt.sign(
        { id: user.id, email: user.email },
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRE || '7d' }
      );

      const { password_hash: _, ...userWithoutPassword } = user;

      return res.status(201).json({
        success: true,
        message: 'Registrasi berhasil',
        data: {
          user: userWithoutPassword,
          token: token
        }
      });
    }

    // Fallback to email registration
    if (!email || !password || !full_name) {
      return res.status(400).json({
        success: false,
        message: 'Email, password, dan full name harus diisi'
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password minimal 6 karakter'
      });
    }

    const emailRegex = /^[^\s@]+@([^\s@.,]+\.)+[^\s@.,]{2,}$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Format email tidak valid'
      });
    }

    const cleanEmail = email.toLowerCase().trim();

    const { data: existingUser, error: checkError } = await supabaseAdmin.from('users')
      .select('email')
      .eq('email', cleanEmail)
      .maybeSingle();

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email sudah terdaftar'
      });
    }

    const salt = await bcrypt.genSalt(10);
    const password_hash = await bcrypt.hash(password, salt);

    const { data: user, error: dbError } = await supabaseAdmin.from('users')
      .insert([
        {
          email: cleanEmail,
          password_hash: password_hash,
          full_name: full_name.trim(),
          phone: phone?.trim() || null,
          balance: 0,
          points: 0,
          is_verified: true,
          created_at: new Date(),
          updated_at: new Date()
        }
      ])
      .select()
      .single();

    if (dbError) {
      console.error('DB Error:', dbError);
      return res.status(400).json({
        success: false,
        message: 'Gagal mendaftar: ' + dbError.message
      });
    }

    try {
      await supabaseAdmin.auth.admin.createUser({
        email: cleanEmail,
        password: password,
        email_confirm: true,
        user_metadata: {
          full_name: full_name.trim(),
          phone: phone?.trim() || ''
        }
      });
    } catch (authError) {
      console.warn('Supabase Auth creation failed (non-critical):', authError.message);
    }

    const token = jwt.sign(
      { id: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    const { password_hash: _, ...userWithoutPassword } = user;

    res.status(201).json({
      success: true,
      message: 'Registrasi berhasil',
      data: {
        user: userWithoutPassword,
        token: token
      }
    });
    
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan pada server: ' + error.message
    });
  }
};

const login = async (req, res) => {
  try {
    const { email, password, phone, otp } = req.body;
    
    // Check if phone-based login
    if (phone) {
      if (!otp || otp.length !== 6) {
        return res.status(400).json({
          success: false,
          message: 'Kode OTP tidak valid'
        });
      }

      const cleanPhone = phone.trim();
      
      console.log('\n═══════════════════════════════════════════════════');
      console.log('🔐 PHONE LOGIN REQUEST');
      console.log(`📞 Phone: ${cleanPhone}`);
      console.log(`🔢 OTP: ${otp}`);
      console.log('═══════════════════════════════════════════════════');

      // Verify OTP against database
      const { data: otpRecord, error: otpError } = await supabaseAdmin
        .from('otp_codes')
        .select('*')
        .eq('phone', cleanPhone)
        .eq('code', otp)
        .eq('is_used', false)
        .gte('expires_at', new Date().toISOString())
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (otpError || !otpRecord) {
        console.error('❌ OTP Verification failed:', otpError);
        return res.status(400).json({
          success: false,
          message: 'OTP tidak valid atau sudah kedaluwarsa'
        });
      }

      // Mark OTP as used
      await supabaseAdmin
        .from('otp_codes')
        .update({ is_used: true })
        .eq('id', otpRecord.id);

      // Cari user berdasarkan nomor HP
      const { data: user, error } = await supabaseAdmin.from('users')
        .select('*')
        .eq('phone', cleanPhone)
        .maybeSingle();

      if (error) {
        console.error('❌ Database error:', error);
        return res.status(500).json({
          success: false,
          message: 'Terjadi kesalahan database'
        });
      }

      if (!user) {
        console.log('❌ User not found with phone:', cleanPhone);
        return res.status(401).json({
          success: false,
          message: 'Nomor HP tidak terdaftar. Silakan registrasi terlebih dahulu.'
        });
      }

      console.log('✅ User found:', user.email);
      console.log('✅ Login successful!');
      console.log('═══════════════════════════════════════════════════\n');

      // Generate token JWT
      const token = jwt.sign(
        { 
          id: user.id, 
          email: user.email,
          full_name: user.full_name 
        },
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRE || '7d' }
      );

      // Hapus password_hash dari response
      const { password_hash: _, ...userWithoutPassword } = user;

      return res.status(200).json({
        success: true,
        message: 'Login berhasil',
        data: {
          user: userWithoutPassword,
          token: token
        }
      });
    }
    
    // Fallback to email/password login
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email dan password harus diisi'
      });
    }
    
    const cleanEmail = email.toLowerCase().trim();
    
    console.log('\n═══════════════════════════════════════════════════');
    console.log('🔐 EMAIL LOGIN REQUEST');
    console.log(`📧 Email: ${cleanEmail}`);
    console.log('═══════════════════════════════════════════════════');

    const { data: user, error } = await supabaseAdmin.from('users')
      .select('*')
      .eq('email', cleanEmail)
      .maybeSingle();

    if (error) {
      console.error('❌ Database error:', error);
      return res.status(401).json({
        success: false,
        message: 'Email atau password salah'
      });
    }

    if (!user) {
      console.log('❌ User not found with email:', cleanEmail);
      return res.status(401).json({
        success: false,
        message: 'Email atau password salah'
      });
    }

    console.log('✅ User found:', user.email);

    if (!user.password_hash) {
      console.error('❌ No password_hash for user');
      return res.status(401).json({
        success: false,
        message: 'Email atau password salah'
      });
    }
    
    let isPasswordValid = false;
    if (user.password_hash) {
      try {
        isPasswordValid = await bcrypt.compare(password, user.password_hash);
      } catch (_) {}

      if (!isPasswordValid && password === user.password_hash) {
        isPasswordValid = true;
        try {
          const salt = await bcrypt.genSalt(10);
          const hashed = await bcrypt.hash(password, salt);
          await supabaseAdmin.from('users').update({ password_hash: hashed }).eq('id', user.id);
        } catch (hErr) {
          console.error('Failed re-hashing password:', hErr);
        }
      }
    }
    console.log('🔑 Password valid:', isPasswordValid);

    if (!isPasswordValid) {
      console.log('❌ Invalid password');
      return res.status(401).json({
        success: false,
        message: 'Email atau password salah'
      });
    }

    console.log('✅ Login successful!');
    console.log('═══════════════════════════════════════════════════\n');

    const token = jwt.sign(
      { 
        id: user.id, 
        email: user.email,
        full_name: user.full_name 
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    const { password_hash: _, ...userWithoutPassword } = user;

    res.status(200).json({
      success: true,
      message: 'Login berhasil',
      data: {
        user: userWithoutPassword,
        token: token
      }
    });
    
  } catch (error) {
    console.error('❌ Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan pada server'
    });
  }
};

// Get Current User
const getMe = async (req, res) => {
  try {
    const user = req.user;
    // Sync with auth.users to check if email was verified
    if (user.is_verified === false && user.email) {
      try {
        const { data: authUsers } = await supabaseAdmin.auth.admin.listUsers();
        const authUser = authUsers.users.find(u => u.email === user.email);
        
        if (authUser && authUser.email_confirmed_at != null) {
          // Update public.users
          await supabaseAdmin.from('users').update({ is_verified: true }).eq('id', user.id);
          user.is_verified = true;
        }
      } catch (e) {
        console.warn('Could not sync auth.users in getMe:', e.message);
      }
    }

    const { password_hash: _, ...userWithoutPassword } = user;
    res.status(200).json({
      success: true,
      data: userWithoutPassword
    });
  } catch (error) {
    console.error('GetMe error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Update Profile
const updateProfile = async (req, res) => {
  try {
    const { full_name, phone, avatar_url } = req.body;
    const userId = req.user.id;

    const { data: user, error } = await supabaseAdmin.from('users')
      .update({
        full_name: full_name?.trim(),
        phone: phone?.trim(),
        avatar_url: avatar_url,
        updated_at: new Date()
      })
      .eq('id', userId)
      .select()
      .single();

    if (error) {
      console.error('Update profile error:', error);
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    const { password_hash: _, ...userWithoutPassword } = user;

    res.status(200).json({
      success: true,
      message: 'Profil berhasil diupdate',
      data: userWithoutPassword
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// ==========================================
// BARU: ALUR REGISTRASI MENGGUNAKAN OTP
// ==========================================

// 1. Send OTP
const sendOtp = async (req, res) => {
  try {
    const { phone } = req.body;
    
    if (!phone) {
      return res.status(400).json({ success: false, message: 'Nomor HP wajib diisi' });
    }

    const cleanPhone = phone.trim();
    
    // Generate 6 digit OTP acak secara dinamis (Mocking tanpa Twilio)
    // Akan menghasilkan angka acak antara 100000 hingga 999999
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    
    const expiresAt = new Date();
    expiresAt.setMinutes(expiresAt.getMinutes() + 5); // 5 menit kedaluwarsa

    const { error } = await supabaseAdmin
      .from('otp_codes')
      .insert([
        {
          phone: cleanPhone,
          code: otpCode,
          expires_at: expiresAt,
          is_used: false
        }
      ]);

    if (error) {
      console.error('Insert OTP Error:', error);
      return res.status(500).json({ success: false, message: 'Gagal membuat OTP' });
    }

    console.log(`[MOCK TWILIO] OTP untuk ${cleanPhone} adalah ${otpCode}`);

    res.status(200).json({
      success: true,
      message: 'OTP berhasil dikirim',
      otp: otpCode
    });
  } catch (error) {
    console.error('Send OTP Error:', error);
    res.status(500).json({ success: false, message: 'Terjadi kesalahan server saat mengirim OTP' });
  }
};

// 2. Verify OTP
const verifyOtp = async (req, res) => {
  try {
    const { phone, otp } = req.body;
    
    if (!phone || !otp) {
      return res.status(400).json({ success: false, message: 'Nomor HP dan OTP wajib diisi' });
    }

    const cleanPhone = phone.trim();

    // Cari OTP valid
    const { data: otpRecord, error } = await supabaseAdmin
      .from('otp_codes')
      .select('*')
      .eq('phone', cleanPhone)
      .eq('code', otp)
      .eq('is_used', false)
      .gte('expires_at', new Date().toISOString()) // belum kedaluwarsa
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error || !otpRecord) {
      return res.status(400).json({ success: false, message: 'OTP tidak valid atau sudah kedaluwarsa' });
    }

    // Tandai OTP sudah digunakan
    await supabaseAdmin
      .from('otp_codes')
      .update({ is_used: true })
      .eq('id', otpRecord.id);

    // Cek apakah user sudah terdaftar
    const { data: existingUser } = await supabaseAdmin.from('users')
      .select('*')
      .eq('phone', cleanPhone)
      .maybeSingle();

    if (existingUser) {
      return res.status(200).json({
        success: true,
        message: 'OTP valid, nomor sudah terdaftar. Silakan login.',
        data: { isRegistered: true }
      });
    }

    // Jika belum terdaftar, izinkan lanjut ke form registrasi
    return res.status(200).json({
      success: true,
      message: 'OTP valid, silakan lengkapi profil',
      data: { isRegistered: false }
    });
  } catch (error) {
    console.error('Verify OTP Error:', error);
    res.status(500).json({ success: false, message: 'Terjadi kesalahan server saat memverifikasi OTP' });
  }
};

// 3. Registrasi menggunakan OTP, Nama, dan Upload Foto
const registerWithOtp = async (req, res) => {
  try {
    const { phone, full_name } = req.body;
    const file = req.file;

    if (!phone || !full_name) {
      return res.status(400).json({ success: false, message: 'Nomor HP dan Nama Lengkap wajib diisi' });
    }

    const cleanPhone = phone.trim();

    // Cek duplikasi
    const { data: existingUser } = await supabaseAdmin.from('users')
      .select('id')
      .eq('phone', cleanPhone)
      .maybeSingle();

    if (existingUser) {
      return res.status(400).json({ success: false, message: 'Nomor HP sudah terdaftar' });
    }

    let avatar_url = null;
    if (file) {
      // Set path file secara statik
      avatar_url = `/uploads/${file.filename}`;
    }

    const generatedEmail = `${cleanPhone}@temenin.aja`;

    const { data: user, error: dbError } = await supabaseAdmin.from('users')
      .insert([
        {
          email: generatedEmail,
          full_name: full_name.trim(),
          phone: cleanPhone,
          avatar_url: avatar_url,
          balance: 0,
          points: 0,
          is_verified: false, // Forces email & password setup + verification
          created_at: new Date(),
          updated_at: new Date()
        }
      ])
      .select()
      .single();

    if (dbError) {
      return res.status(400).json({ success: false, message: 'Gagal mendaftar: ' + dbError.message });
    }

    const token = jwt.sign(
      { id: user.id, phone: user.phone, full_name: user.full_name },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    const { password_hash: _, ...userWithoutPassword } = user;

    res.status(201).json({
      success: true,
      message: 'Registrasi berhasil',
      data: { user: userWithoutPassword, token }
    });
  } catch (error) {
    console.error('Register OTP Error:', error);
    res.status(500).json({ success: false, message: 'Terjadi kesalahan server saat registrasi' });
  }
};

// 4. Login setelah OTP divalidasi
const loginWithOtp = async (req, res) => {
  try {
    const { phone } = req.body;
    
    if (!phone) {
      return res.status(400).json({ success: false, message: 'Nomor HP wajib diisi' });
    }

    const cleanPhone = phone.trim();

    // Pastikan user ada
    const { data: user, error } = await supabaseAdmin.from('users')
      .select('*')
      .eq('phone', cleanPhone)
      .maybeSingle();

    if (error || !user) {
      return res.status(401).json({ success: false, message: 'Nomor HP tidak terdaftar' });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, full_name: user.full_name },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    const { password_hash: _, ...userWithoutPassword } = user;

    res.status(200).json({
      success: true,
      message: 'Login berhasil',
      data: { user: userWithoutPassword, token }
    });
  } catch (error) {
    console.error('Login OTP Error:', error);
    res.status(500).json({ success: false, message: 'Terjadi kesalahan server saat login' });
  }
};

// 5. Setup Account (Email & Password)
const setupAccount = async (req, res) => {
  try {
    const { email, password } = req.body;
    const userId = req.user.id; // from protect middleware

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email dan password wajib diisi' });
    }
    
    if (password.length < 6) {
      return res.status(400).json({ success: false, message: 'Password minimal 6 karakter' });
    }

    const cleanEmail = email.toLowerCase().trim();

    // Check if email already used in public.users
    const { data: existingUser } = await supabaseAdmin.from('users')
      .select('id')
      .eq('email', cleanEmail)
      .neq('id', userId)
      .maybeSingle();

    if (existingUser) {
      return res.status(400).json({ success: false, message: 'Email sudah digunakan akun lain' });
    }

    const salt = await bcrypt.genSalt(10);
    const password_hash = await bcrypt.hash(password, salt);

    // Create user in Supabase Auth
    try {
      await supabaseAdmin.auth.admin.createUser({
        email: cleanEmail,
        password: password,
        email_confirm: true, // Auto verify for frontend testing
        user_metadata: {
          public_user_id: userId
        }
      });
    } catch (authError) {
      console.warn('Supabase Auth creation warning:', authError.message);
      if (authError.message.includes('already registered')) {
        return res.status(400).json({ success: false, message: 'Email sudah terdaftar di sistem Auth' });
      }
    }

    // Update public.users
    const { error: updateError } = await supabaseAdmin.from('users')
      .update({
        email: cleanEmail,
        password_hash: password_hash,
        is_verified: true, // Auto verified for frontend testing
        updated_at: new Date()
      })
      .eq('id', userId);

    if (updateError) {
      return res.status(500).json({ success: false, message: 'Gagal update profil' });
    }

    res.status(200).json({
      success: true,
      message: 'Setup akun berhasil, silakan periksa email Anda untuk verifikasi'
    });
  } catch (error) {
    console.error('Setup Account Error:', error);
    res.status(500).json({ success: false, message: 'Terjadi kesalahan server saat setup akun' });
  }
};

// Export semua fungsi
module.exports = {
  register,
  login,
  getMe,
  updateProfile,
  sendOtp,
  verifyOtp,
  registerWithOtp,
  loginWithOtp,
  setupAccount
};