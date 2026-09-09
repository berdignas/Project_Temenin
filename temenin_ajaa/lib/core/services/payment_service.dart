import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:temenin_ajaa/core/constants/api_constants.dart';
import 'package:temenin_ajaa/modules/clients/pages/payment_methods_page.dart';

String get BASE_URL => ApiConstants.baseUrl;

class PaymentService {
  Future<Map<String, dynamic>> getPaymentMethods(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final List<PaymentMethod> methods = [
      PaymentMethod(
        id: 'pm-1',
        userId: userId,
        methodType: 'bank_transfer',
        provider: 'BCA Virtual Account',
        isDefault: true,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      PaymentMethod(
        id: 'pm-2',
        userId: userId,
        methodType: 'e_wallet',
        provider: 'Gopay',
        isDefault: false,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      PaymentMethod(
        id: 'pm-3',
        userId: userId,
        methodType: 'cash',
        provider: 'Cash',
        isDefault: false,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];
    
    return {
      'success': true,
      'methods': methods,
    };
  }

  Future<Map<String, dynamic>> addPaymentMethod({
    required String userId,
    required String methodType,
    required String provider,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final newMethod = PaymentMethod(
      id: 'pm-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      methodType: methodType,
      provider: provider,
      isDefault: false,
      createdAt: DateTime.now(),
    );
    return {
      'success': true,
      'method': newMethod,
      'message': 'Payment method added successfully (Mock)',
    };
  }

  Future<Map<String, dynamic>> removePaymentMethod(String methodId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'success': true,
      'message': 'Payment method removed successfully (Mock)',
    };
  }

  Future<Map<String, dynamic>> setDefaultPaymentMethod(String methodId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'success': true,
      'message': 'Default payment method updated (Mock)',
    };
  }
}