// lib/core/services/booking_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temenin_ajaa/core/constants/api_constants.dart';
import '../../../data/models/booking_model.dart';

const String BASE_URL = ApiConstants.baseUrl;

class BookingService {
  Future<Map<String, dynamic>> getBookingHistory(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      print('📖 GET BOOKING HISTORY');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }
      
      final response = await http.get(
        Uri.parse('$BASE_URL/api/profile/bookings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> bookingsJson = data['data'] ?? [];
        List<BookingModel> bookings = bookingsJson
            .map((json) => BookingModel.fromJson(json))
            .toList();
        
        return {
          'success': true,
          'bookings': bookings,
        };
      } else {
        try {
          final data = json.decode(response.body);
          return {
            'success': false,
            'message': data['message'] ?? 'Gagal memuat riwayat booking dari server',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Gagal memuat riwayat booking dari server',
          };
        }
      }
    } catch (e) {
      print('❌ Get booking history error: $e');
      return {
        'success': false,
        'message': 'Gagal menghubungkan ke server: $e',
      };
    }
  }
}