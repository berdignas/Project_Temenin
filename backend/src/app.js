const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

// Import routes
const authRoutes = require('./routes/authRoutes');
const profileRoutes = require('./routes/client/profileRoutes');
const driverRoutes = require('./routes/driver/driverRoutes');
const paymentRoutes = require('./routes/client/paymentRoutes');
const communityRoutes = require('./routes/communityRoutes');
const bookingRoutes = require('./routes/bookingRoutes');
const adminRoutes = require('./routes/adminRoutes');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 🔴 PERBAIKI: Path ke folder uploads yang di luar src
// Dari src/app.js ke folder uploads di root: ../../
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
console.log('📁 Serving static files from:', path.join(__dirname, '../uploads'));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/drivers', driverRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/community', communityRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/admin', adminRoutes);

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'Server is running',
    timestamp: new Date()
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: 'Something went wrong!',
    error: process.env.NODE_ENV === 'development' ? err.message : {}
  });
});

module.exports = app;