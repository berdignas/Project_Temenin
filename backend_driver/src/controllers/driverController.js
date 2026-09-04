const { supabase } = require('../config/supabase');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// Register Driver
const registerDriver = async (req, res) => {
  try {
    const {
      email, password, full_name, phone, gender,
      vehicle_type, vehicle_name, plate_number,
      price_per_hour, experience_years, id_card_number,
      driver_license_number, vehicle_stnk
    } = req.body;

    if (!email || !password || !full_name || !vehicle_type || !vehicle_name || !plate_number) {
      return res.status(400).json({
        success: false,
        message: 'Required fields are missing'
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters'
      });
    }

    const cleanEmail = email.toLowerCase().trim();

    // Check if user exists
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

    // Insert user
    const { data: user, error: userError } = await supabase
      .from('users')
      .insert([
        {
          email: cleanEmail,
          password_hash: password_hash,
          full_name: full_name.trim(),
          phone: phone?.trim() || null,
          gender: gender?.trim() || 'Laki-laki',
          role: 'driver',
          is_verified: true,
          balance: 0,
          points: 0,
          created_at: new Date(),
          updated_at: new Date()
        }
      ])
      .select()
      .single();

    if (userError) {
      return res.status(400).json({
        success: false,
        message: 'Failed to create user: ' + userError.message
      });
    }

    // Insert driver profile
    const { data: driver, error: driverError } = await supabase
      .from('drivers')
      .insert([
        {
          user_id: user.id,
          vehicle_type: vehicle_type,
          vehicle_name: vehicle_name.trim(),
          plate_number: plate_number.toUpperCase().trim(),
          price_per_hour: price_per_hour || 50000,
          rating: 5.0,
          total_rides: 0,
          is_available: true,
          status: 'approved', // Auto-approve for standalone testing
          experience_years: experience_years || 0,
          id_card_number: id_card_number,
          driver_license_number: driver_license_number,
          vehicle_stnk: vehicle_stnk,
          registration_date: new Date(),
          approved_at: new Date()
        }
      ])
      .select()
      .single();

    if (driverError) {
      // Rollback user
      await supabase.from('users').delete().eq('id', user.id);
      return res.status(400).json({
        success: false,
        message: 'Failed to create driver profile: ' + driverError.message
      });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, role: 'driver' },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    const { password_hash: _, ...userWithoutPassword } = user;

    res.status(201).json({
      success: true,
      message: 'Driver registered successfully',
      data: {
        user: userWithoutPassword,
        driver: driver,
        token: token
      }
    });
    
  } catch (error) {
    console.error('Register driver error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error: ' + error.message
    });
  }
};

// Get Driver Profile
const getDriverProfile = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data: driver, error } = await supabase
      .from('drivers')
      .select(`
        *,
        users:user_id (
          full_name,
          email,
          phone,
          avatar_url,
          gender,
          balance,
          points
        )
      `)
      .eq('user_id', userId)
      .maybeSingle();

    if (error || !driver) {
      return res.status(404).json({
        success: false,
        message: 'Driver profile not found'
      });
    }

    res.status(200).json({
      success: true,
      data: driver
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Update Driver Status (Online/Offline)
const updateDriverStatus = async (req, res) => {
  try {
    const { is_available, latitude, longitude } = req.body;
    const userId = req.user.id;

    const { data: driver, error } = await supabase
      .from('drivers')
      .update({
        is_available: is_available,
        latitude: latitude || null,
        longitude: longitude || null,
        updated_at: new Date()
      })
      .eq('user_id', userId)
      .select()
      .single();

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    res.status(200).json({
      success: true,
      message: `Driver status set to ${is_available ? 'Online' : 'Offline'}`,
      data: driver
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Get Driver Bookings
const getDriverBookings = async (req, res) => {
  try {
    const userId = req.user.id;
    const { status } = req.query;

    const { data: driver, error: driverError } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', userId)
      .single();

    if (driverError || !driver) {
      return res.status(404).json({
        success: false,
        message: 'Driver not found'
      });
    }

    let query = supabase
      .from('bookings')
      .select(`
        *,
        users:user_id (
          full_name,
          email,
          phone,
          avatar_url
        )
      `)
      .eq('driver_id', driver.id)
      .order('created_at', { ascending: false });

    if (status && status !== 'all') {
      query = query.eq('status', status);
    }

    const { data: bookings, error } = await query;

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    res.status(200).json({
      success: true,
      data: bookings
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Update Booking Status
const updateBookingStatus = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { status } = req.body;
    const userId = req.user.id;

    // Get driver details including total_rides
    const { data: driver, error: driverError } = await supabase
      .from('drivers')
      .select('id, total_rides')
      .eq('user_id', userId)
      .single();

    if (driverError || !driver) {
      return res.status(404).json({
        success: false,
        message: 'Driver not found'
      });
    }

    // Get current booking data first to check current status and price
    const { data: bookingCheck, error: bookingCheckError } = await supabase
      .from('bookings')
      .select('*')
      .eq('id', bookingId)
      .eq('driver_id', driver.id)
      .single();

    if (bookingCheckError || !bookingCheck) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found or not assigned to this driver'
      });
    }

    // Update booking status
    const { data: booking, error } = await supabase
      .from('bookings')
      .update({
        status: status,
        updated_at: new Date()
      })
      .eq('id', bookingId)
      .eq('driver_id', driver.id)
      .select(`
        *,
        users:user_id (
          id,
          full_name,
          email,
          phone,
          avatar_url,
          role,
          balance,
          points
        )
      `)
      .single();

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    // If status updated to 'completed' and was not previously completed/cancelled
    if (status === 'completed' && bookingCheck.status !== 'completed' && bookingCheck.status !== 'cancelled') {
      try {
        // 1. Increment driver rides count
        await supabase
          .from('drivers')
          .update({
            total_rides: (driver.total_rides || 0) + 1,
            updated_at: new Date()
          })
          .eq('id', driver.id);

        // 2. Fetch current balance
        const { data: userProfile, error: userError } = await supabase
          .from('users')
          .select('balance')
          .eq('id', userId)
          .single();

        if (!userError && userProfile) {
          const newBalance = Number(userProfile.balance || 0) + Number(bookingCheck.total_price || 0);
          
          // 3. Update user balance
          await supabase
            .from('users')
            .update({
              balance: newBalance,
              updated_at: new Date()
            })
            .eq('id', userId);
        }
      } catch (err) {
        console.error('Error updating driver balance/rides:', err);
      }
    }

    res.status(200).json({
      success: true,
      message: 'Booking status updated successfully',
      data: booking
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Get Driver Earnings
const getDriverEarnings = async (req, res) => {
  try {
    const userId = req.user.id;
    const { period } = req.query; // 'daily', 'weekly', 'monthly', 'all'

    const { data: driver, error: driverError } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', userId)
      .single();

    if (driverError || !driver) {
      return res.status(404).json({
        success: false,
        message: 'Driver not found'
      });
    }

    let query = supabase
      .from('bookings')
      .select('total_price, created_at')
      .eq('driver_id', driver.id)
      .eq('status', 'completed');

    const now = new Date();
    if (period === 'daily') {
      const startOfDay = new Date(now.setHours(0, 0, 0, 0)).toISOString();
      query = query.gte('created_at', startOfDay);
    } else if (period === 'weekly') {
      const startOfWeek = new Date(now.setDate(now.getDate() - now.getDay())).toISOString();
      query = query.gte('created_at', startOfWeek);
    } else if (period === 'monthly') {
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
      query = query.gte('created_at', startOfMonth);
    }

    const { data: bookings, error } = await query;

    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }

    const totalEarnings = bookings.reduce((sum, b) => sum + (parseFloat(b.total_price) || 0), 0);
    const totalRides = bookings.length;

    res.status(200).json({
      success: true,
      data: {
        total_earnings: totalEarnings,
        total_rides: totalRides,
        period: period || 'all',
        bookings: bookings
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Update Driver Profile
const updateDriverProfile = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      full_name,
      phone,
      avatar_url,
      gender,
      vehicle_name,
      plate_number,
      price_per_hour,
      experience_years,
      vehicle_stnk // repurposed for storing JSON of social media fields or biography
    } = req.body;

    // Update user details
    const userUpdates = {};
    if (full_name) userUpdates.full_name = full_name.trim();
    if (phone) userUpdates.phone = phone.trim();
    if (avatar_url) userUpdates.avatar_url = avatar_url.trim();
    if (gender) userUpdates.gender = gender.trim();
    userUpdates.updated_at = new Date();

    if (Object.keys(userUpdates).length > 1) {
      const { error: userError } = await supabase
        .from('users')
        .update(userUpdates)
        .eq('id', userId);

      if (userError) {
        return res.status(400).json({
          success: false,
          message: 'Failed to update user table: ' + userError.message
        });
      }
    }

    // Update driver details
    const driverUpdates = {};
    if (vehicle_name) driverUpdates.vehicle_name = vehicle_name.trim();
    if (plate_number) driverUpdates.plate_number = plate_number.toUpperCase().trim();
    if (price_per_hour !== undefined) driverUpdates.price_per_hour = Number(price_per_hour);
    if (experience_years !== undefined) driverUpdates.experience_years = Number(experience_years);
    if (vehicle_stnk) driverUpdates.vehicle_stnk = vehicle_stnk;
    driverUpdates.updated_at = new Date();

    const { data: updatedDriver, error: driverError } = await supabase
      .from('drivers')
      .update(driverUpdates)
      .eq('user_id', userId)
      .select(`
        *,
        users:user_id (
          full_name,
          email,
          phone,
          avatar_url,
          gender,
          balance,
          points
        )
      `)
      .single();

    if (driverError) {
      return res.status(400).json({
        success: false,
        message: 'Failed to update driver profile: ' + driverError.message
      });
    }

    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      data: updatedDriver
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

module.exports = {
  registerDriver,
  getDriverProfile,
  updateDriverStatus,
  getDriverBookings,
  updateBookingStatus,
  getDriverEarnings,
  updateDriverProfile
};
