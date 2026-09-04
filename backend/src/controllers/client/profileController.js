const profileService = require('../../services/client/profileService');
const db = require('../../config/supabase');


class ProfileController {
  /**
   * Get user profile
   */
  async getProfile(req, res) {
    try {
      const userId = req.user.id; // From auth middleware
      const profile = await profileService.getUserProfile(userId);
      
      res.status(200).json({
        success: true,
        message: 'Profile retrieved successfully',
        data: profile
      });
    } catch (error) {
      console.error('Get profile error:', error);
      res.status(400).json({
        success: false,
        message: error.message || 'Failed to get profile'
      });
    }
  }

  // backend/src/controllers/client/profileController.js

async updateProfile(req, res) {
  try {
    const userId = req.user.id;
    
    // 🔴 PERBAIKI: Ambil data dari body (untuk JSON) atau fields (untuk multipart)
    let full_name = req.body.full_name;
    let phone = req.body.phone;
    
    // Jika dari multipart, cek juga di req.fields
    if (!full_name && req.fields) {
      full_name = req.fields.full_name;
    }
    if (!phone && req.fields) {
      phone = req.fields.phone;
    }
    
    console.log('📥 Update profile request:', { userId, full_name, phone });
    
    // Validasi
    if (!full_name && !phone) {
      return res.status(400).json({
        success: false,
        message: 'At least one field (full_name or phone) is required'
      });
    }
    
    const updatedProfile = await profileService.updateUserProfile(userId, {
      full_name,
      phone
    });
    
    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      data: updatedProfile
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(400).json({
      success: false,
      message: error.message || 'Failed to update profile'
    });
  }
}

  /**
   * Upload avatar
   */
  async uploadAvatar(req, res) {
    try {
      const userId = req.user.id;
      
      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: 'No image file uploaded'
        });
      }
      
      const updatedUser = await profileService.updateAvatar(userId, req.file);
      
      res.status(200).json({
        success: true,
        message: 'Avatar uploaded successfully',
        data: updatedUser
      });
    } catch (error) {
      console.error('Upload avatar error:', error);
      res.status(400).json({
        success: false,
        message: error.message || 'Failed to upload avatar'
      });
    }
  }

  /**
   * Delete avatar
   */
  async deleteAvatar(req, res) {
    try {
      const userId = req.user.id;
      const updatedUser = await profileService.deleteAvatar(userId);
      
      res.status(200).json({
        success: true,
        message: 'Avatar deleted successfully',
        data: updatedUser
      });
    } catch (error) {
      console.error('Delete avatar error:', error);
      res.status(400).json({
        success: false,
        message: error.message || 'Failed to delete avatar'
      });
    }
  }

  /**
   * Change password
   */
  async changePassword(req, res) {
    try {
      const userId = req.user.id;
      const { old_password, new_password } = req.body;
      
      if (!old_password || !new_password) {
        return res.status(400).json({
          success: false,
          message: 'Old password and new password are required'
        });
      }
      
      if (new_password.length < 6) {
        return res.status(400).json({
          success: false,
          message: 'New password must be at least 6 characters'
        });
      }
      
      const result = await profileService.changePassword(userId, old_password, new_password);
      
      res.status(200).json({
        success: true,
        message: result.message
      });
    } catch (error) {
      console.error('Change password error:', error);
      res.status(400).json({
        success: false,
        message: error.message || 'Failed to change password'
      });
    }
  }

  /**
   * Get booking history
   */
  async getBookingHistory(req, res) {
    try {
      const userId = req.user.id;
      const { status } = req.query;
      
      const history = await profileService.getBookingHistory(userId, status);
      
      res.status(200).json({
        success: true,
        message: 'Booking history retrieved successfully',
        data: history
      });
    } catch (error) {
      console.error('Get booking history error:', error);
      res.status(400).json({
        success: false,
        message: error.message || 'Failed to get booking history'
      });
    }
  }

  /**
   * Deduct user points
   */
  async deductPoints(req, res) {
    try {
      const userId = req.user.id;
      const { points } = req.body;

      if (points === undefined || points === null || points <= 0) {
        return res.status(400).json({
          success: false,
          message: 'Jumlah poin yang dipotong harus lebih besar dari 0'
        });
      }

      const updatedUser = await profileService.deductPoints(userId, parseInt(points));

      res.status(200).json({
        success: true,
        message: 'Poin berhasil dipotong',
        data: updatedUser
      });
    } catch (error) {
      console.error('Deduct points error:', error);
      res.status(400).json({
        success: false,
        message: error.message || 'Gagal memotong poin'
      });
    }
  }
}

module.exports = new ProfileController();