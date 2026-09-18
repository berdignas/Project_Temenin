import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/constants/api_constants.dart';
import 'package:temenin_ajaa/modules/clients/pages/notifications_page.dart';

String get BASE_URL => ApiConstants.baseUrl;

class NotificationService {
  /// Fetch real saved notifications for the user from Supabase DB or SharedPreferences
  Future<Map<String, dynamic>> getNotifications(String userId) async {
    try {
      // 1. Fetch real notifications from Supabase DB
      try {
        final List<dynamic> rows = await Supabase.instance.client
            .from('notifications')
            .select('*')
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        if (rows.isNotEmpty) {
          final List<NotificationModel> dbNotifications = rows.map((item) {
            return NotificationModel(
              id: item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              title: item['title'] ?? 'Notifikasi',
              message: item['message'] ?? '',
              type: item['type'] ?? 'info',
              isRead: item['is_read'] ?? item['isRead'] ?? false,
              createdAt: item['created_at'] != null 
                  ? DateTime.parse(item['created_at'].toString()) 
                  : DateTime.now(),
            );
          }).toList();

          return {
            'success': true,
            'notifications': dbNotifications,
          };
        }
      } catch (dbErr) {
        debugPrint('⚠️ Supabase notifications fetch error, falling back to local storage: $dbErr');
      }

      // 2. Fallback: SharedPreferences local storage
      final prefs = await SharedPreferences.getInstance();
      final key = 'client_notifications_$userId';
      final jsonStr = prefs.getString(key);

      List<NotificationModel> notifications = [];
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        notifications = decoded.map((item) => NotificationModel.fromJson(Map<String, dynamic>.from(item))).toList();
      }
      
      return {
        'success': true,
        'notifications': notifications,
      };
    } catch (e) {
      debugPrint('❌ Get notifications error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> markAsRead(String notificationId) async {
    try {
      try {
        await Supabase.instance.client
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notificationId);
      } catch (_) {}

      return {
        'success': true,
        'message': 'Notification marked as read',
      };
    } catch (e) {
      debugPrint('❌ Mark as read error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> markAllAsRead() async {
    try {
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await Supabase.instance.client
              .from('notifications')
              .update({'is_read': true})
              .eq('user_id', userId);
        }
      } catch (_) {}

      return {
        'success': true,
        'message': 'All notifications marked as read',
      };
    } catch (e) {
      debugPrint('❌ Mark all as read error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
    try {
      try {
        await Supabase.instance.client
            .from('notifications')
            .delete()
            .eq('id', notificationId);
      } catch (_) {}

      return {
        'success': true,
        'message': 'Notification deleted',
      };
    } catch (e) {
      debugPrint('❌ Delete notification error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}