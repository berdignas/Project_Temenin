import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/api_constants.dart';
import '../core/services/auth_service.dart';
import '../core/services/notification_sound_service.dart';
import '../modules/clients/pages/notifications_page.dart';

class ClientNotificationProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  List<NotificationModel> _notifications = [];
  StreamSubscription<List<Map<String, dynamic>>>? _bookingSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _chatSubscription;

  String? _currentUserId;
  final Set<String> _seenStatusKeys = {};
  bool _isFirstBookingLoad = true;

  List<NotificationModel> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Initialize and load saved notifications for user
  Future<void> subscribeToNotifications(String userId) async {
    if (_currentUserId == userId && (_bookingSubscription != null || _chatSubscription != null)) {
      return;
    }

    _currentUserId = userId;
    _isFirstBookingLoad = true;
    await _loadSavedNotifications(userId);
    _listenToBookingUpdates(userId);
    _listenToChatUpdates(userId);
  }

  void unsubscribe() {
    _bookingSubscription?.cancel();
    _chatSubscription?.cancel();
    _bookingSubscription = null;
    _chatSubscription = null;
    _currentUserId = null;
    _seenStatusKeys.clear();
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }

  /// Load persisted notifications from SharedPreferences
  Future<void> _loadSavedNotifications(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'client_notifications_$userId';
      final jsonStr = prefs.getString(key);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _notifications = decoded.map((item) => NotificationModel.fromJson(Map<String, dynamic>.from(item))).toList();
      } else {
        _notifications = [];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved notifications: $e');
    }
  }

  /// Persist current notifications to SharedPreferences
  Future<void> _saveNotifications() async {
    if (_currentUserId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'client_notifications_$_currentUserId';
      final jsonList = _notifications.map((n) => n.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  Timer? _notificationPollingTimer;

  /// Listen to Supabase Realtime booking changes for current client
  void _listenToBookingUpdates(String userId) {
    _bookingSubscription?.cancel();
    _notificationPollingTimer?.cancel();
    try {
      _bookingSubscription = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .handleError((err) {
            debugPrint('❌ Client Notification Booking Realtime Error handled: $err -> Fallback Polling');
            _startNotificationPolling(userId);
          })
          .listen((List<Map<String, dynamic>> data) {
            _processBookingEvents(data);
          }, onError: (err) {
            debugPrint('❌ Client Notification Booking Realtime Error: $err -> Fallback Polling');
            _startNotificationPolling(userId);
          }, cancelOnError: false);
    } catch (e) {
      debugPrint('❌ Client Notification Booking Realtime Exception: $e -> Fallback Polling');
      _startNotificationPolling(userId);
    }
  }

  void _startNotificationPolling(String userId) {
    _notificationPollingTimer?.cancel();
    _notificationPollingTimer = Timer.periodic(const Duration(seconds: 7), (_) async {
      try {
        final token = await _authService.getToken();
        if (token == null) return;
        final url = Uri.parse('${ApiConstants.baseUrl}/api/bookings');
        final response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        if (response.statusCode == 200) {
          final resData = jsonDecode(response.body);
          final List<dynamic> rawList = resData['data'] ?? [];
          final List<Map<String, dynamic>> list = rawList.cast<Map<String, dynamic>>();
          _processBookingEvents(list);
        }
      } catch (e) {
        debugPrint('ℹ️ Notification polling notice: $e');
      }
    });
  }

  /// Process incoming booking updates and trigger notifications with sound
  void _processBookingEvents(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) return;

    for (final rawBooking in bookings) {
      final bookingId = rawBooking['id']?.toString() ?? '';
      final status = rawBooking['status']?.toString() ?? '';
      final addDetails = rawBooking['additional_details'] is Map ? rawBooking['additional_details'] as Map : {};
      final subStatus = addDetails['sub_status']?.toString() ?? '';
      final isNegot = addDetails['negotiation'] == true;
      final driverOfferPrice = addDetails['driver_offer_price'];

      // Build unique key for this booking state event
      final eventKey = '$bookingId-$status-$subStatus-${addDetails['dp_paid']}-${addDetails['pelunasan_paid']}-$driverOfferPrice';

      if (_seenStatusKeys.contains(eventKey)) {
        continue;
      }
      _seenStatusKeys.add(eventKey);

      // Skip triggering sounds on the very first historical data load
      if (_isFirstBookingLoad) {
        continue;
      }

      String? title;
      String? message;
      String type = 'booking';

      if (status == 'accepted' || status == 'confirmed') {
        title = '🚗 Booking Dikonfirmasi!';
        message = 'Driver telah mengonfirmasi pesanan pendampingan Anda.';
      } else if (subStatus == 'on_the_way') {
        title = '🛵 Driver Dalam Perjalanan';
        message = 'Driver sedang berjalan menuju lokasi penjemputan Anda.';
      } else if (subStatus == 'arrived') {
        title = '📍 Driver Telah Sampai';
        message = 'Driver sudah berada di lokasi penjemputan Anda!';
      } else if (subStatus == 'started' || subStatus == 'ongoing' || status == 'ongoing' || status == 'in_progress') {
        title = '✨ Perjalanan Dimulai';
        message = 'Selamat menikmati perjalanan & layanan dari Temenin Ajaa.';
      } else if (status == 'completed' || subStatus == 'completed') {
        title = '🏁 Perjalanan Selesai';
        message = 'Pesanan Anda telah selesai. Jangan lupa berikan ulasan untuk driver!';
      } else if (status == 'cancelled' || subStatus == 'cancelled') {
        title = '❌ Booking Dibatalkan';
        message = 'Pesanan Anda telah dibatalkan.';
      } else if (isNegot && driverOfferPrice != null) {
        title = '💬 Penawaran Harga Baru!';
        message = 'Driver menawarkan harga Rp $driverOfferPrice untuk pesanan Anda.';
      } else if (addDetails['early_start_request'] == 'pending' && !_hasNotifForKey('early-req-$bookingId-${addDetails['early_start_requested_at']}')) {
        _seenStatusKeys.add('early-req-$bookingId-${addDetails['early_start_requested_at']}');
        title = '⚡ Permintaan Keberangkatan (OTW)';
        message = 'Driver meminta persetujuan untuk mengakhiri waktu persiapan dan berangkat OTW sekarang.';
        type = 'booking';
      } else if (addDetails['early_start_request'] == 'approved' && !_hasNotifForKey('early-appr-$bookingId-${addDetails['early_start_approved_at']}')) {
        _seenStatusKeys.add('early-appr-$bookingId-${addDetails['early_start_approved_at']}');
        title = '✅ Persetujuan Keberangkatan';
        message = 'Anda telah menyetujui driver untuk mengakhiri persiapan & berangkat OTW.';
        type = 'booking';
      } else if (addDetails['dp_paid'] == true && !_hasNotifForKey('dp-$bookingId')) {
        title = '💳 Uang Muka (DP) Berhasil';
        message = 'Pembayaran DP untuk pesanan Anda berhasil diproses.';
        type = 'payment';
      } else if (addDetails['pelunasan_paid'] == true && !_hasNotifForKey('lunas-$bookingId')) {
        title = '✅ Pelunasan Berhasil';
        message = 'Pembayaran pelunasan akhir pesanan Anda telah berhasil.';
        type = 'payment';
      }

      if (title != null && message != null) {
        _addNotificationAndPlaySound(
          title: title,
          message: message,
          type: type,
          data: {
            'bookingId': bookingId,
            'booking': rawBooking,
          },
        );
      }
    }

    _isFirstBookingLoad = false;
  }

  /// Listen to Supabase Realtime chat messages
  void _listenToChatUpdates(String userId) {
    _chatSubscription?.cancel();
    try {
      _chatSubscription = Supabase.instance.client
          .from('booking_messages')
          .stream(primaryKey: ['id'])
          .handleError((err) {
            debugPrint("Chat stream Realtime error handled: $err");
          })
          .listen(
            (List<Map<String, dynamic>> messages) {
              for (final msg in messages) {
                final senderRole = msg['sender_role']?.toString();
                final senderId = msg['sender_id']?.toString() ?? '';
                final msgId = msg['id']?.toString() ?? '';

                if (senderRole == 'driver' && senderId != userId) {
                  final key = 'chat-msg-$msgId';
                  if (!_seenStatusKeys.contains(key)) {
                    _seenStatusKeys.add(key);

                    final content = msg['message']?.toString() ?? 'Pesan baru masuk';
                    final bookingId = msg['booking_id']?.toString();

                    _addNotificationAndPlaySound(
                      title: '💬 Pesan Baru dari Driver',
                      message: content,
                      type: 'chat',
                      data: {
                        'bookingId': bookingId,
                        'senderId': senderId,
                      },
                    );
                  }
                }
              }
            },
            onError: (err) {
              debugPrint("Chat stream Realtime error: $err");
            },
            cancelOnError: false,
          );
    } catch (e) {
      debugPrint('❌ Client Notification Chat Realtime Exception: $e');
    }
  }

  bool _hasNotifForKey(String key) {
    return _seenStatusKeys.contains(key);
  }

  void _addNotificationAndPlaySound({
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) {
    final notif = NotificationModel(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}-${_notifications.length}',
      title: title,
      message: message,
      type: type,
      isRead: false,
      data: data,
      createdAt: DateTime.now(),
    );

    _notifications.insert(0, notif);
    _saveNotifications();
    
    // Play alert sound & haptic feedback (same sound system as driver app)
    NotificationSoundService().playNotificationSound(
      isLoudAlert: type == 'booking' || type == 'payment',
    );

    notifyListeners();
  }

  /// Add notification manually
  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    _saveNotifications();
    notifyListeners();
  }

  /// Mark single notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index].isRead = true;
      await _saveNotifications();
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      n.isRead = true;
    }
    await _saveNotifications();
    notifyListeners();
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _saveNotifications();
    notifyListeners();
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    _notifications.clear();
    await _saveNotifications();
    notifyListeners();
  }
}
