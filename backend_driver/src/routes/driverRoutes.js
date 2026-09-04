const express = require('express');
const router = express.Router();
const {
  registerDriver,
  getDriverProfile,
  updateDriverStatus,
  getDriverBookings,
  updateBookingStatus,
  getDriverEarnings,
  updateDriverProfile
} = require('../controllers/driverController');
const { protect } = require('../middleware/authMiddleware');

// Public route for driver registration
router.post('/register', registerDriver);

// Protected routes (driver only)
router.get('/profile', protect, getDriverProfile);
router.put('/profile', protect, updateDriverProfile);
router.put('/status', protect, updateDriverStatus);
router.get('/bookings', protect, getDriverBookings);
router.put('/bookings/:bookingId/status', protect, updateBookingStatus);
router.get('/earnings', protect, getDriverEarnings);

module.exports = router;
