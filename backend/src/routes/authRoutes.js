const express = require('express');
const router = express.Router();
const { 
  register, 
  login, 
  getMe, 
  updateProfile,
  sendOtp,
  verifyOtp,
  registerWithOtp,
  loginWithOtp,
  setupAccount
} = require('../controllers/authController');
const { protect } = require('../middleware/authMiddleware');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Konfigurasi Multer untuk upload foto profil
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadPath = path.join(__dirname, '../../uploads');
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'profile-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 } // limit 5MB
});

// === ALUR BARU: Registrasi dengan OTP ===
router.post('/send-otp', sendOtp);
router.post('/verify-otp', verifyOtp);
// Registrasi: nomor HP + nama + foto profil
router.post('/register-otp', upload.single('profile_picture'), registerWithOtp);
router.post('/login-otp', loginWithOtp);
router.post('/setup-account', protect, setupAccount);

// === ALUR LAMA (Email/Password fallback jika masih dipakai Admin dsb) ===
router.post('/register', register);
router.post('/login', login);
router.get('/me', protect, getMe);
router.put('/profile', protect, updateProfile);

module.exports = router;