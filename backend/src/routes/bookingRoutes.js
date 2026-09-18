const express = require('express');
const router = express.Router();
const {
  createBooking,
  getClientBookings,
  getOpenBookings,
  placeNegotiation,
  getBookingNegotiations,
  acceptNegotiation,
  updateBookingStatus,
  createBookingReview,
  getBookingReviews,
  sendChatMessage,
  getChatMessages
} = require('../controllers/bookingController');
const { getPublicPricingConfig } = require('../controllers/settingsController');
const { protect } = require('../middleware/authMiddleware');

// Public pricing configuration for Client and Driver apps
router.get('/pricing-config', getPublicPricingConfig);

router.use(protect);

// Booking Creation & Retrieval
router.route('/')
  .post(createBooking)            // Client requests booking
  .get(getClientBookings);         // Client checks their booking requests

// Driver Open Bookings Board
router.get('/open', getOpenBookings); // Drivers browse pending client requests

// Negotiation Interactions
router.route('/:bookingId/negotiations')
  .post(placeNegotiation)                 // Driver submits a counter-offer / negotiation price
  .get(getBookingNegotiations);           // Client (and Drivers) view all negotiations

// Negotiation Acceptance & Status Lifecycle
router.post('/:bookingId/negotiations/:negotiationId/accept', acceptNegotiation); // Client accepts a driver's negotiation price
router.put('/:bookingId/status', updateBookingStatus);                           // Client/Driver updates ongoing status
router.patch('/:bookingId/status', updateBookingStatus);

// Reviews & Ratings
router.route('/:bookingId/reviews')
  .post(createBookingReview)
  .get(getBookingReviews);

// Chat messages
router.route('/:bookingId/messages')
  .post(sendChatMessage)
  .get(getChatMessages);

module.exports = router;
