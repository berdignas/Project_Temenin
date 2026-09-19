import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.isEmpty ? '127.0.0.1' : Uri.base.host;
      return 'http://$host:3002';
    }
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    final dotenvUrl = dotenv.env['API_BASE_URL'];
    if (dotenvUrl != null && dotenvUrl.isNotEmpty) return dotenvUrl;
    return 'http://192.168.1.4:3002';
  }

  // Auth Endpoints
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String getMe = '/api/auth/me';
  static const String updateProfile = '/api/auth/profile';
  static const String changePassword = '/api/profile/change-password';
  static const String sendOtp = '/api/auth/send-otp';
  static const String verifyOtp = '/api/auth/verify-otp';
  static const String registerOtp = '/api/auth/register-otp';
  static const String loginOtp = '/api/auth/login-otp';
  static const String setupAccount = '/api/auth/setup-account';
  
  // User & Profile Endpoints
  static const String profile = '/api/profile/profile';
  static const String avatar = '/api/profile/avatar';
  static const String bookings = '/api/bookings';

  // Driver Endpoints
  static const String drivers = '/api/drivers';
  
  // Booking Endpoints
  static const String createBooking = '/api/bookings';
  static const String openBookings = '/api/bookings/open';
  static const String myBookings = '/api/bookings';
  
  // Payment Endpoints
  static const String payments = '/api/payments';
  static const String paymentMethods = '/api/payments/methods';
  static const String processPayment = '/api/payments/pay';
  static const String paymentHistory = '/api/payments/history';
  
  // Community Endpoints
  static const String stories = '/api/community/stories';
  static const String posts = '/api/community/posts';

  static String get driverRegister => '$baseUrl/api/drivers/register';
  static String get driverProfile => '$baseUrl/api/drivers/profile';
  static String get driverStatus => '$baseUrl/api/drivers/status';
  static String get driverBookings => '$baseUrl/api/drivers/bookings';
  static String get driverEarnings => '$baseUrl/api/drivers/earnings';
  
  // Headers
  static const String contentType = 'application/json';
  
  // Helper method untuk mendapatkan full URL
  static String getFullUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
}