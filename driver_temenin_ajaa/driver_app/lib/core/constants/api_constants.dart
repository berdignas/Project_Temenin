import 'package:flutter/foundation.dart';

class ApiConstants {
  // Use http://localhost:3001 for Android Emulator / Physical Device (via adb reverse), iOS / Web / desktop
  // Menggunakan host browser secara dinamis agar otomatis jalan di HP atau laptop di WiFi mana pun
  static String get baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.isEmpty ? '127.0.0.1' : Uri.base.host;
      return 'http://$host:3004';
    }
    return 'http://10.187.2.129:3004';
  } 
  
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
