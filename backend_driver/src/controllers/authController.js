const { supabase } = require('../config/supabase');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const register = async (req, res) => {
  try {
    const { email, password, full_name, phone, role, gender, vehicle_type, vehicle_name, plate_number, vehicle_stnk } = req.body;

    if (!email || !password || !full_name) {
      return res.status(400).json({
        success: false,
        message: 'Email, password, and full name are required'
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters'
      });
    }

    const cleanEmail = email.toLowerCase().trim();

    // Check if user already exists
    const { data: existingUser } = await supabase
      .from('users')
      .select('email')
      .eq('email', cleanEmail)
      .maybeSingle();

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email already registered'
      });
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const password_hash = await bcrypt.hash(password, salt);

    // Create user record
    const { data: user, error: dbError } = await supabase
      .from('users')
      .insert([
        {
          email: cleanEmail,
          password_hash: password_hash,
          full_name: full_name.trim(),
          phone: phone?.trim() || null,
          gender: gender || null,
          role: role || 'driver', // Default to driver for this backend
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
      return res.status(400).json({
        success: false,
        message: 'Failed to register: ' + dbError.message
      });
    }

    // Create driver record if role is driver
    if (user.role === 'driver') {
      const { error: driverError } = await supabase
        .from('drivers')
        .insert([
          {
            user_id: user.id,
            vehicle_type: vehicle_type || 'Motor',
            vehicle_name: vehicle_name?.trim() || 'Kendaraan Driver',
            plate_number: plate_number?.trim() || 'B 1234 OK',
            vehicle_stnk: vehicle_stnk || null,
            price_per_hour: vehicle_type === 'Mobil' ? 150000 : 50000,
            rating: 5.00,
            total_rides: 0,
            is_available: true,
            status: 'approved',
            created_at: new Date(),
            updated_at: new Date()
          }
        ]);
        
      if (driverError) {
        console.error('Failed to insert driver profile:', driverError);
      }
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    const { password_hash: _, ...userWithoutPassword } = user;

    res.status(201).json({
      success: true,
      message: 'Registrasi Mitra Driver berhasil',
      data: {
        user: userWithoutPassword,
        token: token
      }
    });
    
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error: ' + error.message
    });
  }
};

const login = async (req, res) => {
  try {
    const { email, password } = req.body;
    
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email dan kata sandi wajib diisi'
      });
    }
    
    const cleanEmail = email.toLowerCase().trim();
    
    // Find user in database
    const { data: user, error } = await supabase
      .from('users')
      .select('*')
      .eq('email', cleanEmail)
      .maybeSingle();

    if (error || !user) {
      return res.status(401).json({
        success: false,
        message: 'Alamat email tidak ditemukan. Pastikan email Anda sudah terdaftar.'
      });
    }

    // Check role (Must be driver)
    if (user.role && user.role !== 'driver') {
      return res.status(403).json({
        success: false,
        message: 'Akun ini terdaftar sebagai Klien/Penumpang, bukan sebagai Mitra Driver.'
      });
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Kata sandi salah. Silakan periksa kembali kata sandi Anda.'
      });
    }

    // Ensure driver profile exists in drivers table (auto-create if missing)
    const { data: existingDriver } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (!existingDriver) {
      console.log(`[DriverAuth] Auto-creating missing driver profile for user ${user.id}...`);
      await supabase
        .from('drivers')
        .insert([
          {
            user_id: user.id,
            vehicle_type: 'Motor',
            vehicle_name: 'Kendaraan Driver',
            plate_number: 'B 1234 OK',
            price_per_hour: 50000,
            rating: 5.00,
            total_rides: 0,
            is_available: true,
            status: 'approved',
            created_at: new Date(),
            updated_at: new Date()
          }
        ]);
    }

    // Generate token
    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role, full_name: user.full_name },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    const { password_hash: _, ...userWithoutPassword } = user;

    res.status(200).json({
      success: true,
      message: 'Login Mitra berhasil',
      data: {
        user: userWithoutPassword,
        token: token
      }
    });
    
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error: ' + error.message
    });
  }
};

const getMe = async (req, res) => {
  try {
    const { password_hash: _, ...userWithoutPassword } = req.user;
    res.status(200).json({
      success: true,
      data: userWithoutPassword
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

module.exports = {
  register,
  login,
  getMe
};
