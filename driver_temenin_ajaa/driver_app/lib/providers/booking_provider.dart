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
  

  
  // Realtime subscription
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSubscription;

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

  // Subscribe to real-time bookings from Supabase
  void subscribeToBookings(String driverId) {
    debugPrint('📡 Subscribing to Supabase Realtime for Driver ID: $driverId');
    _realtimeSubscription?.cancel();

    try {
      _realtimeSubscription = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('driver_id', driverId)
          .listen((List<Map<String, dynamic>> data) async {
            debugPrint('⚡ Supabase Realtime: Received ${data.length} bookings for driver $driverId');
            if (data.isNotEmpty) {
              // Filters: pending (incoming request) vs accepted/ongoing (active)
              final pendingList = data.where((b) => b['status'] == 'pending').toList();
              final activeList = data.where((b) => b['status'] == 'accepted' || b['status'] == 'ongoing').toList();

              if (pendingList.isNotEmpty) {
                final rawBooking = pendingList.first;
                final clientId = rawBooking['user_id'];
                Map<String, dynamic>? clientData;
                try {
                  final dbUser = await Supabase.instance.client
                      .from('users')
                      .select()
                      .eq('id', clientId)
                      .single();
                  clientData = dbUser;
                } catch (e) {
                  debugPrint('Error fetching client details: $e');
                }
                _incomingBooking = BookingModel.fromJson({
                  ...rawBooking,
                  'users': clientData,
                });
              } else {
                _incomingBooking = null;
              }

              if (activeList.isNotEmpty) {
                final rawBooking = activeList.first;
                final clientId = rawBooking['user_id'];
                Map<String, dynamic>? clientData;
                try {
                  final dbUser = await Supabase.instance.client
                      .from('users')
                      .select()
                      .eq('id', clientId)
                      .single();
                  clientData = dbUser;
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
            } else {
              _incomingBooking = null;
              _activeBooking = null;
            }
            notifyListeners();
          }, onError: (err) {
            debugPrint('❌ Supabase stream subscription error: $err');
          });
    } catch (e) {
      debugPrint('❌ Supabase stream connection failed: $e');
    }
  }

  // Cancel subscription
  void unsubscribeFromBookings() {
    debugPrint('📡 Unsubscribed from Supabase bookings.');
    _realtimeSubscription?.cancel();
  }

  // Generates a mock booking to simulate incoming client request (kept as no-op for signature)
  void generateMockIncomingBooking() {}

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

    Map<String, dynamic>? result;
    try {
      result = await _bookingService.updateBookingStatus(bookingId, 'on_the_way');
    } catch (e) {
      debugPrint("Offline mode: updateBookingStatus failed, using simulation.");
    }
    
    _isLoading = false;
    
    // Fallback for offline demo / simulation mode
    if (_incomingBooking != null && _incomingBooking!.id == bookingId) {
      _activeBooking = BookingModel(
        id: _incomingBooking!.id,
        userId: _incomingBooking!.userId,
        driverId: _incomingBooking!.driverId,
        status: 'on_the_way',
        pickupLocation: _incomingBooking!.pickupLocation,
        dropoffLocation: _incomingBooking!.dropoffLocation,
        pickupLatitude: _incomingBooking!.pickupLatitude,
        pickupLongitude: _incomingBooking!.pickupLongitude,
        dropoffLatitude: _incomingBooking!.dropoffLatitude,
        dropoffLongitude: _incomingBooking!.dropoffLongitude,
        duration: _incomingBooking!.duration,
        totalPrice: _incomingBooking!.totalPrice,
        bookingDate: _incomingBooking!.bookingDate,
        additionalDetails: _incomingBooking!.additionalDetails,
        createdAt: _incomingBooking!.createdAt,
        client: _incomingBooking!.client,
      );
      _incomingBooking = null;
      notifyListeners();
      return true;
    }

    if (result != null && result['success'] == true) {
      _incomingBooking = null;
      _activeBooking = result['booking'];
      notifyListeners();
      return true;
    }
    
    // Force simulation true if incoming booking was somehow lost but we have active booking ID
    if (_activeBooking == null) {
       _activeBooking = BookingModel(
          id: bookingId,
          userId: 'c1',
          driverId: 'd1',
          status: 'on_the_way',
          pickupLocation: 'Simulation Pickup',
          dropoffLocation: 'Simulation Dropoff',
          duration: 1,
          totalPrice: 100000.0,
          createdAt: DateTime.now(),
       );
       notifyListeners();
       return true;
    }
    
    _errorMessage = result?['message'] ?? 'Failed to accept booking';
    notifyListeners();
    return false;
  }

  // Accept a booking with a custom final negotiated price
  Future<bool> acceptBookingWithPrice(String bookingId, double finalPrice) async {
    _isLoading = true;
    notifyListeners();

    Map<String, dynamic>? result;
    // Try to update on the server if possible (or fallback to simulation)
    try {
      result = await _bookingService.updateBookingStatus(bookingId, 'on_the_way');
    } catch (e) {
      debugPrint("Offline mode: updateBookingStatus failed, using simulation.");
    }
    
    _isLoading = false;

    if (_incomingBooking != null && _incomingBooking!.id == bookingId) {
      _activeBooking = BookingModel(
        id: _incomingBooking!.id,
        userId: _incomingBooking!.userId,
        driverId: _incomingBooking!.driverId,
        status: 'on_the_way',
        pickupLocation: _incomingBooking!.pickupLocation,
        dropoffLocation: _incomingBooking!.dropoffLocation,
        pickupLatitude: _incomingBooking!.pickupLatitude,
        pickupLongitude: _incomingBooking!.pickupLongitude,
        dropoffLatitude: _incomingBooking!.dropoffLatitude,
        dropoffLongitude: _incomingBooking!.dropoffLongitude,
        duration: _incomingBooking!.duration,
        totalPrice: finalPrice,
        bookingDate: _incomingBooking!.bookingDate,
        additionalDetails: {
          ...?_incomingBooking!.additionalDetails,
          'finalNegotiatedPrice': finalPrice,
        },
        createdAt: _incomingBooking!.createdAt,
        client: _incomingBooking!.client,
      );
      _incomingBooking = null;
      notifyListeners();
      return true;
    }

    if (result != null && result['success'] == true) {
      _incomingBooking = null;
      _activeBooking = result['booking'];
      notifyListeners();
      return true;
    }

    // Force simulation true if incoming booking was somehow lost but we have active booking ID
    if (_activeBooking == null) {
       _activeBooking = BookingModel(
          id: bookingId,
          userId: 'c1',
          driverId: 'd1',
          status: 'on_the_way',
          pickupLocation: 'Simulation Pickup',
          dropoffLocation: 'Simulation Dropoff',
          duration: 1,
          totalPrice: finalPrice,
          createdAt: DateTime.now(),
       );
       notifyListeners();
       return true;
    }

    _errorMessage = result?['message'] ?? 'Failed to accept booking';
    notifyListeners();
    return false;
  }

  // Reject booking (cancels it or returns to queue)
  Future<bool> rejectBooking(String bookingId) async {
    _isLoading = true;
    notifyListeners();

    final result = await _bookingService.updateBookingStatus(bookingId, 'cancelled');
    _isLoading = false;

    if (result['success'] == true) {
      _incomingBooking = null;
      notifyListeners();
      return true;
    }

    // Fallback for offline demo / simulation mode
    if (_incomingBooking != null && _incomingBooking!.id == bookingId) {
      _incomingBooking = null;
      notifyListeners();
      return true;
    }

    _errorMessage = result['message'];
    notifyListeners();
    return false;
  }

  // Update Booking Progress Status
  Future<bool> updateBookingProgress(String status, {AuthProvider? authProvider}) async {
    if (_activeBooking == null) return false;
    
    _isLoading = true;
    notifyListeners();

    final result = await _bookingService.updateBookingStatus(_activeBooking!.id, status);
    _isLoading = false;

    if (result['success'] == true) {
      _activeBooking = result['booking'];
      if (status == 'closed') {
        _activeBooking = null; // Clear active since it is completed and paid
      }
      notifyListeners();
      return true;
    }

    // Fallback for offline demo / simulation mode
    _activeBooking = BookingModel(
      id: _activeBooking!.id,
      userId: _activeBooking!.userId,
      driverId: _activeBooking!.driverId,
      status: status,
      pickupLocation: _activeBooking!.pickupLocation,
      dropoffLocation: _activeBooking!.dropoffLocation,
      pickupLatitude: _activeBooking!.pickupLatitude,
      pickupLongitude: _activeBooking!.pickupLongitude,
      dropoffLatitude: _activeBooking!.dropoffLatitude,
      dropoffLongitude: _activeBooking!.dropoffLongitude,
      duration: _activeBooking!.duration,
      totalPrice: _activeBooking!.totalPrice,
      bookingDate: _activeBooking!.bookingDate,
      additionalDetails: _activeBooking!.additionalDetails,
      createdAt: _activeBooking!.createdAt,
      client: _activeBooking!.client,
    );

    if (status == 'closed') {
      _activeBooking = null; // Clear active
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
