import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/constants/api_constants.dart';
import 'package:temenin_ajaa/core/services/auth_service.dart';
import 'package:temenin_ajaa/core/utils/booking_date_helper.dart';

class ClientBookingProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _currentBooking;
  List<Map<String, dynamic>> _activeBookings = [];
  List<dynamic> _negotiations = [];
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSubscription;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get currentBooking => _currentBooking;
  List<Map<String, dynamic>> get activeBookings => List.unmodifiable(_activeBookings);
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
              final activeList = data.where((b) {
                final s = b['status']?.toString();
                final addDetails = b['additional_details'] is Map ? b['additional_details'] as Map : null;
                final sub = addDetails?['sub_status']?.toString();

                if (s == 'completed' || s == 'closed' || s == 'cancelled' || s == 'paid' || s == 'selesai' ||
                    sub == 'completed' || sub == 'closed' || sub == 'cancelled' || sub == 'paid' || sub == 'selesai' ||
                    addDetails?['pelunasan_paid'] == true || addDetails?['final_paid'] == true || addDetails?['has_reviewed'] == true || addDetails?['review'] != null || addDetails?['payment_status'] == 'LUNAS') {
                  return false;
                }

                return s == 'pending' ||
                       s == 'accepted' ||
                       s == 'confirmed' ||
                       s == 'ongoing' ||
                       s == 'in_progress' ||
                       s == 'started' ||
                       s == 'on_the_way' ||
                       s == 'arrived' ||
                       s == 'dp_paid' ||
                       sub == 'dp_paid' ||
                       sub == 'on_the_way' ||
                       sub == 'arrived' ||
                       sub == 'started' ||
                       sub == 'ongoing';
              }).toList();

              _activeBookings = List<Map<String, dynamic>>.from(activeList);

              if (activeList.isNotEmpty) {
                // Prioritize which booking to display as main currentBooking:
                // 1. Actively in trip (started, ongoing, on_the_way, arrived)
                // 2. Confirmed & DP Paid (dp_paid == true or sub_status == 'dp_paid')
                // 3. Accepted by driver (waiting DP)
                // 4. Pending request
                Map<String, dynamic>? selectedBooking;

                final ongoingTrips = activeList.where((b) {
                  final s = b['status']?.toString().toLowerCase();
                  final add = b['additional_details'] is Map ? b['additional_details'] as Map : null;
                  final sub = add?['sub_status']?.toString().toLowerCase();
                  return s == 'ongoing' && (sub == 'started' || sub == 'on_the_way' || sub == 'arrived' || sub == 'ongoing');
                }).toList();

                if (ongoingTrips.isNotEmpty) {
                  selectedBooking = ongoingTrips.first;
                } else {
                  final dpPaidBookings = activeList.where((b) {
                    final s = b['status']?.toString().toLowerCase();
                    final add = b['additional_details'] is Map ? b['additional_details'] as Map : null;
                    final sub = add?['sub_status']?.toString().toLowerCase();
                    return add?['dp_paid'] == true || sub == 'dp_paid' || s == 'dp_paid' || s == 'ongoing' || s == 'confirmed';
                  }).toList();

                  if (dpPaidBookings.isNotEmpty) {
                    // Sort by earliest scheduled date
                    dpPaidBookings.sort((a, b) {
                      final dtA = BookingDateHelper.extractScheduledDateTime(a) ?? DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
                      final dtB = BookingDateHelper.extractScheduledDateTime(b) ?? DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
                      return dtA.compareTo(dtB);
                    });
                    selectedBooking = dpPaidBookings.first;
                  } else {
                    final acceptedBookings = activeList.where((b) => b['status'] == 'accepted').toList();
                    if (acceptedBookings.isNotEmpty) {
                      selectedBooking = acceptedBookings.first;
                    } else {
                      selectedBooking = activeList.last;
                    }
                  }
                }

                final driverId = selectedBooking['driver_id'];
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
                  ...selectedBooking,
                  if (driverData != null) 'driver': driverData,
                };
              } else {
                _currentBooking = null;
              }
              notifyListeners();
            } else {
              _activeBookings = [];
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

  void clearBooking() {
    _currentBooking = null;
    notifyListeners();
  }

  void unsubscribeFromBookings() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _currentBooking = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribeFromBookings();
    super.dispose();
  }

  // 1. Create a Booking Request via REST API
  Future<Map<String, dynamic>> createBookingRequest(Map<String, dynamic> bookingData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      // Resolve driver ID ONLY if booking directly to a driver (NOT an open offer / freedom request / lelang)
      final bool isOpenOffer = bookingData['isOpenOffer'] == true || 
                               bookingData['is_open_offer'] == true || 
                               bookingData['serviceType'] == 'freedom_request' || 
                               bookingData['isDirectBooking'] == false;

      String? driverId;
      if (!isOpenOffer) {
        driverId = bookingData['driver_id'] ?? 
                   bookingData['driverId'] ?? 
                   bookingData['partnerId'] ?? 
                   bookingData['selectedPartner']?['id'] ?? 
                   bookingData['partner']?['id'];
      }

      String? validDriverId;
      if (driverId != null && 
          !driverId.startsWith('mock') && 
          !driverId.startsWith('drv-') && 
          !driverId.startsWith('d1') && 
          driverId.isNotEmpty) {
        validDriverId = driverId;
      }

      final totalPriceVal = bookingData['total_price'] ?? 
                            bookingData['totalPrice'] ?? 
                            bookingData['price'] ?? 
                            bookingData['totalPayment'] ?? 
                            bookingData['userInitialPrice'] ?? 
                            bookingData['serviceFee'] ?? 
                            50000;
      final numPrice = totalPriceVal is num ? totalPriceVal.toDouble() : (double.tryParse(totalPriceVal.toString()) ?? 50000.0);

      final pickup = bookingData['pickup_location'] ?? 
                     bookingData['pickupLocation'] ?? 
                     bookingData['pickup'] ?? 
                     bookingData['location'] ?? 
                     'Lokasi Penjemputan';

      final dropoff = bookingData['dropoff_location'] ?? 
                      bookingData['dropoffLocation'] ?? 
                      bookingData['destination'] ?? 
                      bookingData['location'] ?? 
                      'Lokasi Tujuan';

      final String unitStr = (bookingData['duration_unit'] ?? 
                              bookingData['unit'] ?? 
                              bookingData['additional_details']?['duration_unit'] ?? 
                              '').toString().toLowerCase();

      final int rawDurVal = int.tryParse(
        (bookingData['duration'] ?? 
         bookingData['call_duration_minutes'] ?? 
         bookingData['duration_minutes'] ?? 
         '60').toString()
      ) ?? 60;

      // Pure integer minutes standardization without heuristic multiplication
      int durationInMinutes;
      if (unitStr == 'hours' || unitStr == 'jam' || unitStr == 'hour') {
        durationInMinutes = rawDurVal * 60;
      } else {
        durationInMinutes = rawDurVal;
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/api/bookings');
      debugPrint('📡 Sending create booking request to $url (Driver: $validDriverId, Total: $numPrice, Duration: ${durationInMinutes}m)');

      // Resolve real scheduled booking date & time
      final scheduledDt = BookingDateHelper.extractScheduledDateTime(bookingData);
      final String bookingDateIso = scheduledDt?.toIso8601String() ?? 
                                    bookingData['booking_date']?.toString() ?? 
                                    bookingData['bookingDate']?.toString() ?? 
                                    DateTime.now().toIso8601String();

      final enrichedDetails = Map<String, dynamic>.from(bookingData);
      enrichedDetails['booking_date'] = bookingDateIso;
      enrichedDetails['bookingDate'] = bookingDateIso;

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'pickup_location': pickup,
          'dropoff_location': dropoff,
          'pickup_latitude': bookingData['pickup_latitude'] ?? bookingData['pickupLatitude'],
          'pickup_longitude': bookingData['pickup_longitude'] ?? bookingData['pickupLongitude'],
          'dropoff_latitude': bookingData['dropoff_latitude'] ?? bookingData['dropoffLatitude'],
          'dropoff_longitude': bookingData['dropoff_longitude'] ?? bookingData['dropoffLongitude'],
          'duration': durationInMinutes,
          'duration_unit': 'minutes',
          'total_price': numPrice,
          'booking_date': bookingDateIso,
          if (validDriverId != null) 'driver_id': validDriverId,
          'additional_details': enrichedDetails,
        }),
      );

      debugPrint('📡 Create booking response (${response.statusCode}): ${response.body}');
      final data = jsonDecode(response.body);
      _isLoading = false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _currentBooking = data['data'];
        notifyListeners();
        return {'success': true, 'booking': data['data'], 'data': data['data']};
      } else {
        _errorMessage = data['message'] ?? 'Gagal membuat pesanan';
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
