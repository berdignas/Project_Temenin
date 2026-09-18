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
  createBooking,
  updateBooking,
  deleteBooking,
  updateBookingStatus,
  topUpUserBalance,
  getTransactions,
  approveTransaction,
  settlePelunasanSplit,
  disbursePayout,
  rejectTransaction,
  executeDpForfeit,
  deleteTransaction,
  getCommunityPosts,
  deleteCommunityPost,
  getEvents,
  createEvent,
  updateEvent,
  deleteEvent
} = require('../controllers/adminController');
const { getSettings, updateSettings } = require('../controllers/settingsController');
const { protect, requireRole } = require('../middleware/authMiddleware');

// Protect all admin routes
router.use(protect);
router.use(requireRole(['admin']));

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
router.post('/bookings', createBooking);
router.put('/bookings/:id', updateBooking);
router.delete('/bookings/:id', deleteBooking);
router.put('/bookings/:id/status', updateBookingStatus);

// Finance & Transaction Management CMS
router.post('/topup', topUpUserBalance);
router.get('/finance/transactions', getTransactions);
router.post('/finance/transactions/:id/approve', approveTransaction);
router.post('/finance/transactions/:id/settle', settlePelunasanSplit);
router.post('/finance/transactions/:id/disburse', disbursePayout);
router.post('/finance/transactions/:id/reject', rejectTransaction);
router.post('/finance/transactions/:id/forfeit', executeDpForfeit);
router.delete('/finance/transactions/:id', deleteTransaction);

// Community Content Moderation
router.get('/community/posts', getCommunityPosts);
router.delete('/community/posts/:id', deleteCommunityPost);

// Event Terdekat Management
router.get('/events', getEvents);
router.post('/events', createEvent);
router.put('/events/:id', updateEvent);
router.delete('/events/:id', deleteEvent);

// Platform System & Pricing Settings
router.get('/settings', getSettings);
router.put('/settings', updateSettings);

module.exports = router;
