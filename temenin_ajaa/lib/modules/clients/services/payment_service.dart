// lib/services/payment_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temenin_ajaa/core/constants/api_constants.dart';
import 'package:temenin_ajaa/modules/clients/pages/payment_methods_page.dart';


String get BASE_URL => ApiConstants.baseUrl;

class PaymentService {
  Future<Map<String, dynamic>> getPaymentMethods(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }
      
      final response = await http.get(
        Uri.parse('$BASE_URL/api/payments/methods'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      print('📡 Payment methods response: ${response.statusCode}');
      print('📡 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> methodsJson = data['data'] ?? [];
        List<PaymentMethod> methods = methodsJson
            .map((json) => PaymentMethod.fromJson(json))
            .toList();
        
        return {
          'success': true,
          'methods': methods,
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load payment methods',
        };
      }
    } catch (e) {
      print('❌ Get payment methods error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> addPaymentMethod({
    required String userId,
    required String methodType,
    required String provider,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }
      
      final response = await http.post(
        Uri.parse('$BASE_URL/api/payments/methods'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'method_type': methodType,
          'provider': provider,
        }),
      );
      
      print('📡 Add payment method response: ${response.statusCode}');
      print('📡 Response body: ${response.body}');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'method': PaymentMethod.fromJson(data['data']),
          'message': data['message'] ?? 'Payment method added',
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to add payment method',
        };
      }
    } catch (e) {
      print('❌ Add payment method error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> removePaymentMethod(String methodId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }
      
      final response = await http.delete(
        Uri.parse('$BASE_URL/api/payments/methods/$methodId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      print('📡 Remove payment method response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Payment method removed',
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to remove payment method',
        };
      }
    } catch (e) {
      print('❌ Remove payment method error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> setDefaultPaymentMethod(String methodId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }
      
      final response = await http.put(
        Uri.parse('$BASE_URL/api/payments/methods/$methodId/default'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Default payment method updated',
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to set default payment method',
        };
      }
    } catch (e) {
      print('❌ Set default payment method error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Process booking payment (DP or Pelunasan) via REST API (/api/payments/pay)
  Future<Map<String, dynamic>> processPayment({
    required String bookingId,
    required double amount,
    required String paymentType, // 'dp' or 'pelunasan' or 'full'
    bool useWallet = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {
          'success': false,
          'message': 'Sesi Anda telah berakhir, silakan login kembali.',
        };
      }

      final url = Uri.parse('$BASE_URL/api/payments/pay');
      print('💳 Processing payment to: $url (bookingId: $bookingId, amount: $amount, type: $paymentType)');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'booking_id': bookingId,
          'amount': amount,
          'payment_type': paymentType,
          'use_wallet': useWallet,
        }),
      );

      print('📡 Process payment response code: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Pembayaran berhasil diproses',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal memproses pembayaran',
        };
      }
    } catch (e) {
      print('❌ Process payment error: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan jaringan: $e',
      };
    }
  }

  /// Get Wallet History
  Future<Map<String, dynamic>> getWalletHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.get(
        Uri.parse('$BASE_URL/api/payments/history'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load wallet history',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Create Xendit QRIS Code via REST API (/api/payments/qris)
  Future<Map<String, dynamic>> createQrisPayment({
    required String bookingId,
    required double amount,
    required String paymentType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {
          'success': false,
          'message': 'Sesi Anda telah berakhir, silakan login kembali.',
        };
      }

      final url = Uri.parse('$BASE_URL/api/payments/qris');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'booking_id': bookingId,
          'amount': amount,
          'payment_type': paymentType,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'QRIS berhasil dibuat',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal membuat QRIS',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan jaringan: $e',
      };
    }
  }

  /// Simulate QRIS Payment Success in Sandbox Mode (/api/payments/simulate-qris-paid)
  Future<Map<String, dynamic>> simulateQrisPaid({
    required String bookingId,
    required double amount,
    required String paymentType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {
          'success': false,
          'message': 'Sesi Anda telah berakhir, silakan login kembali.',
        };
      }

      final url = Uri.parse('$BASE_URL/api/payments/simulate-qris-paid');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'booking_id': bookingId,
          'amount': amount,
          'payment_type': paymentType,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Simulasi pembayaran sukses',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal mensimulasikan pembayaran',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan jaringan: $e',
      };
    }
  }
}