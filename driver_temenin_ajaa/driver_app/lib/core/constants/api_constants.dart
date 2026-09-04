class ApiConstants {
  // Use http://localhost:3001 for Android Emulator / Physical Device (via adb reverse), iOS / Web / desktop
  // Menggunakan IP lokal komputer agar HP (Infinix) bisa terhubung ke backend Node.js (port 3004)
  static const String baseUrl = 'http://192.168.1.4:3004'; 
  
  // Auth Endpoints
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String getMe = '/api/auth/me';
  
  // Driver Endpoints
  static const String profile = '/api/drivers/profile';
  static const String status = '/api/drivers/status';
  static const String bookings = '/api/drivers/bookings';
  static const String earnings = '/api/drivers/earnings';
}
