import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/constants/api_constants.dart';
import 'package:temenin_ajaa/core/services/auth_service.dart';

class ClientBookingProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _currentBooking;
  List<dynamic> _negotiations = [];
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSubscription;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get currentBooking => _currentBooking;
  List<dynamic> get negotiations => _negotiations;

  /// Subscribe to real-time updates for any booking belonging to the logged-in client
  void subscribeToClientBookings(String userId) {
    debugPrint('📡 Client Subscribing to Realtime Bookings for User ID: $userId');
    _realtimeSubscription?.cancel();

    try {
      _realtimeSubscription = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .listen((List<Map<String, dynamic>> data) async {
            debugPrint('⚡ Client Realtime: Received ${data.length} bookings for user $userId');
            if (data.isNotEmpty) {
              final activeBookings = data.where((b) {
                final s = b['status']?.toString();
                final addDetails = b['additional_details'] is Map ? b['additional_details'] as Map : null;
                final sub = addDetails?['sub_status']?.toString();

                if (s == 'completed' || s == 'closed' || s == 'cancelled' || s == 'paid' ||
                    sub == 'completed' || sub == 'closed' || sub == 'cancelled' || sub == 'paid') {
                  return false;
                }

                return s == 'pending' ||
                       s == 'accepted' ||
                       s == 'confirmed' ||
                       s == 'ongoing' ||
                       s == 'in_progress' ||
                       sub == 'dp_paid' ||
                       sub == 'on_the_way' ||
                       sub == 'arrived' ||
                       sub == 'started' ||
                       sub == 'ongoing';
              }).toList();

              if (activeBookings.isNotEmpty) {
                final latestRaw = activeBookings.last;
                final driverId = latestRaw['driver_id'];

                Map<String, dynamic>? driverData;
                if (driverId != null && driverId.toString().isNotEmpty) {
                  try {
                    final dbDriver = await Supabase.instance.client
                        .from('drivers')
                        .select('*, users(*)')
                        .eq('id', driverId)
                        .maybeSingle();
                    driverData = dbDriver;
                  } catch (e) {
                    debugPrint('Error fetching driver details for client booking: $e');
                  }
                }

                _currentBooking = {
                  ...latestRaw,
                  if (driverData != null) 'driver': driverData,
                };
              } else {
                _currentBooking = null;
              }
              notifyListeners();
            } else {
              _currentBooking = null;
              notifyListeners();
            }
          }, onError: (err) {
            debugPrint('❌ Client Realtime Error: $err');
          });
    } catch (e) {
      debugPrint('❌ Client Realtime Exception: $e');
    }
  }

  void unsubscribeFromBookings() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromBookings();
    super.dispose();
  }

  // 1. Create a Booking Request
  Future<Map<String, dynamic>> createBookingRequest(Map<String, dynamic> bookingData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/api/bookings');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'pickup_location': bookingData['pickupLocation'],
          'dropoff_location': bookingData['dropoffLocation'],
          'pickup_latitude': bookingData['pickupLatitude'],
          'pickup_longitude': bookingData['pickupLongitude'],
          'dropoff_latitude': bookingData['dropoffLatitude'],
          'dropoff_longitude': bookingData['dropoffLongitude'],
          'duration': bookingData['duration'] != null ? int.tryParse(bookingData['duration'].toString()) : 1,
          'total_price': bookingData['userInitialPrice'] ?? bookingData['serviceFee'] ?? 50000,
          'booking_date': DateTime.now().toIso8601String(),
          'additional_details': {
            'serviceType': bookingData['serviceType'] ?? 'freedom',
            'description': bookingData['description'] ?? '',
            'negotiation': true,
          }
        }),
      );

      final data = jsonDecode(response.body);
      _isLoading = false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _currentBooking = data['data'];
        notifyListeners();
        return {'success': true, 'booking': data['data']};
      } else {
        _errorMessage = data['message'] ?? 'Failed to create booking';
        notifyListeners();
        return {'success': false, 'message': _errorMessage};
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    }
  }

  // 2. Fetch Negotiations for current booking
  Future<void> fetchNegotiations(String bookingId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final url = Uri.parse('${ApiConstants.baseUrl}/api/bookings/$bookingId/negotiations');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _negotiations = data['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching negotiations: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 3. Accept a Negotiation Offer
  Future<bool> acceptNegotiation(String bookingId, String negotiationId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final url = Uri.parse('${ApiConstants.baseUrl}/api/bookings/$bookingId/negotiations/$negotiationId/accept');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      _isLoading = false;

      if (response.statusCode == 200) {
        _currentBooking = data['data'];
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'Failed to accept negotiation';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // 4. Update Booking Status
  Future<bool> updateStatus(String bookingId, String status) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final url = Uri.parse('${ApiConstants.baseUrl}/api/bookings/$bookingId/status');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentBooking = data['data'];
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      return false;
    }
  }
}
