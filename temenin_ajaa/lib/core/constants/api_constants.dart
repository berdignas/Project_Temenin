// Path: constants\api_constants.dart
class ApiConstants {
  static const String baseUrl = 'http://192.168.1.4:3002'; // Updated to physical PC IP for physical device testing

  
  // Auth Endpoints
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String getMe = '/api/auth/me';
  static const String updateProfile = '/api/auth/profile';
  static const String googleLogin = '/api/auth/google';
  static const String refreshToken = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String changePassword = '/api/profile/change-password';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';
  static const String verifyEmail = '/api/auth/verify-email';
  
  // User Endpoints
  static const String getUserById = '/api/users';
  static const String deleteAccount = '/api/users/account';
  static const String updateAvatar = '/api/users/avatar';
  

  static const String profile = '/api/profile/profile';
  static const String avatar = '/api/profile/avatar';
  static const String bookings = '/api/profile/bookings';

  // Driver Endpoints
  static const String drivers = '/api/drivers';
  static const String nearbyDrivers = '/api/drivers/nearby';
  static const String driverDetail = '/api/drivers/detail';
  static const String driverAvailability = '/api/drivers/availability';
  static const String updateDriverLocation = '/api/drivers/location';
  
  // Booking Endpoints
  static const String createBooking = '/api/bookings/create';
  static const String myBookings = '/api/bookings/my-bookings';
  static const String bookingDetail = '/api/bookings/detail';
  static const String cancelBooking = '/api/bookings/cancel';
  static const String confirmBooking = '/api/bookings/confirm';
  static const String completeBooking = '/api/bookings/complete';
  static const String ongoingBooking = '/api/bookings/ongoing';
  
  // Chat Endpoints
  static const String chats = '/api/chats';
  static const String sendMessage = '/api/chats/send';
  static const String getMessages = '/api/chats/messages';
  static const String markAsRead = '/api/chats/mark-read';
  static const String getChatHistory = '/api/chats/history';
  
  // Review Endpoints
  static const String reviews = '/api/reviews';
  static const String createReview = '/api/reviews/create';
  static const String driverReviews = '/api/reviews/driver';
  static const String userReviews = '/api/reviews/user';
  
  // Payment Endpoints
  static const String payments = '/api/payments';
  static const String createPayment = '/api/payments/create';
  static const String paymentStatus = '/api/payments/status';
  static const String topUpBalance = '/api/payments/topup';
  static const String paymentHistory = '/api/payments/history';
  
  // Location Endpoints
  static const String searchLocation = '/api/location/search';
  static const String reverseGeocode = '/api/location/reverse';
  static const String getPlaces = '/api/location/places';
  static const String calculateDistance = '/api/location/distance';
  
  // Notification Endpoints
  static const String notifications = '/api/notifications';
  static const String markNotificationRead = '/api/notifications/mark-read';
  static const String deleteNotification = '/api/notifications/delete';
  static const String notificationSettings = '/api/notifications/settings';

  static const String driverRegister = '$baseUrl/api/drivers/register';
  static const String driverProfile = '$baseUrl/api/drivers/profile';
  static const String driverStatus = '$baseUrl/api/drivers/status';
  static const String driverBookings = '$baseUrl/api/drivers/bookings';
  static const String driverEarnings = '$baseUrl/api/drivers/earnings';
  
  // Headers
  static const String contentType = 'application/json';
  
  // Helper method untuk mendapatkan full URL
  static String getFullUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
  
  // Helper method untuk debugging
  static void logEndpoint(String endpointName, String endpoint) {
  }
}