// backend/src/routes/client/paymentRoutes.js
const express = require('express');
const router = express.Router();
const paymentController = require('../../controllers/client/paymentController');
const { protect } = require('../../middleware/authMiddleware');

// Protect all routes
router.use(protect);

// Payment method routes
router.get('/methods', paymentController.getPaymentMethods);
router.post('/methods', paymentController.addPaymentMethod);
router.delete('/methods/:methodId', paymentController.removePaymentMethod);
router.put('/methods/:methodId/default', paymentController.setDefaultPaymentMethod);

module.exports = router;
