// backend/src/routes/client/paymentRoutes.js
const express = require('express');
const router = express.Router();
const paymentController = require('../../controllers/client/paymentController');
const { protect } = require('../../middleware/authMiddleware');

// Public Webhook Route (Called by Xendit Server without Bearer Token)
router.post('/xendit-webhook', paymentController.handleXenditWebhook);

// Protect all following client routes
router.use(protect);

// Payment method routes
router.get('/methods', paymentController.getPaymentMethods);
router.post('/methods', paymentController.addPaymentMethod);
router.delete('/methods/:methodId', paymentController.removePaymentMethod);
router.put('/methods/:methodId/default', paymentController.setDefaultPaymentMethod);

// 🛡️ Middleware: Larang akses endpoint simulasi pembayaran di lingkungan produksi untuk non-admin
const allowSandboxSimulationOnly = (req, res, next) => {
  const isDev = process.env.NODE_ENV === 'development' || process.env.NODE_ENV === 'test';
  const isAdmin = req.user && req.user.role === 'admin';

  if (!isDev && !isAdmin) {
    return res.status(403).json({
      success: false,
      message: 'Akses ditolak. Endpoint simulasi pembayaran sandbox dinonaktifkan di lingkungan produksi untuk pengguna non-admin.'
    });
  }
  next();
};

// Payment processing & Wallet routes
router.post('/pay', paymentController.processPayment);
router.post('/qris', paymentController.createQrisPayment);
router.post('/simulate-qris-paid', allowSandboxSimulationOnly, paymentController.simulateQrisPaid);
router.post('/manual-submit', paymentController.submitManualPayment);
router.post('/manual-topup', paymentController.submitManualTopup);
router.get('/pending', paymentController.getPendingPayments);
router.get('/history', paymentController.getWalletHistory);

module.exports = router;
