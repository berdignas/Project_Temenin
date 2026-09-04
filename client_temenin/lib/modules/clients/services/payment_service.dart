// lib/services/payment_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temenin_ajaa/core/constants/api_constants.dart';
import 'package:temenin_ajaa/modules/clients/pages/payment_methods_page.dart';


const String BASE_URL = ApiConstants.baseUrl;

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
}