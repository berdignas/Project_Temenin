import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/booking_service.dart';
import '../data/models/booking_model.dart';
import '../core/services/notification_sound_service.dart';
import '../data/models/driver_notification_model.dart';
import 'auth_provider.dart';

class BookingProvider extends ChangeNotifier {
  final BookingService _bookingService = BookingService();
  
  List<BookingModel> _bookings = [];
  BookingModel? _activeBooking;
  BookingModel? _incomingBooking;
  BookingModel? _pendingReviewBooking;
  BookingModel? _lastCompletedBooking;
  BookingModel? _ongoingTrip;
  List<BookingModel> _upcomingBookings = [];
  List<BookingModel> _completedBookings = [];
  List<BookingModel> _cancelledBookings = [];
  
  // In-app Notifications state
  final List<DriverNotificationModel> _notifications = [];
  DriverNotificationModel? _activeBannerNotification;
  final Set<String> _seenBookingIds = {};
  final Set<String> _seenDpPaidBookingIds = {};
  final Set<String> _seenPelunasanBookingIds = {};
  final Set<String> _seenMessageKeys = {};
  bool _isFirstBookingProcess = true;
  String _lastBookingsFingerprint = '';
  final Map<String, Map<String, dynamic>> _clientUserCache = {};
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Earnings & Escrow state
  double _totalEarnings = 0.0;
  int _totalRides = 0;
  double _pendingEscrowBalance = 0.0;
  List<dynamic> _earningsBookings = [];
  
  // Realtime subscription & Polling
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _chatMessagesSubscription;
  Timer? _pollingTimer;

  List<BookingModel> get bookings => _bookings;
  List<BookingModel> get completedBookings => _completedBookings;
  List<BookingModel> get upcomingBookings => List.unmodifiable(_upcomingBookings);
  List<BookingModel> get cancelledBookings => List.unmodifiable(_cancelledBookings);
  BookingModel? get ongoingTrip => _ongoingTrip;
  bool get isCurrentlyOnTrip => _ongoingTrip != null;
  BookingModel? get activeBooking => _activeBooking;
  BookingModel? get incomingBooking => _incomingBooking;
  BookingModel? get pendingReviewBooking => _pendingReviewBooking;
  BookingModel? get lastCompletedBooking => _lastCompletedBooking;
  List<DriverNotificationModel> get notifications => List.unmodifiable(_notifications);
  DriverNotificationModel? get activeBannerNotification => _activeBannerNotification;
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  double get totalEarnings => _totalEarnings;
  int get totalRides => _totalRides;
  double get pendingEscrowBalance => _pendingEscrowBalance;
  List<dynamic> get earningsBookings => _earningsBookings;

  // Dismiss top floating banner
  void dismissBannerNotification() {
    if (_activeBannerNotification != null) {
      _activeBannerNotification!.isRead = true;
    }
    _activeBannerNotification = null;
    NotificationSoundService().stopSound();
    notifyListeners();
  }

  // Mark notification as read
  void markNotificationAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx].isRead = true;
      notifyListeners();
    }
  }

  // Mark all notifications as read
  void markAllNotificationsAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  // Clear current incoming request
  void clearIncomingRequest() {
    _incomingBooking = null;
    if (_activeBannerNotification != null) {
      _activeBannerNotification!.isRead = true;
    }
    _activeBannerNotification = null;
    NotificationSoundService().stopSound();
    notifyListeners();
  }

  // Set active booking manually (e.g. on click from list)
  void setActiveBooking(BookingModel? booking) {
    _activeBooking = booking;
    _ongoingTrip = booking;
    notifyListeners();
  }

  void clearActiveBooking() {
    _activeBooking = null;
    notifyListeners();
  }

  void clearPendingReview() {
    _pendingReviewBooking = null;
    notifyListeners();
  }

  String? _currentDriverId;
  String? _currentUserId;
  final Set<String> _associatedDriverIds = {};
  List<BookingModel> _pendingOffers = [];
  List<BookingModel> get pendingOffers => _pendingOffers;

  Future<void> _resolveDriverIds() async {
    try {
      final currentAuthUser = Supabase.instance.client.auth.currentUser;
      final uId = _currentUserId ?? currentAuthUser?.id;
      if (uId != null && uId.isNotEmpty && uId != 'active-driver') {
        _associatedDriverIds.add(uId);
        try {
          final driverRow = await Supabase.instance.client
              .from('drivers')
              .select('id, user_id')
              .or('id.eq.$uId,user_id.eq.$uId')
              .maybeSingle();
          if (driverRow != null) {
            if (driverRow['id'] != null) _associatedDriverIds.add(driverRow['id'].toString());
            if (driverRow['user_id'] != null) _associatedDriverIds.add(driverRow['user_id'].toString());
          }
        } catch (e) {
          debugPrint("Note: Driver lookup query: $e");
        }
      }
      if (_currentDriverId != null && _currentDriverId!.isNotEmpty && _currentDriverId != 'active-driver') {
        _associatedDriverIds.add(_currentDriverId!);
      }
    } catch (e) {
      debugPrint("Error resolving driver IDs: $e");
    }
  }

  Future<void> _processBookingsData(List<Map<String, dynamic>> data) async {
    if (data.isEmpty) {
      if (_pendingOffers.isNotEmpty || _incomingBooking != null || _activeBooking != null) {
        _pendingOffers = [];
        _incomingBooking = null;
        _activeBooking = null;
        notifyListeners();
      }
      return;
    }

    final currentFingerprint = data.map((b) {
      final d = b['additional_details'];
      final sub = d is Map ? "${d['sub_status']}_${d['dp_paid']}_${d['pelunasan_paid']}_${d['payout_status']}_${d['driver_credited']}" : '';
      return "${b['id']}_${b['status']}_${b['driver_id']}_$sub";
    }).join('|');

    final bool hasDataChanged = currentFingerprint != _lastBookingsFingerprint;
    final int prevNotifCount = _notifications.length;
    _lastBookingsFingerprint = currentFingerprint;

    final pendingList = data.where((b) {
      if (b['status']?.toString() != 'pending') return false;
      final rawDriverId = b['driver_id'];
      final bDriverId = rawDriverId != null ? rawDriverId.toString().trim() : '';
      
      // If driver_id is not assigned, it's an open offer broadcast
      if (bDriverId.isEmpty || bDriverId == 'null') return true;
      
      // Check against all known IDs for this driver
      if (_associatedDriverIds.contains(bDriverId)) return true;
      if (_currentDriverId != null && (_currentDriverId == bDriverId || _currentDriverId == 'active-driver')) return true;
      if (_currentUserId != null && _currentUserId == bDriverId) return true;
      
      // Check additional details for partner metadata
      final details = b['additional_details'];
      if (details is Map) {
        final dId = details['driverId']?.toString() ?? details['driver_id']?.toString();
        final uId = details['driver_user_id']?.toString();
        if (dId != null && dId.isNotEmpty && (_currentDriverId == dId || _associatedDriverIds.contains(dId))) {
          return true;
        }
        if (uId != null && uId.isNotEmpty && _currentUserId == uId) {
          return true;
        }
      }
      
      return false; // Do not notify driver if targeted to another specific driver
    }).toList();

    // Fetch client details only for users not yet in memory cache
    final Set<String> clientIds = {};
    for (final b in data) {
      final uid = b['user_id'];
      if (uid != null) {
        final s = uid.toString().trim();
        if (s.isNotEmpty && s != 'null') {
          clientIds.add(s);
        }
      }
    }

    final missingClientIds = clientIds.where((id) => !_clientUserCache.containsKey(id)).toList();
    if (missingClientIds.isNotEmpty) {
      try {
        final usersData = await Supabase.instance.client
            .from('users')
            .select()
            .inFilter('id', missingClientIds);
        for (final u in usersData) {
          if (u is Map && u['id'] != null) {
            _clientUserCache[u['id'].toString()] = Map<String, dynamic>.from(u);
          }
        }
      } catch (e) {
        debugPrint('Error batch fetching client details: $e');
      }
    }
    final userMap = _clientUserCache;

    // Real-time calculation of pending escrow (DP safely held in platform)
    double realtimePendingEscrow = 0.0;
    for (final raw in data) {
      final s = raw['status']?.toString();
      final d = raw['additional_details'] is Map ? raw['additional_details'] as Map : null;
      final sub = d?['sub_status']?.toString();
      final isDpPaid = d?['dp_paid'] == true || sub == 'dp_paid';
      final isReleased = d?['payout_status'] == 'released' || d?['driver_credited'] == true;
      if (s != 'cancelled' && sub != 'cancelled' && isDpPaid && !isReleased) {
        final dpVal = d?['dp'] ?? d?['dp_amount'] ?? raw['escrow_balance'] ?? ((raw['total_price'] ?? 0) * 0.5);
        final dpNum = dpVal is num ? dpVal.toDouble() : (double.tryParse(dpVal?.toString() ?? '') ?? 0.0);
        realtimePendingEscrow += dpNum;
      }
    }
    _pendingEscrowBalance = realtimePendingEscrow;

    // Process pending offers
    if (pendingList.isNotEmpty) {
      List<BookingModel> offers = pendingList.map((rawBooking) {
        final clientId = rawBooking['user_id']?.toString();
        final clientData = clientId != null ? userMap[clientId] : null;
        return BookingModel.fromJson({
          ...rawBooking,
          'users': clientData,
        });
      }).toList();
      _pendingOffers = offers;

      for (final offer in offers) {
        final bId = offer.id.toString();
        if (!_seenBookingIds.contains(bId)) {
          _seenBookingIds.add(bId);

          final clientName = offer.client?.fullName ?? 'Pelanggan';
          final notif = DriverNotificationModel(
            id: 'notif-$bId-${DateTime.now().millisecondsSinceEpoch}',
            title: '🔔 Pesanan Baru Masuk!',
            message: '$clientName memesan pendampingan (${offer.duration} Jam) • Rp ${offer.totalPrice.toStringAsFixed(0)}',
            timestamp: DateTime.now(),
            type: NotificationType.newOrder,
            booking: offer,
            isRead: false,
          );
          _notifications.insert(0, notif);
          _activeBannerNotification = notif;
          NotificationSoundService().playOrderAlert();
        }
      }

      final directTargetOffer = offers.where((offer) {
        final dId = offer.driverId?.toString();
        return dId != null && _associatedDriverIds.contains(dId);
      }).firstOrNull;

      if (directTargetOffer != null) {
        if (_incomingBooking == null || _incomingBooking!.id.toString() != directTargetOffer.id.toString()) {
          _incomingBooking = directTargetOffer;
        }
      } else {
        _incomingBooking = null;
      }
    } else {
      _pendingOffers = [];
      _incomingBooking = null;
    }

    // Categorize bookings: Ongoing trip vs Scheduled upcoming vs Completed vs Cancelled
    final List<BookingModel> convertedUpcoming = [];
    final List<BookingModel> convertedOngoing = [];
    final List<BookingModel> convertedCompleted = [];
    final List<BookingModel> convertedCancelled = [];

    for (final rawBooking in data) {
      final s = rawBooking['status']?.toString();
      final d = rawBooking['additional_details'] is Map
          ? rawBooking['additional_details'] as Map
          : (rawBooking['additionalDetails'] is Map ? rawBooking['additionalDetails'] as Map : null);
      final sub = d?['sub_status']?.toString();
      final isPelunasanPaid = sub == 'paid' || 
                             s == 'paid' || 
                             s == 'closed' || 
                             sub == 'closed' || 
                             d?['pelunasan_paid'] == true || 
                             d?['final_paid'] == true || 
                             d?['payment_status'] == 'LUNAS';

      // If pending, check if it's targeted directly to this driver
      final bDriverId = rawBooking['driver_id']?.toString();
      final isDirectToMe = bDriverId != null && bDriverId.isNotEmpty &&
          (_associatedDriverIds.contains(bDriverId) || 
           _currentDriverId == bDriverId || 
           _currentUserId == bDriverId);

      if (s == 'pending' && !isDirectToMe) continue; // Skip only unassigned broadcast offers from upcoming list

      final clientId = rawBooking['user_id']?.toString();
      final clientData = clientId != null ? userMap[clientId] : null;
      final model = BookingModel.fromJson({
        ...rawBooking,
        'users': clientData,
      });

      if (s == 'cancelled' || sub == 'cancelled') {
        convertedCancelled.add(model);
      } else if (model.isOngoingTrip) {
        convertedOngoing.add(model);
      } else if (isPelunasanPaid || s == 'closed' || sub == 'closed' || s == 'completed' || sub == 'completed') {
        convertedCompleted.add(model);
      } else {
        convertedUpcoming.add(model);
      }
    }

    convertedOngoing.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    convertedUpcoming.sort((a, b) => (a.bookingDate ?? a.createdAt).compareTo(b.bookingDate ?? b.createdAt));
    convertedCompleted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    convertedCancelled.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _upcomingBookings = convertedUpcoming;
    _completedBookings = convertedCompleted;
    _cancelledBookings = convertedCancelled;
    _bookings = [...convertedOngoing, ...convertedUpcoming, ...convertedCompleted, ...convertedCancelled];

    // Set ongoing trip (if physically on trip)
    if (convertedOngoing.isNotEmpty) {
      if (_ongoingTrip != null && convertedOngoing.any((b) => b.id == _ongoingTrip!.id)) {
        _ongoingTrip = convertedOngoing.firstWhere(
          (b) => b.id == _ongoingTrip!.id,
          orElse: () => convertedOngoing.first,
        );
      } else {
        _ongoingTrip = convertedOngoing.first;
      }
    } else {
      _ongoingTrip = null;
    }

    // Set active booking: ongoing trip has highest priority, then earliest upcoming
    if (_ongoingTrip != null) {
      _activeBooking = _ongoingTrip;
    } else if (_upcomingBookings.isNotEmpty) {
      _activeBooking = _upcomingBookings.first;
    } else {
      if (_activeBooking != null && (_activeBooking!.isCompleted || _activeBooking!.isPelunasanPaid)) {
        _lastCompletedBooking = _activeBooking;
      }
      _activeBooking = null;
    }

    // DP Paid Notifications for upcoming bookings
    for (final b in _upcomingBookings) {
      final add = b.additionalDetails;
      final isDpPaid = add?['dp_paid'] == true || add?['sub_status'] == 'dp_paid' || b.status == 'dp_paid';
      if (isDpPaid && !_seenDpPaidBookingIds.contains(b.id)) {
        _seenDpPaidBookingIds.add(b.id);
        final clientName = b.client?.fullName ?? 'Pelanggan';
        final notif = DriverNotificationModel(
          id: 'notif-dp-${b.id}-${DateTime.now().millisecondsSinceEpoch}',
          title: '💳 Pembayaran DP Berhasil!',
          message: '$clientName telah membayar DP. Jadwal terkonfirmasi.',
          timestamp: DateTime.now(),
          type: NotificationType.dpPaid,
          booking: b,
          isRead: false,
        );
        _notifications.insert(0, notif);
        _activeBannerNotification = notif;
        NotificationSoundService().playOrderAlert();
      }
    }

    // Process pending review bookings (settled/completed, waiting for driver review)
    final pendingReviewList = convertedCompleted.where((b) {
      final d = b.additionalDetails;
      final isReviewed = d?['client_review'] != null || 
                         d?['driver_rating_client'] != null || 
                         d?['driver_reviewed'] == true ||
                         b.status == 'closed' || 
                         d?['sub_status'] == 'closed';
      return !isReviewed && b.isPelunasanPaid;
    }).toList();

    if (pendingReviewList.isNotEmpty) {
      _pendingReviewBooking = pendingReviewList.first;
      _lastCompletedBooking = _pendingReviewBooking;
      final bId = _pendingReviewBooking!.id;
      if (!_seenPelunasanBookingIds.contains(bId)) {
        _seenPelunasanBookingIds.add(bId);
        final clientName = _pendingReviewBooking?.client?.fullName ?? 'Pelanggan';
        final notif = DriverNotificationModel(
          id: 'notif-pelunasan-$bId-${DateTime.now().millisecondsSinceEpoch}',
          title: '🎉 Pelunasan Berhasil Diterima!',
          message: '$clientName telah menyelesaikan pelunasan. Berikan rating & ulasan klien.',
          timestamp: DateTime.now(),
          type: NotificationType.pelunasanPaid,
          booking: _pendingReviewBooking,
          isRead: false,
        );
        _notifications.insert(0, notif);
        _activeBannerNotification = notif;
        NotificationSoundService().playOrderAlert();
      }
    } else {
      _pendingReviewBooking = null;
    }

    // Process chat messages across all bookings for real-time notifications
    for (final rawBooking in data) {
      try {
        final bId = rawBooking['id']?.toString() ?? '';
        final addDetails = rawBooking['additional_details'] is Map
            ? rawBooking['additional_details'] as Map
            : (rawBooking['additionalDetails'] is Map ? rawBooking['additionalDetails'] as Map : null);
        
        final chatMsgs = addDetails?['chat_messages'] as List<dynamic>?;
        if (chatMsgs != null && chatMsgs.isNotEmpty) {
          for (final m in chatMsgs) {
            if (m is Map) {
              final sender = m['sender']?.toString() ?? m['sender_role']?.toString();
              if (sender == 'user' || sender == 'client') {
                final msgText = m['text']?.toString() ?? m['message']?.toString() ?? '';
                final timeKey = m['timestamp']?.toString() ?? m['time']?.toString() ?? '';
                final msgKey = "${bId}_${timeKey}_$msgText";

                if (!_seenMessageKeys.contains(msgKey)) {
                  _seenMessageKeys.add(msgKey);
                  
                  BookingModel? bModel;
                  try {
                    bModel = BookingModel.fromJson(rawBooking);
                  } catch (_) {}

                  final clientName = bModel?.client?.fullName ?? 'Pelanggan';
                  final notif = DriverNotificationModel(
                    id: 'notif-msg-$msgKey-${DateTime.now().millisecondsSinceEpoch}',
                    title: '💬 Pesan Baru dari $clientName',
                    message: msgText,
                    timestamp: DateTime.now(),
                    type: NotificationType.newMessage,
                    booking: bModel,
                    isRead: false,
                  );
                  
                  _notifications.insert(0, notif);
                  _activeBannerNotification = notif;
                  if (!_isFirstBookingProcess) {
                    NotificationSoundService().playOrderAlert();
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error processing booking notification: $e');
      }
    }

    final bool hasNotifChanged = _notifications.length != prevNotifCount;
    _isFirstBookingProcess = false;

    if (hasDataChanged || hasNotifChanged) {
      debugPrint('📦 Driver bookings updated (${data.length} items, unread: $unreadNotificationsCount)');
      notifyListeners();
    }
  }

  // Subscribe to real-time bookings from Supabase
  void subscribeToBookings(String driverId, {String? userId}) {
    _currentDriverId = driverId;
    _currentUserId = userId;
    debugPrint('📡 Subscribing to Supabase Realtime for Driver ID: $driverId, User ID: $userId');
    _resolveDriverIds();
    _realtimeSubscription?.cancel();
    _pollingTimer?.cancel();

    try {
      _realtimeSubscription = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .listen((List<Map<String, dynamic>> data) {
            debugPrint('⚡ Supabase Realtime: Received ${data.length} bookings');
            _processBookingsData(data);
          }, onError: (err) {
            debugPrint('❌ Supabase stream subscription error: $err');
          });
    } catch (e) {
      debugPrint('❌ Supabase stream connection failed: $e');
    }

    _chatMessagesSubscription?.cancel();
    try {
      _chatMessagesSubscription = Supabase.instance.client
          .from('booking_messages')
          .stream(primaryKey: ['id'])
          .listen((List<Map<String, dynamic>> messages) {
            _processChatMessages(messages);
          }, onError: (err) {
            debugPrint('❌ Supabase chat stream subscription error: $err');
          });
    } catch (e) {
      debugPrint('❌ Supabase chat stream connection failed: $e');
    }

    // Polling fallback every 5 seconds (realtime stream is primary)
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final data = await Supabase.instance.client
            .from('bookings')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        _processBookingsData(List<Map<String, dynamic>>.from(data));
      } catch (e) {
        debugPrint("Error in driver polling: $e");
      }
    });

    // Immediate initial fetch to ensure instant display
    Supabase.instance.client
        .from('bookings')
        .select()
        .order('created_at', ascending: false)
        .limit(20)
        .then((data) {
          _processBookingsData(List<Map<String, dynamic>>.from(data));
        }).catchError((e) {
          debugPrint("Error in driver initial fetch: $e");
        });
  }

  void _processChatMessages(List<Map<String, dynamic>> messages) {
    for (final m in messages) {
      final role = m['sender_role']?.toString();
      final msgId = m['id']?.toString() ?? '';
      final msgKey = "chat_$msgId";

      if (role == 'client' && !_seenMessageKeys.contains(msgKey)) {
        _seenMessageKeys.add(msgKey);
        final bookingId = m['booking_id']?.toString() ?? '';
        final msgText = m['message']?.toString() ?? '';

        final matchingBooking = _bookings.where((b) => b.id == bookingId).firstOrNull;
        if (matchingBooking != null) {
          final clientName = matchingBooking.client?.fullName ?? 'Pelanggan';
          final notif = DriverNotificationModel(
            id: 'notif-msg-$msgKey-${DateTime.now().millisecondsSinceEpoch}',
            title: '💬 Pesan Baru dari $clientName',
            message: msgText,
            timestamp: DateTime.now(),
            type: NotificationType.newMessage,
            booking: matchingBooking,
            isRead: false,
          );

          _notifications.insert(0, notif);
          _activeBannerNotification = notif;
          NotificationSoundService().playOrderAlert();
          notifyListeners();
        }
      }
    }
  }

  // Cancel subscription
  void unsubscribeFromBookings() {
    debugPrint('📡 Unsubscribed from Supabase bookings.');
    _realtimeSubscription?.cancel();
    _chatMessagesSubscription?.cancel();
    _pollingTimer?.cancel();
  }

  // Send a counter offer price for Freedom Request
  Future<bool> sendCounterOffer(String bookingId, double counterPrice) async {
    final result = await _bookingService.placeNegotiation(bookingId, counterPrice, "Driver counter offer");
    if (result['success'] == true) {
      debugPrint("Negotiation successfully sent to server.");
    }

    if (_incomingBooking != null && _incomingBooking!.id == bookingId) {
      _incomingBooking = BookingModel(
        id: _incomingBooking!.id,
        userId: _incomingBooking!.userId,
        driverId: _incomingBooking!.driverId,
        status: 'pending',
        pickupLocation: _incomingBooking!.pickupLocation,
        dropoffLocation: _incomingBooking!.dropoffLocation,
        pickupLatitude: _incomingBooking!.pickupLatitude,
        pickupLongitude: _incomingBooking!.pickupLongitude,
        dropoffLatitude: _incomingBooking!.dropoffLatitude,
        dropoffLongitude: _incomingBooking!.dropoffLongitude,
        duration: _incomingBooking!.duration,
        totalPrice: counterPrice,
        bookingDate: _incomingBooking!.bookingDate,
        additionalDetails: {
          ...?_incomingBooking!.additionalDetails,
          'driverCounterPrice': counterPrice,
          'isCounterSent': true,
        },
        createdAt: _incomingBooking!.createdAt,
        client: _incomingBooking!.client,
      );
      notifyListeners();
      return true;
    }
    return result['success'] == true;
  }

  // Load Bookings History (via API)
  Future<void> loadBookingsHistory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _bookingService.getDriverBookings(status: 'all');
    if (result['success'] == true) {
      _bookings = result['bookings'];
    } else {
      _errorMessage = result['message'];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Accept booking
  Future<bool> acceptBooking(String bookingId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updateData = <String, dynamic>{'status': 'accepted'};
      if (_currentDriverId != null && _currentDriverId!.isNotEmpty && !_currentDriverId!.startsWith('active')) {
        updateData['driver_id'] = _currentDriverId;
      }
      await Supabase.instance.client
          .from('bookings')
          .update(updateData)
          .eq('id', bookingId);
    } catch (e) {
      debugPrint("Supabase direct update error: $e");
    }

    try {
      await _bookingService.updateBookingStatus(bookingId, 'accepted');
    } catch (e) {
      debugPrint("Backend updateBookingStatus error: $e");
    }
    
    _isLoading = false;

    BookingModel? matched = _findBookingById(bookingId);
    BookingModel acceptedModel;
    if (matched != null) {
      acceptedModel = matched.copyWith(status: 'accepted');
    } else {
      acceptedModel = BookingModel(
        id: bookingId,
        userId: 'client-user',
        status: 'accepted',
        pickupLocation: 'Lokasi Penjemputan',
        dropoffLocation: 'Tujuan',
        duration: 3,
        totalPrice: 150000.0,
        createdAt: DateTime.now(),
      );
    }
    _activeBooking = acceptedModel;
    _pendingOffers.removeWhere((b) => b.id.toString() == bookingId.toString());
    if (!_upcomingBookings.any((b) => b.id.toString() == bookingId.toString())) {
      _upcomingBookings.insert(0, acceptedModel);
    }
    _incomingBooking = null;

    notifyListeners();
    return true;
  }

  BookingModel? _findBookingById(String bookingId) {
    if (_incomingBooking != null && _incomingBooking!.id.toString() == bookingId.toString()) {
      return _incomingBooking;
    }
    if (_activeBooking != null && _activeBooking!.id.toString() == bookingId.toString()) {
      return _activeBooking;
    }
    final matchInPending = _pendingOffers.where((b) => b.id.toString() == bookingId.toString()).toList();
    if (matchInPending.isNotEmpty) {
      return matchInPending.first;
    }
    return null;
  }

  // Accept a booking with a custom final negotiated price
  Future<bool> acceptBookingWithPrice(String bookingId, double finalPrice) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Supabase.instance.client
          .from('bookings')
          .update({
            'status': 'accepted',
            'total_price': finalPrice,
          })
          .eq('id', bookingId);
    } catch (e) {
      debugPrint("Supabase direct update error: $e");
    }

    try {
      await _bookingService.updateBookingStatus(bookingId, 'accepted');
    } catch (e) {
      debugPrint("Backend updateBookingStatus error: $e");
    }
    
    _isLoading = false;

    BookingModel? matched = _findBookingById(bookingId);
    if (matched != null) {
      final updated = matched.copyWith(status: 'accepted', totalPrice: finalPrice);
      _activeBooking = updated;
      _pendingOffers.removeWhere((b) => b.id.toString() == bookingId.toString());
      if (!_upcomingBookings.any((b) => b.id.toString() == bookingId.toString())) {
        _upcomingBookings.insert(0, updated);
      }
    }
    _incomingBooking = null;

    notifyListeners();
    return true;
  }

  // Reject booking (cancels it or returns to queue)
  Future<bool> rejectBooking(String bookingId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Supabase.instance.client
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', bookingId);
    } catch (e) {
      debugPrint("Supabase rejectBooking error: $e");
    }

    try {
      await _bookingService.updateBookingStatus(bookingId, 'cancelled');
    } catch (e) {
      debugPrint("Backend rejectBooking error: $e");
    }

    _isLoading = false;

    if (_incomingBooking != null && _incomingBooking!.id == bookingId) {
      _incomingBooking = null;
    }
    notifyListeners();
    return true;
  }

  // Update Booking Progress Status
  Future<bool> updateBookingProgress(String status, {AuthProvider? authProvider}) async {
    if (_activeBooking == null) return false;
    
    _isLoading = true;
    notifyListeners();

    final bId = _activeBooking!.id;

    String dbStatus = status;
    if (status == 'on_the_way' || status == 'arrived' || status == 'started' || status == 'dp_paid' || status == 'completion_requested') {
      dbStatus = 'ongoing';
    } else if (status == 'closed') {
      dbStatus = 'completed';
    }

    Map<String, dynamic> updatedDetails = Map<String, dynamic>.from(_activeBooking?.additionalDetails ?? {});
    try {
      final dynamic queryId = int.tryParse(bId) ?? bId;
      final currentRec = await Supabase.instance.client
          .from('bookings')
          .select('additional_details')
          .eq('id', queryId)
          .maybeSingle();
      if (currentRec != null) {
        Map<String, dynamic> dbAdd = {};
        if (currentRec['additional_details'] is Map) {
          dbAdd = Map<String, dynamic>.from(currentRec['additional_details'] as Map);
        } else if (currentRec['additional_details'] is String) {
          try {
            final dec = jsonDecode(currentRec['additional_details'] as String);
            if (dec is Map) dbAdd = Map<String, dynamic>.from(dec);
          } catch (_) {}
        }
        dbAdd.forEach((key, val) {
          if (!updatedDetails.containsKey(key)) {
            updatedDetails[key] = val;
          }
        });
      }
    } catch (_) {}

    updatedDetails['sub_status'] = status;
    if (status == 'dp_paid') {
      updatedDetails['dp_paid'] = true;
    }
    if (status == 'arrived') {
      final startOtp = updatedDetails['start_otp'] ?? updatedDetails['otp'] ?? updatedDetails['security_pin'];
      String? servicePin = updatedDetails['service_pin']?.toString() ?? updatedDetails['service_otp']?.toString();
      if (servicePin == null || servicePin.isEmpty || servicePin == '1234') {
        if (startOtp != null && startOtp.toString().isNotEmpty && startOtp.toString() != '1234') {
          servicePin = startOtp.toString();
        } else {
          final rand = Random();
          servicePin = (rand.nextInt(9000) + 1000).toString();
        }
        updatedDetails['service_pin'] = servicePin;
        updatedDetails['start_service_pin'] = servicePin;
        updatedDetails['service_otp'] = servicePin;
        debugPrint("🆕 Driver arrived: Ensured Token 2 service_pin: $servicePin");
      }
    }

    final updatePayload = <String, dynamic>{
      'status': dbStatus,
      'additional_details': updatedDetails,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      if (int.tryParse(bId) != null) {
        await Supabase.instance.client
            .from('bookings')
            .update(updatePayload)
            .eq('id', int.parse(bId));
      } else {
        await Supabase.instance.client
            .from('bookings')
            .update(updatePayload)
            .eq('id', bId);
      }
      debugPrint("✅ Supabase updated booking $bId status to sub: $status, db: $dbStatus");
    } catch (e) {
      debugPrint("❌ Supabase updateBookingProgress error: $e");
    }

    try {
      await _bookingService.updateBookingStatus(bId, status);
    } catch (e) {
      debugPrint("Backend updateBookingProgress error: $e");
    }

    _isLoading = false;

    _activeBooking = _activeBooking!.copyWith(
      status: status,
      additionalDetails: updatedDetails,
    );
    if (status == 'closed' || status == 'cancelled' || status == 'paid' || updatedDetails['pelunasan_paid'] == true || updatedDetails['payment_status'] == 'LUNAS') {
      _lastCompletedBooking = _activeBooking;
      _activeBooking = null; // Clear active since session is closed or settled
    }
    notifyListeners();
    return true;
  }

  // Load Earnings
  Future<void> loadEarnings(String period) async {
    _isLoading = true;
    notifyListeners();

    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      final userId = authUser?.id ?? _currentUserId;

      if (userId != null && userId.isNotEmpty) {
        String? targetDriverId = _currentDriverId;
        if (targetDriverId == null || targetDriverId == 'active-driver') {
          final driverRow = await Supabase.instance.client
              .from('drivers')
              .select('id')
              .or('id.eq.$userId,user_id.eq.$userId')
              .maybeSingle();
          if (driverRow != null && driverRow['id'] != null) {
            targetDriverId = driverRow['id'].toString();
          }
        }

        var query = Supabase.instance.client.from('bookings').select('*');
        if (targetDriverId != null && targetDriverId.isNotEmpty && targetDriverId != 'active-driver') {
          query = query.or('driver_id.eq.$targetDriverId,user_id.eq.$userId');
        }

        final List<dynamic> rows = await query.order('created_at', ascending: false);

        if (rows.isNotEmpty) {
          final completed = rows.where((b) {
            final status = b['status']?.toString();
            final addDetails = b['additional_details'] is Map ? b['additional_details'] as Map : null;
            final subStatus = addDetails?['sub_status']?.toString();
            return status == 'completed' || status == 'paid' || subStatus == 'completed' || subStatus == 'paid';
          }).toList();

          double sum = 0.0;
          for (final b in completed) {
            final priceVal = b['total_price'] ?? 0;
            sum += priceVal is num ? priceVal.toDouble() : (double.tryParse(priceVal.toString()) ?? 0.0);
          }

          // Calculate pending escrow from active/ongoing bookings (DP held)
          double pendingEscrowSum = 0.0;
          final activeRows = rows.where((b) {
            final status = b['status']?.toString();
            final addDetails = b['additional_details'] is Map ? b['additional_details'] as Map : null;
            final subStatus = addDetails?['sub_status']?.toString();
            final isDpPaid = addDetails?['dp_paid'] == true || subStatus == 'dp_paid';
            final isReleased = addDetails?['payout_status'] == 'released' || addDetails?['driver_credited'] == true;
            return status != 'completed' && status != 'cancelled' && isDpPaid && !isReleased;
          }).toList();

          for (final b in activeRows) {
            final addDetails = b['additional_details'] is Map ? b['additional_details'] as Map : null;
            final dpVal = addDetails?['dp'] ?? addDetails?['dp_amount'] ?? b['escrow_balance'] ?? ((b['total_price'] ?? 0) * 0.5);
            final dpNum = dpVal is num ? dpVal.toDouble() : (double.tryParse(dpVal?.toString() ?? '') ?? 0.0);
            pendingEscrowSum += dpNum;
          }

          _totalEarnings = sum;
          _totalRides = completed.length;
          _pendingEscrowBalance = pendingEscrowSum;
          _earningsBookings = completed;
          _isLoading = false;
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint("Supabase loadEarnings error: $e");
    }

    final result = await _bookingService.getDriverEarnings(period);
    if (result['success'] == true) {
      _totalEarnings = (result['totalEarnings'] ?? 0.0).toDouble();
      _totalRides = (result['totalRides'] ?? 0).toInt();
      _pendingEscrowBalance = (result['pendingEscrow'] ?? 0.0).toDouble();
      _earningsBookings = result['bookings'] ?? [];
    } else {
      _errorMessage = result['message'];
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribeFromBookings();
    super.dispose();
  }
}
