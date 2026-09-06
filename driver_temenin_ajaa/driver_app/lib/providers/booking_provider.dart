import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/booking_service.dart';
import '../data/models/booking_model.dart';
import 'auth_provider.dart';

class BookingProvider extends ChangeNotifier {
  final BookingService _bookingService = BookingService();
  
  List<BookingModel> _bookings = [];
  BookingModel? _activeBooking;
  BookingModel? _incomingBooking;
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Earnings state
  double _totalEarnings = 0.0;
  int _totalRides = 0;
  List<dynamic> _earningsBookings = [];
  

  
  // Realtime subscription & Polling
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSubscription;
  Timer? _pollingTimer;

  List<BookingModel> get bookings => _bookings;
  BookingModel? get activeBooking => _activeBooking;
  BookingModel? get incomingBooking => _incomingBooking;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  double get totalEarnings => _totalEarnings;
  int get totalRides => _totalRides;
  List<dynamic> get earningsBookings => _earningsBookings;

  // Clear current incoming request
  void clearIncomingRequest() {
    _incomingBooking = null;
    notifyListeners();
  }

  // Set active booking manually (e.g. on click from list)
  void setActiveBooking(BookingModel? booking) {
    _activeBooking = booking;
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
      _pendingOffers = [];
      _incomingBooking = null;
      _activeBooking = null;
      notifyListeners();
      return;
    }

    final pendingList = data.where((b) {
      if (b['status'] != 'pending') return false;
      final bDriverId = b['driver_id']?.toString();
      
      // If driver_id is not assigned, it's an open offer broadcast
      if (bDriverId == null || bDriverId.isEmpty) return true;
      
      // Check against all known IDs for this driver
      if (_associatedDriverIds.contains(bDriverId)) return true;
      if (_currentDriverId != null && (_currentDriverId == bDriverId || _currentDriverId == 'active-driver')) return true;
      if (_currentUserId != null && _currentUserId == bDriverId) return true;
      
      // Check additional details for partner metadata
      final details = b['additional_details'];
      if (details is Map) {
        if (details['driverId']?.toString() == _currentDriverId || 
            details['driver_id']?.toString() == _currentDriverId ||
            details['driver_user_id']?.toString() == _currentUserId) {
          return true;
        }
      }
      
      return true; // Active driver receives incoming pending requests
    }).toList();

    final activeList = data.where((b) {
      final s = b['status']?.toString();
      final d = b['additional_details'] is Map ? b['additional_details'] as Map : null;
      final sub = d?['sub_status']?.toString();

      // Exclude finished or cancelled bookings from active list
      if (s == 'completed' || s == 'closed' || s == 'cancelled' || s == 'paid' ||
          sub == 'completed' || sub == 'closed' || sub == 'cancelled' || sub == 'paid') {
        return false;
      }

      return s == 'accepted' || 
             s == 'ongoing' || 
             sub == 'dp_paid' || 
             sub == 'on_the_way' || 
             sub == 'arrived' || 
             sub == 'started' || 
             sub == 'ongoing';
    }).toList();

    if (pendingList.isNotEmpty) {
      List<BookingModel> offers = [];
      for (final rawBooking in pendingList) {
        final clientId = rawBooking['user_id'];
        Map<String, dynamic>? clientData;
        try {
          final dbUser = await Supabase.instance.client
              .from('users')
              .select()
              .eq('id', clientId)
              .maybeSingle();
          clientData = dbUser;
        } catch (e) {
          debugPrint('Error fetching client details: $e');
        }
        offers.add(BookingModel.fromJson({
          ...rawBooking,
          'users': clientData,
        }));
      }
      _pendingOffers = offers;
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

    if (activeList.isNotEmpty) {
      Map<String, dynamic> rawBooking = activeList.first;
      if (_activeBooking != null) {
        final match = activeList.firstWhere(
          (b) => b['id'].toString() == _activeBooking!.id.toString(),
          orElse: () => activeList.first,
        );
        rawBooking = Map<String, dynamic>.from(match);
      } else {
        rawBooking = Map<String, dynamic>.from(activeList.first);
      }

      final dbStatus = rawBooking['status']?.toString();
      final addDetails = rawBooking['additional_details'] is Map
          ? rawBooking['additional_details'] as Map
          : (rawBooking['additionalDetails'] is Map ? rawBooking['additionalDetails'] as Map : null);
      final subStatus = addDetails?['sub_status']?.toString();
      final isDpPaid = addDetails?['dp_paid'] == true || subStatus == 'dp_paid' || rawBooking['dp_paid'] == true;
      final isAdvanced = subStatus == 'on_the_way' || 
                         subStatus == 'arrived' || 
                         subStatus == 'started' || 
                         subStatus == 'ongoing' || 
                         subStatus == 'completed' || 
                         subStatus == 'paid';

      String effectiveStatus = subStatus ?? dbStatus ?? 'pending';
      if (isDpPaid && !isAdvanced) {
        effectiveStatus = 'dp_paid';
      }
      rawBooking['status'] = effectiveStatus;

      final clientId = rawBooking['user_id'];
      Map<String, dynamic>? clientData;
      try {
        if (clientId != null) {
          final dbUser = await Supabase.instance.client
              .from('users')
              .select()
              .eq('id', clientId)
              .maybeSingle();
          clientData = dbUser;
        }
      } catch (e) {
        debugPrint('Error fetching active client details: $e');
      }
      _activeBooking = BookingModel.fromJson({
        ...rawBooking,
        'users': clientData,
      });
    } else {
      _activeBooking = null;
    }
    notifyListeners();
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

    // Polling fallback every 1 second for instant syncing
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final data = await Supabase.instance.client
            .from('bookings')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (data is List) {
          _processBookingsData(List<Map<String, dynamic>>.from(data));
        }
      } catch (e) {
        debugPrint("Error in driver polling: $e");
      }
    });
  }

  // Cancel subscription
  void unsubscribeFromBookings() {
    debugPrint('📡 Unsubscribed from Supabase bookings.');
    _realtimeSubscription?.cancel();
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
    if (matched != null) {
      _activeBooking = matched.copyWith(status: 'accepted');
    } else {
      _activeBooking = BookingModel(
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
      _activeBooking = matched.copyWith(
        status: 'accepted',
        totalPrice: finalPrice,
      );
    } else {
      _activeBooking = BookingModel(
        id: bookingId,
        userId: 'client-user',
        status: 'accepted',
        pickupLocation: 'Lokasi Penjemputan',
        dropoffLocation: 'Tujuan',
        duration: 3,
        totalPrice: finalPrice,
        createdAt: DateTime.now(),
      );
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

    final updatedDetails = Map<String, dynamic>.from(_activeBooking?.additionalDetails ?? {});
    updatedDetails['sub_status'] = status;
    if (status == 'dp_paid') {
      updatedDetails['dp_paid'] = true;
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
    if (status == 'completed' || status == 'closed' || status == 'cancelled' || status == 'paid') {
      _activeBooking = null; // Clear active since session is closed
    }
    notifyListeners();
    return true;
  }

  // Load Earnings
  Future<void> loadEarnings(String period) async {
    _isLoading = true;
    notifyListeners();

    final result = await _bookingService.getDriverEarnings(period);
    if (result['success'] == true) {
      _totalEarnings = result['totalEarnings'];
      _totalRides = result['totalRides'];
      _earningsBookings = result['bookings'];
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
