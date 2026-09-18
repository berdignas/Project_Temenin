// backend/src/controllers/authController.js
const { supabaseAdmin } = require('../config/supabase');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { sendOtpSms } = require('../services/smsService');
const { sendOtpWhatsApp } = require('../services/whatsappService');
const { ensureAuthUser } = require('../utils/authSync');

// Helper: Sanitize Phone Number to standard formats
const sanitizePhone = (phone) => {
  if (!phone) return '';
  let cleaned = phone.toString().replace(/\D/g, '');
  if (cleaned.startsWith('62')) {
    cleaned = '0' + cleaned.substring(2);
  } else if (!cleaned.startsWith('0') && cleaned.length >= 8) {
    cleaned = '0' + cleaned;
  }
  return cleaned;
};

// Helper: Get Phone search variations
const getPhoneVariants = (phone) => {
  const digits = phone.toString().replace(/\D/g, '');
  const core = digits.replace(/^(0|62)/, '');
  return [
    core,
    '0' + core,
    '62' + core,
    '+62' + core,
    digits
  ];
};

/**
 * 1. REGISTRASI AKUN (Phone / Email + Password)
 * Mendukung registrasi via Email atau No. HP dengan password pilihan user yang di-hash aman.
 */
const register = async (req, res) => {
  try {
    const { email, password, full_name, phone, gender, avatar_url } = req.body;

    // Validasi Nama dan Password
    if (!full_name || full_name.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Nama lengkap wajib diisi'
      });
    }

    if (!password || password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password minimal 6 karakter'
      });
    }

    // Harus menyertakan minimal salah satu: Email atau No. HP
    if (!email && !phone) {
      return res.status(400).json({
        success: false,
        message: 'Nomor HP atau Email harus diisi'
      });
    }

    let cleanEmail = null;
    let cleanPhone = null;

    if (phone) {
      cleanPhone = sanitizePhone(phone);
      // Cek apakah nomor HP sudah terdaftar
      const phoneVariants = getPhoneVariants(cleanPhone);
      const { data: existingPhone } = await supabaseAdmin
        .from('users')
        .select('id, phone')
        .in('phone', phoneVariants)
        .maybeSingle();

      if (existingPhone) {
        return res.status(400).json({
          success: false,
          message: 'Nomor HP sudah terdaftar. Silakan login.'
        });
      }
    }

    if (email && email.trim().length > 0) {
      const emailRegex = /^[^\s@]+@([^\s@.,]+\.)+[^\s@.,]{2,}$/;
      if (!emailRegex.test(email.trim())) {
        return res.status(400).json({
          success: false,
          message: 'Format email tidak valid'
        });
      }
      cleanEmail = email.toLowerCase().trim();

      // Cek apakah email sudah terdaftar
      const { data: existingEmail } = await supabaseAdmin
        .from('users')
        .select('id, email')
        .eq('email', cleanEmail)
        .maybeSingle();

      if (existingEmail) {
        return res.status(400).json({
          success: false,
          message: 'Email sudah terdaftar. Silakan login.'
        });
      }
    } else if (cleanPhone) {
      // Jika registrasi hanya dengan no HP, buat email identifier internal
      cleanEmail = `${cleanPhone}@temenin.aja`;
    }

    // 🔒 Hash password pengguna menggunakan bcrypt (10 salt rounds)
    const salt = await bcrypt.genSalt(10);
    const password_hash = await bcrypt.hash(password, salt);

    // Avatar from file upload or URL
    const finalAvatarUrl = req.file ? `/uploads/${req.file.filename}` : (avatar_url || null);

    // Insert user baru ke database
    const { data: user, error: dbError } = await supabaseAdmin
      .from('users')
      .insert([
        {
          email: cleanEmail,
          password_hash: password_hash,
          full_name: full_name.trim(),
          phone: cleanPhone,
          gender: gender?.trim() || 'Laki-laki',
          avatar_url: finalAvatarUrl,
          role: 'client',
          balance: 0,
          points: 0,
          is_verified: true,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        }
      ])
      .select()
      .single();

    if (dbError) {
      console.error('Registration DB Error:', dbError);
      return res.status(400).json({
        success: false,
        message: 'Gagal mendaftar: ' + dbError.message
      });
    }

    // Ensure user exists in auth.users for payment_transactions FK compatibility & GoTrue session
    await ensureAuthUser(user.id, user.email);

    // Generate token JWT with Supabase GoTrue compatible claims
    const token = jwt.sign(
      { 
        aud: 'authenticated',
        role: 'authenticated',
        sub: user.id,
        id: user.id, 
        email: user.email, 
        phone: user.phone,
        full_name: user.full_name,
        app_metadata: {
          provider: 'email',
          providers: ['email'],
          role: user.role || 'client'
        },
        user_metadata: {
          full_name: user.full_name,
          role: user.role || 'client'
        }
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    const { password_hash: _, ...userWithoutPassword } = user;

    res.status(201).json({
      success: true,
      message: 'Registrasi berhasil! Selamat datang di Temenin Ajaa.',
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

/**
 * 2. LOGIN AKUN (Identifier: Email / No. HP / Username + Password)
 * Mendukung login instan tanpa OTP jika password cocok.
 */
const login = async (req, res) => {
  try {
    const { identifier, email, phone, username, password } = req.body;
    const loginIdentifier = (identifier || email || phone || username || '').toString().trim();

    if (!loginIdentifier || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email / Nomor HP dan kata sandi wajib diisi'
      });
    }

    let user = null;

    // Kasus 1: Identifier adalah format Email
    if (loginIdentifier.includes('@')) {
      const cleanEmail = loginIdentifier.toLowerCase();
      const { data: userByEmail } = await supabaseAdmin
        .from('users')
        .select('*')
        .eq('email', cleanEmail)
        .maybeSingle();

      user = userByEmail;
    } 
    // Kasus 2: Identifier adalah Nomor Telepon / Angka
    else {
      const phoneVariants = getPhoneVariants(loginIdentifier);
      
      // Cari berdasarkan varian no HP
      const { data: userByPhone } = await supabaseAdmin
        .from('users')
        .select('*')
        .in('phone', phoneVariants)
        .maybeSingle();

      if (userByPhone) {
        user = userByPhone;
      } else {
        // Fallback cari email `${phone}@temenin.aja`
        const cleanPhone = sanitizePhone(loginIdentifier);
        const { data: userByDummyEmail } = await supabaseAdmin
          .from('users')
          .select('*')
          .eq('email', `${cleanPhone}@temenin.aja`)
          .maybeSingle();
          
        user = userByDummyEmail;
      }
    }

    // Jika belum ketemu, coba pencarian case-insensitive pada email
    if (!user) {
      const { data: userFallback } = await supabaseAdmin
        .from('users')
        .select('*')
        .ilike('email', loginIdentifier)
        .maybeSingle();

      user = userFallback;
    }

    // User tidak ditemukan
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Email/Nomor HP atau kata sandi salah'
      });
    }

    // Pastikan user memiliki hash password
    if (!user.password_hash) {
      return res.status(401).json({
        success: false,
        message: 'Akun belum memiliki kata sandi. Silakan buat kata sandi terlebih dahulu.'
      });
    }

    // 🔒 Verifikasi kata sandi dengan bcrypt
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Email/Nomor HP atau kata sandi salah'
      });
    }

    // Pastikan user tercatat di auth.users Supabase
    await ensureAuthUser(user.id, user.email);

    // Generate token JWT dengan klaim standar Supabase GoTrue
    const token = jwt.sign(
      { 
        aud: 'authenticated',
        role: 'authenticated',
        sub: user.id,
        id: user.id, 
        email: user.email, 
        phone: user.phone,
        full_name: user.full_name,
        app_metadata: {
          provider: 'email',
          providers: ['email'],
          role: user.role || 'client'
        },
        user_metadata: {
          full_name: user.full_name,
          role: user.role || 'client'
        }
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    const { password_hash: _, ...userWithoutPassword } = user;

    res.status(200).json({
      success: true,
      message: 'Login berhasil!',
      data: {
        user: userWithoutPassword,
        token: token
      }
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan pada server: ' + error.message
    });
  }
};

/**
 * 3. GET CURRENT USER (ME)
 */
const getMe = async (req, res) => {
  try {
    const user = req.user;
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

/**
 * 4. UPDATE PROFILE
 */
const updateProfile = async (req, res) => {
  try {
    const { full_name, phone, avatar_url, gender } = req.body;
    const userId = req.user.id;

    const updates = {
      updated_at: new Date().toISOString()
    };
    if (full_name !== undefined) updates.full_name = full_name.trim();
    if (phone !== undefined) updates.phone = sanitizePhone(phone);
    if (avatar_url !== undefined) updates.avatar_url = avatar_url;
    if (gender !== undefined) updates.gender = gender;

    const { data: user, error } = await supabaseAdmin
      .from('users')
      .update(updates)
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
      message: 'Profil berhasil diperbarui',
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

/**
 * 5. SEND OTP (Perbaikan: Tidak membocorkan kode OTP di response JSON)
 */
const sendOtp = async (req, res) => {
  try {
    const { phone, channel } = req.body;
    if (!phone) {
      return res.status(400).json({ success: false, message: 'Nomor HP wajib diisi' });
    }

    const cleanPhone = sanitizePhone(phone);
    
    // Generate 6-digit OTP acak kriptografis
    const otpCode = crypto.randomInt(100000, 1000000).toString();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 menit kedaluwarsa

    const { error } = await supabaseAdmin
      .from('otp_codes')
      .insert([
        {
          phone: cleanPhone,
          code: otpCode,
          expires_at: expiresAt.toISOString(),
          is_used: false
        }
      ]);

    if (error) {
      console.error('Insert OTP Error:', error);
      return res.status(500).json({ success: false, message: 'Gagal membuat kode OTP' });
    }

    // 1. Kirim OTP via Zenziva Gateway (Voice Call OTP / WhatsApp / SMS)
    let sendResult = await sendOtpSms(cleanPhone, otpCode, channel);

    // 2. Jika Zenziva gagal atau Meta diaktifkan, coba kirim via Meta WhatsApp Cloud API
    if (!sendResult.success && process.env.WHATSAPP_PHONE_NUMBER_ID) {
      sendResult = await sendOtpWhatsApp(cleanPhone, otpCode);
    }

    const channelInfo = sendResult.channel ? ` (${sendResult.channel})` : '';

    // 🛡️ PERBAIKAN KEAMANAN: Hapus properti `otp` dari response JSON
    res.status(200).json({
      success: true,
      channel: sendResult.channel || 'Zenziva Gateway',
      message: `Kode OTP verifikasi berhasil dikirim ke nomor Anda${channelInfo}`
    });
  } catch (error) {
    console.error('Send OTP Error:', error);
    res.status(500).json({ success: false, message: 'Terjadi kesalahan server saat mengirim OTP' });
  }
};

/**
 * 6. VERIFY OTP
 */
const verifyOtp = async (req, res) => {
  try {
    const { phone, otp } = req.body;
    if (!phone || !otp) {
      return res.status(400).json({ success: false, message: 'Nomor HP dan kode OTP wajib diisi' });
    }

    // Sandbox / Test bypass
    if (otp.toString().trim() === '123456') {
      return res.status(200).json({
        success: true,
        message: 'Verifikasi OTP berhasil (Mode Sandbox 123456)',
        data: { isRegistered: true }
      });
    }

    const cleanPhone = sanitizePhone(phone);

    // Cari OTP valid
    const { data: otpRecord, error } = await supabaseAdmin
      .from('otp_codes')
      .select('*')
      .eq('phone', cleanPhone)
      .eq('code', otp.trim())
      .eq('is_used', false)
      .gte('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error || !otpRecord) {
      return res.status(400).json({ success: false, message: 'Kode OTP tidak valid atau sudah kedaluwarsa' });
    }

    // Tandai OTP telah digunakan
    await supabaseAdmin
      .from('otp_codes')
      .update({ is_used: true })
      .eq('id', otpRecord.id);

    // Cek apakah nomor HP sudah terdaftar
    const phoneVariants = getPhoneVariants(cleanPhone);
    const { data: existingUser } = await supabaseAdmin
      .from('users')
      .select('id, full_name, phone')
      .in('phone', phoneVariants)
      .maybeSingle();

    return res.status(200).json({
      success: true,
      message: 'Verifikasi OTP berhasil',
      data: { 
        isRegistered: !!existingUser 
      }
    });
  } catch (error) {
    console.error('Verify OTP Error:', error);
    res.status(500).json({ success: false, message: 'Terjadi kesalahan server saat memverifikasi OTP' });
  }
};

/**
 * 7. SETUP ACCOUNT (Set Email & Password untuk akun berbasis nomor HP)
 */
const setupAccount = async (req, res) => {
  try {
    const { email, password } = req.body;
    const userId = req.user.id;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email dan password wajib diisi' });
    }
    
    if (password.length < 6) {
      return res.status(400).json({ success: false, message: 'Password minimal 6 karakter' });
    }

    const cleanEmail = email.toLowerCase().trim();

    // Pastikan email belum digunakan akun lain
    const { data: existingUser } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('email', cleanEmail)
      .neq('id', userId)
      .maybeSingle();

    if (existingUser) {
      return res.status(400).json({ success: false, message: 'Email sudah digunakan akun lain' });
    }

    const salt = await bcrypt.genSalt(10);
    const password_hash = await bcrypt.hash(password, salt);

    // Update data di tabel users
    const { error: updateError } = await supabaseAdmin
      .from('users')
      .update({
        email: cleanEmail,
        password_hash: password_hash,
        is_verified: true,
        updated_at: new Date().toISOString()
      })
      .eq('id', userId);

    if (updateError) {
      return res.status(500).json({ success: false, message: 'Gagal memperbarui akun: ' + updateError.message });
    }

    res.status(200).json({
      success: true,
      message: 'Pengaturan akun berhasil disimpan'
    });
  } catch (error) {
    console.error('Setup Account Error:', error);
    res.status(500).json({ success: false, message: 'Terjadi kesalahan server saat setup akun' });
  }
};

module.exports = {
  register,
  login,
  getMe,
  updateProfile,
  sendOtp,
  verifyOtp,
  setupAccount
};