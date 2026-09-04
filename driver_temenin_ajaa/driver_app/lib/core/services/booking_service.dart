import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/models/booking_model.dart';
import '../constants/api_constants.dart';
import 'auth_service.dart';

class BookingService {
  final AuthService _authService = AuthService();

  // Fetch driver bookings
  Future<Map<String, dynamic>> getDriverBookings({String status = 'all'}) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Belum login', 'bookings': <BookingModel>[]};
      }

      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bookings}?status=$status');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> list = data['data'] ?? data['bookings'] ?? [];
        final bookings = list.map((json) => BookingModel.fromJson(json)).toList();
        return {'success': true, 'bookings': bookings};
      }
      return {'success': true, 'bookings': <BookingModel>[]};
    } catch (e) {
      return {'success': true, 'bookings': <BookingModel>[]};
    }
  }

  // Update booking status
  Future<Map<String, dynamic>> updateBookingStatus(String bookingId, String status) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Belum login'};
      }

      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bookings}/$bookingId/status');
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Status berhasil diperbarui',
          'booking': data['data'] != null ? BookingModel.fromJson(data['data']) : null,
        };
      }
      return {'success': false, 'message': 'Gagal memperbarui status'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fetch driver earnings
  Future<Map<String, dynamic>> getDriverEarnings(String period) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {
          'success': true,
          'totalEarnings': 0.0,
          'totalRides': 0,
          'bookings': [],
        };
      }

      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.earnings}?period=$period');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'totalEarnings': (data['totalEarnings'] ?? 0).toDouble(),
          'totalRides': data['totalRides'] ?? 0,
          'bookings': data['bookings'] ?? [],
        };
      }
      return {
        'success': true,
        'totalEarnings': 0.0,
        'totalRides': 0,
        'bookings': [],
      };
    } catch (e) {
      return {
        'success': true,
        'totalEarnings': 0.0,
        'totalRides': 0,
        'bookings': [],
      };
    }
  }

  // Place a negotiation / counter-offer on a booking
  Future<Map<String, dynamic>> placeNegotiation(String bookingId, double negotiatedPrice, String notes) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Belum login'};
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/api/bookings/$bookingId/negotiations');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'negotiated_price': negotiatedPrice,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      final data = jsonDecode(response.body);
      return {'success': false, 'message': data['message'] ?? 'Gagal mengajukan negosiasi'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
