// lib/services/reward_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temenin_ajaa/core/constants/api_constants.dart';
import 'package:temenin_ajaa/modules/clients/pages/rewards_page.dart';

String get BASE_URL => ApiConstants.baseUrl;

class RewardService {
  Future<Map<String, dynamic>> getRewards(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }
      
      // Sample data for now
      // Replace with actual API call
      final List<Reward> rewards = [
        Reward(
          id: '1',
          name: 'Free Ride',
          description: 'Get 1 free ride up to 10km',
          pointsCost: 500,
          icon: Icons.directions_car,
          stock: 10,
        ),
        Reward(
          id: '2',
          name: '10% Discount',
          description: '10% discount on next booking',
          pointsCost: 300,
          icon: Icons.local_offer,
          stock: 20,
        ),
        Reward(
          id: '3',
          name: 'Priority Support',
          description: 'Get priority customer support for 1 month',
          pointsCost: 1000,
          icon: Icons.support_agent,
          stock: 5,
        ),
      ];
      
      final List<Transaction> transactions = [
        Transaction(
          id: '1',
          description: 'Completed booking - Jakarta to Bogor',
          points: 100,
          type: 'earn',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        Transaction(
          id: '2',
          description: 'Redeemed Free Ride voucher',
          points: 500,
          type: 'redeem',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ];
      
      return {
        'success': true,
        'rewards': rewards,
        'transactions': transactions,
      };
    } catch (e) {
      print('❌ Get rewards error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getVouchers(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }
      
      // Sample data
      final List<Voucher> vouchers = [
        Voucher(
          id: '1',
          code: 'WELCOME10',
          description: '10% discount on your next booking',
          discount: 10,
          maxDiscount: 10,
          minSpend: 50000,
          expiryDate: DateTime.now().add(const Duration(days: 30)),
          isClaimed: false,
        ),
        Voucher(
          id: '2',
          code: 'SPECIAL20',
          description: '20% discount for first-time users',
          discount: 20,
          maxDiscount: 20,
          minSpend: 100000,
          expiryDate: DateTime.now().add(const Duration(days: 15)),
          isClaimed: false,
        ),
        Voucher(
          id: '3',
          code: 'FLASH15',
          description: '15% discount on weekend bookings',
          discount: 15,
          maxDiscount: 15,
          minSpend: 75000,
          expiryDate: DateTime.now().add(const Duration(days: 7)),
          isClaimed: false,
        ),
      ];
      
      return {
        'success': true,
        'vouchers': vouchers,
      };
    } catch (e) {
      print('❌ Get vouchers error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getUserPoints(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final rawUser = data['data'];
        if (rawUser != null) {
          return {
            'success': true,
            'points': rawUser['points'] ?? 0,
          };
        }
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal mengambil poin',
      };
    } catch (e) {
      print('❌ Get user points error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> redeemReward(String rewardId, int pointsCost) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/api/profile/points/deduct');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'points': pointsCost,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Reward redeemed successfully',
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal menukarkan reward',
      };
    } catch (e) {
      print('❌ Redeem reward error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> claimVoucher(String voucherId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }
      
      // API call would go here
      return {
        'success': true,
        'message': 'Voucher claimed successfully',
        'voucherCode': 'WELCOME10',
      };
    } catch (e) {
      print('❌ Claim voucher error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}