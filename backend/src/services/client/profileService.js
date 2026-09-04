const { supabase, supabaseAdmin } = require('../../config/supabase');
const fs = require('fs').promises;
const path = require('path');
const sharp = require('sharp');

class ProfileService {
  /**
   * Get user profile by ID
   */
  async getUserProfile(userId) {
    try {
      const { data: user, error: userError } = await supabase
        .from('users')
        .select('id, email, full_name, phone, avatar_url, balance, points, is_verified, created_at, updated_at')
        .eq('id', userId)
        .maybeSingle();
      
      if (userError) throw userError;
      if (!user) {
        throw new Error('User not found');
      }
      
      // Get user statistics
      const { data: bookings, error: bookingsError } = await supabase
        .from('bookings')
        .select('status')
        .eq('user_id', userId);
      
      if (bookingsError) throw bookingsError;
      
      const total_bookings = bookings ? bookings.length : 0;
      const ongoing_bookings = bookings ? bookings.filter(b => b.status === 'ongoing').length : 0;
      const completed_bookings = bookings ? bookings.filter(b => b.status === 'completed').length : 0;
      
      return {
        ...user,
        stats: {
          total_bookings,
          ongoing_bookings,
          completed_bookings
        }
      };
    } catch (error) {
      throw error;
    }
  }

  /**
   * Update user profile
   */
  async updateUserProfile(userId, updateData) {
    try {
      const { full_name, phone } = updateData;
      const updateObj = {};

      if (full_name !== undefined && full_name !== null && full_name !== '') {
        updateObj.full_name = full_name;
        console.log('📝 Updating full_name:', full_name);
      }
      
      if (phone !== undefined && phone !== null && phone !== '') {
        updateObj.phone = phone;
        console.log('📱 Updating phone:', phone);
      }

      if (Object.keys(updateObj).length === 0) {
        console.log('⚠️ No fields to update, returning current user');
        const { data: currentUser, error: getError } = await supabase
          .from('users')
          .select('id, email, full_name, phone, avatar_url, balance, points, is_verified')
          .eq('id', userId)
          .maybeSingle();
        if (getError) throw getError;
        if (!currentUser) {
          throw new Error('User not found');
        }
        return currentUser;
      }

      updateObj.updated_at = new Date();

      const { data: updatedUser, error: updateError } = await supabase
        .from('users')
        .update(updateObj)
        .eq('id', userId)
        .select('id, email, full_name, phone, avatar_url, balance, points, is_verified')
        .single();
      
      if (updateError) throw updateError;
      return updatedUser;
    } catch (error) {
      console.error('Update profile error:', error);
      throw error;
    }
  }

  /**
   * Update avatar
   */
  async updateAvatar(userId, file) {
    try {
      console.log('🖼️ Starting avatar upload for user:', userId);
      
      if (!file) {
        throw new Error('No file uploaded');
      }

      // Get current user data to delete old avatar
      const { data: currentUser, error: getError } = await supabase
        .from('users')
        .select('avatar_url')
        .eq('id', userId)
        .maybeSingle();

      if (getError) throw getError;
      if (!currentUser) {
        throw new Error('User not found');
      }

      // Pastikan direktori uploads/avatars ada
      const uploadDir = path.join(__dirname, '../../../uploads/avatars');
      try {
        await fs.access(uploadDir);
      } catch (error) {
        console.log('📁 Creating uploads directory...');
        await fs.mkdir(uploadDir, { recursive: true });
      }

      // Process image with Sharp
      const processedFilename = `avatar-${Date.now()}-${userId}.webp`;
      const processedPath = path.join(uploadDir, processedFilename);
      
      await sharp(file.path)
        .resize(400, 400, {
          fit: 'cover',
          position: 'center'
        })
        .webp({ quality: 80 })
        .toFile(processedPath);

      // Delete old avatar file
      const oldAvatarUrl = currentUser.avatar_url;
      if (oldAvatarUrl) {
        const oldFilename = oldAvatarUrl.split('/').pop();
        const oldPath = path.join(uploadDir, oldFilename);
        try {
          await fs.unlink(oldPath);
        } catch (err) {
          console.log('Old avatar not found:', err.message);
        }
      }

      // Delete temporary file
      await fs.unlink(file.path);

      // Buat URL relatif
      const avatarUrl = `/uploads/avatars/${processedFilename}`;
      
      console.log('📸 Avatar URL:', avatarUrl);

      // Update database
      const { data: updatedUser, error: updateError } = await supabase
        .from('users')
        .update({ avatar_url: avatarUrl, updated_at: new Date() })
        .eq('id', userId)
        .select('id, email, full_name, avatar_url')
        .single();

      if (updateError) throw updateError;
      return updatedUser;
    } catch (error) {
      if (file && file.path) {
        try {
          await fs.unlink(file.path);
        } catch (err) {
          console.log('Error deleting temp file:', err.message);
        }
      }
      throw error;
    }
  }

  /**
   * Delete avatar
   */
  async deleteAvatar(userId) {
    try {
      // Get current user data
      const { data: currentUser, error: getError } = await supabase
        .from('users')
        .select('avatar_url')
        .eq('id', userId)
        .maybeSingle();

      if (getError) throw getError;
      if (!currentUser) {
        throw new Error('User not found');
      }

      const avatarUrl = currentUser.avatar_url;
      if (avatarUrl) {
        // Delete file from filesystem using absolute path
        const filename = avatarUrl.split('/').pop();
        const filePath = path.join(__dirname, '../../../uploads/avatars', filename);
        try {
          await fs.unlink(filePath);
        } catch (err) {
          console.log('Avatar file not found:', err.message);
        }
      }

      // Update database
      const { data: updatedUser, error: updateError } = await supabase
        .from('users')
        .update({ avatar_url: null, updated_at: new Date() })
        .eq('id', userId)
        .select('id, email, full_name, avatar_url')
        .single();

      if (updateError) throw updateError;
      return updatedUser;
    } catch (error) {
      throw error;
    }
  }

  /**
   * Change password
   */
  async changePassword(userId, oldPassword, newPassword) {
    try {
      const bcrypt = require('bcryptjs');
      
      // Get current user with password
      const { data: user, error: getError } = await supabase
        .from('users')
        .select('password_hash')
        .eq('id', userId)
        .maybeSingle();

      if (getError) throw getError;
      if (!user) {
        throw new Error('User not found');
      }

      // Verify old password
      const isValid = await bcrypt.compare(oldPassword, user.password_hash);
      if (!isValid) {
        throw new Error('Current password is incorrect');
      }

      // Hash new password
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(newPassword, salt);

      // Update password
      const { error: updateError } = await supabase
        .from('users')
        .update({ password_hash: hashedPassword, updated_at: new Date() })
        .eq('id', userId);

      if (updateError) throw updateError;

      return { message: 'Password updated successfully' };
    } catch (error) {
      throw error;
    }
  }

  /**
   * Get booking history
   */
  async getBookingHistory(userId, status = null) {
    try {
      let queryBuilder = supabase
        .from('bookings')
        .select(`
          *,
          drivers (
            id,
            vehicle_name,
            vehicle_type,
            plate_number,
            price_per_hour,
            rating
          )
        `)
        .eq('user_id', userId);
      
      if (status) {
        queryBuilder = queryBuilder.eq('status', status);
      }
      
      const { data: bookings, error: bookingsError } = await queryBuilder.order('created_at', { ascending: false });
      
      if (bookingsError) throw bookingsError;
      
      // Flat-map drivers properties to maintain backward compatibility with old join structure,
      // and also add nested 'driver' object for BookingModel compatibility in Flutter Client.
      return bookings.map(b => {
        const { drivers, ...bookingData } = b;
        return {
          ...bookingData,
          vehicle_name: drivers?.vehicle_name || null,
          vehicle_type: drivers?.vehicle_type || null,
          plate_number: drivers?.plate_number || null,
          price_per_hour: drivers?.price_per_hour || null,
          driver: drivers ? {
            id: drivers.id,
            vehicle_name: drivers.vehicle_name,
            vehicle_type: drivers.vehicle_type,
            plate_number: drivers.plate_number,
            price_per_hour: drivers.price_per_hour,
            rating: drivers.rating ? parseFloat(drivers.rating) : 5.0
          } : null
        };
      });
    } catch (error) {
      console.error('Error fetching booking history:', error);
      throw error;
    }
  }
  /**
   * Deduct points from user
   */
  async deductPoints(userId, pointsToDeduct) {
    try {
      const { data: user, error: getError } = await supabase
        .from('users')
        .select('points')
        .eq('id', userId)
        .maybeSingle();

      if (getError) throw getError;
      if (!user) {
        throw new Error('User not found');
      }

      if (user.points < pointsToDeduct) {
        throw new Error('Poin tidak mencukupi');
      }

      const { data: updatedUser, error: updateError } = await supabase
        .from('users')
        .update({ points: user.points - pointsToDeduct, updated_at: new Date() })
        .eq('id', userId)
        .select('id, email, full_name, points')
        .single();

      if (updateError) throw updateError;
      return updatedUser;
    } catch (error) {
      throw error;
    }
  }
}

module.exports = new ProfileService();