const express = require('express');
const router = express.Router();
const profileController = require('../../controllers/client/profileController');
const upload = require('../../middleware/upload');
const { protect } = require('../../middleware/authMiddleware');
const db = require('../../config/supabase');

router.use(protect);

// Profile routes
router.get('/profile', profileController.getProfile);
router.put('/profile', profileController.updateProfile);

// Avatar routes
router.post('/avatar', upload.single('avatar'), profileController.uploadAvatar);
router.delete('/avatar', profileController.deleteAvatar);

// Password route
router.put('/change-password', profileController.changePassword);

// Booking history
router.get('/bookings', profileController.getBookingHistory);

// Deduct points route
router.put('/points/deduct', profileController.deductPoints);

module.exports = router;