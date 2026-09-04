import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:temenin_ajaa/core/constants/api_constants.dart';
import 'package:temenin_ajaa/modules/clients/pages/notifications_page.dart';
const String BASE_URL = ApiConstants.baseUrl;

class NotificationService {
  Future<Map<String, dynamic>> getNotifications(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }
      
      // Sample notifications data
      final List<NotificationModel> notifications = [
        NotificationModel(
          id: '1',
          title: 'Booking Confirmed! 🚗',
          message: 'Your booking with Driver Ahmad has been confirmed. Driver is on the way.',
          type: 'booking',
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        NotificationModel(
          id: '2',
          title: 'Special Promo for You! 🎉',
          message: 'Get 20% off on your next booking. Use code: RIDE20',
          type: 'promo',
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        NotificationModel(
          id: '3',
          title: 'Payment Successful ✅',
          message: 'Your payment of Rp 50.000 has been processed successfully.',
          type: 'payment',
          isRead: true,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        NotificationModel(
          id: '4',
          title: 'Points Earned! ⭐',
          message: 'You earned 100 points from your recent booking. Total points: 1.250',
          type: 'reward',
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        NotificationModel(
          id: '5',
          title: 'New Voucher Available 🎁',
          message: 'Claim your free ride voucher worth Rp 20.000! Limited time only.',
          type: 'promo',
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        NotificationModel(
          id: '6',
          title: 'Ride Completed 🏁',
          message: 'Your trip to Bogor has been completed. Rate your driver now!',
          type: 'booking',
          isRead: true,
          createdAt: DateTime.now().subtract(const Duration(days: 4)),
        ),
        NotificationModel(
          id: '7',
          title: 'Top Up Successful 💰',
          message: 'Your balance has been topped up by Rp 100.000',
          type: 'payment',
          isRead: true,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        NotificationModel(
          id: '8',
          title: 'Welcome to Temenin Ajaa! 👋',
          message: 'Thank you for joining us. Enjoy your first ride with 50% off!',
          type: 'system',
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
      ];
      
      return {
        'success': true,
        'notifications': notifications,
      };
    } catch (e) {
      print('❌ Get notifications error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> markAsRead(String notificationId) async {
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
        'message': 'Notification marked as read',
      };
    } catch (e) {
      print('❌ Mark as read error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> markAllAsRead() async {
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
        'message': 'All notifications marked as read',
      };
    } catch (e) {
      print('❌ Mark all as read error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
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
        'message': 'Notification deleted',
      };
    } catch (e) {
      print('❌ Delete notification error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}