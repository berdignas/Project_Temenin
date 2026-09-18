// routes/driverRoutes.js
const express = require('express');
const router = express.Router();
const {
  registerDriver,
  getDriverProfile,
  updateDriverStatus,
  getDriverBookings,
  updateBookingStatus,
  getDriverEarnings,
  getAllDrivers,
  getDriverSchedules,
  addManualSchedule,
  deleteManualSchedule,
  updateBufferTime,
  updateDriverProfile,
  requestWithdrawal,
  getWithdrawalHistory
} = require('../../controllers/driver/driverController');
const { protect, optionalProtect } = require('../../middleware/authMiddleware');

// Public routes
router.post('/register', registerDriver);

// Client-facing endpoint to get all drivers
router.get('/', optionalProtect, getAllDrivers);

// Public / Client endpoint to fetch a driver's locked schedule slots
router.get('/:id/schedules', optionalProtect, getDriverSchedules);

// Protected routes (hanya untuk driver)
router.get('/profile', protect, getDriverProfile);
router.put('/profile', protect, updateDriverProfile);
router.put('/status', protect, updateDriverStatus);
router.get('/bookings', protect, getDriverBookings);
router.put('/bookings/:bookingId/status', protect, updateBookingStatus);
router.patch('/bookings/:bookingId/status', protect, updateBookingStatus);
router.get('/earnings', protect, getDriverEarnings);

// Driver Withdrawal routes
router.post('/withdraw', protect, requestWithdrawal);
router.get('/withdrawals', protect, getWithdrawalHistory);

// Driver Schedule & Buffer Management
router.get('/schedule/my', protect, getDriverSchedules);
router.post('/schedule/manual', protect, addManualSchedule);
router.delete('/schedule/:scheduleId', protect, deleteManualSchedule);
router.put('/buffer-time', protect, updateBufferTime);

module.exports = router;