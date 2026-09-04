const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Ensure upload directory exists
const uploadDir = 'uploads/avatars';
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Configure storage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    // 🔴 PERBAIKI: Dapatkan ekstensi dari originalname atau mimetype
    let ext = path.extname(file.originalname);
    if (!ext && file.mimetype) {
      // Jika tidak ada ekstensi, buat dari mimetype
      const mimeToExt = {
        'image/jpeg': '.jpg',
        'image/jpg': '.jpg',
        'image/png': '.png',
        'image/gif': '.gif',
        'image/webp': '.webp'
      };
      ext = mimeToExt[file.mimetype] || '.jpg';
    }
    cb(null, 'avatar-' + uniqueSuffix + ext);
  }
});

// 🔴 PERBAIKI: File filter yang lebih fleksibel
const fileFilter = (req, file, cb) => {
  // Log untuk debug
  console.log('📁 Received file:', {
    originalname: file.originalname,
    mimetype: file.mimetype,
    size: file.size
  });
  
  // Izinkan semua file yang memiliki mimetype image
  const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
  const isAllowedMime = allowedMimeTypes.includes(file.mimetype);
  
  // Juga cek ekstensi file
  const ext = path.extname(file.originalname).toLowerCase();
  const allowedExt = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  const isAllowedExt = allowedExt.includes(ext);
  
  if (isAllowedMime || isAllowedExt) {
    console.log('✅ File accepted');
    return cb(null, true);
  } else {
    console.log('❌ File rejected:', file.mimetype, ext);
    cb(new Error('Only image files are allowed (jpeg, jpg, png, gif, webp)'));
  }
};

const upload = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 🔴 Naikkan limit ke 10MB
  fileFilter: fileFilter
});

module.exports = upload;