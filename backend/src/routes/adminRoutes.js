const express = require('express');
const router = express.Router();
const {
  getDashboardStats,
  getUsers,
  updateUser,
  deleteUser,
  getDrivers,
  verifyDriverStatus,
  updateDriver,
  getBookings,
  updateBookingStatus,
  topUpUserBalance,
  getCommunityPosts,
  deleteCommunityPost
} = require('../controllers/adminController');

// Admin Dashboard & Stats
router.get('/stats', getDashboardStats);

// User/Client Management
router.get('/users', getUsers);
router.put('/users/:id', updateUser);
router.delete('/users/:id', deleteUser);

// Driver/Mitra Management & Approvals
router.get('/drivers', getDrivers);
router.put('/drivers/:id/verify', verifyDriverStatus);
router.put('/drivers/:id', updateDriver);

// Booking Management
router.get('/bookings', getBookings);
router.put('/bookings/:id/status', updateBookingStatus);

// Finance & Top-Up
router.post('/topup', topUpUserBalance);

// Community Content Moderation
router.get('/community/posts', getCommunityPosts);
router.delete('/community/posts/:id', deleteCommunityPost);

module.exports = router;
