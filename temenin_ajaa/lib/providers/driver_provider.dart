import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/constants/api_constants.dart';

class DriverProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _driversStreamSub;

  List<Map<String, dynamic>> get drivers => _drivers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void subscribeToDriversRealtime() {
    _driversStreamSub?.cancel();
    try {
      _driversStreamSub = Supabase.instance.client
          .from('drivers')
          .stream(primaryKey: ['id'])
          .listen((_) {
            fetchDrivers();
          });
    } catch (e) {
      debugPrint("Error subscribing to drivers stream: $e");
    }
  }

  Future<void> fetchDrivers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // 1. Direct Supabase fetch (instant & real-time)
    try {
      final List<dynamic> dbDrivers = await Supabase.instance.client
          .from('drivers')
          .select('*, users(*)');

      if (dbDrivers.isNotEmpty) {
        _drivers = dbDrivers.map((d) {
          final user = d['users'] ?? {};
          final ratingVal = double.tryParse(d['rating']?.toString() ?? '5.0') ?? 5.0;
          final ridesVal = d['total_rides'] is int ? d['total_rides'] as int : (int.tryParse(d['total_rides']?.toString() ?? '0') ?? 0);
          
          String tier = 'Gold';
          if (ridesVal > 50 && ratingVal >= 4.9) {
            tier = 'Diamond';
          } else if (ridesVal > 20 && ratingVal >= 4.8) {
            tier = 'Platinum';
          } else if (ratingVal >= 4.5) {
            tier = 'Gold';
          } else if (ratingVal >= 4.0) {
            tier = 'Silver';
          } else {
            tier = 'Bronze';
          }

          return {
            'id': d['id'].toString(),
            'driverId': d['id'].toString(),
            'userId': d['user_id']?.toString(),
            'name': user['full_name'] ?? 'Driver Partner',
            'vehicle': d['vehicle_name'] ?? 'Motor',
            'vehicleType': d['vehicle_type'] ?? 'Motor',
            'rating': ratingVal.toStringAsFixed(1),
            'status': d['is_available'] == true ? 'Available' : 'Busy',
            'type': tier,
            'tier': tier,
            'image': user['avatar_url'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
            'tag': d['vehicle_type'] ?? 'Motor',
            'isAvailable': d['is_available'] == true,
            'price': d['price_per_hour'] ?? 50000,
            'kpi': 95,
            'gender': user['gender'] ?? 'Laki-laki',
            'trips': ridesVal,
            'plateNumber': d['plate_number'] ?? 'B 1234 ABC',
            'description': 'Driver profesional dan terverifikasi siap menemani perjalanan atau aktivitas Anda dengan aman dan nyaman.',
          };
        }).toList();
        _isLoading = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint("Direct Supabase fetchDrivers: $e");
    }

    // HTTP fallback if Supabase fails
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final url = Uri.parse('${ApiConstants.baseUrl}/api/drivers');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> driversList = data['data'];
          _drivers = driversList.map((d) {
            final user = d['users'] ?? {};
            final ratingVal = double.tryParse(d['rating']?.toString() ?? '5.0') ?? 5.0;
            final ridesVal = d['total_rides'] is int ? d['total_rides'] as int : (int.tryParse(d['total_rides']?.toString() ?? '0') ?? 0);
            
            String tier = 'Gold';
            if (ridesVal > 50 && ratingVal >= 4.9) {
              tier = 'Diamond';
            } else if (ridesVal > 20 && ratingVal >= 4.8) {
              tier = 'Platinum';
            } else if (ratingVal >= 4.5) {
              tier = 'Gold';
            } else if (ratingVal >= 4.0) {
              tier = 'Silver';
            } else {
              tier = 'Bronze';
            }
            
            return {
              'id': d['id'].toString(),
              'name': user['full_name'] ?? 'Driver',
              'vehicle': d['vehicle_name'] ?? 'Motor',
              'vehicleType': d['vehicle_type'] ?? 'Motor',
              'rating': ratingVal.toStringAsFixed(1),
              'status': d['is_available'] == true ? 'Available' : 'Busy',
              'type': tier,
              'tier': tier,
              'image': user['avatar_url'] != null && user['avatar_url'].toString().startsWith('/')
                  ? '${ApiConstants.baseUrl}${user['avatar_url']}'
                  : (user['avatar_url'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user['full_name'] ?? 'Driver')}'),
              'tag': d['vehicle_type'] ?? 'Motor',
              'isAvailable': d['is_available'] == true,
              'price': d['price_per_hour'] ?? 50000,
              'kpi': 95,
              'gender': user['gender'] ?? 'Laki-laki',
              'trips': ridesVal,
              'description': 'Driver profesional dan terverifikasi siap menemani perjalanan atau aktivitas Anda dengan aman dan nyaman.',
            };
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('HTTP fetchDrivers failed: $e, falling back to Supabase directly...');
    }

    // Direct Supabase fallback if empty or failed
    if (_drivers.isEmpty) {
      try {
        final List<dynamic> dbDrivers = await Supabase.instance.client
            .from('drivers')
            .select('*, users(*)');

        if (dbDrivers.isNotEmpty) {
          _drivers = dbDrivers.map((d) {
            final user = d['users'] ?? {};
            final ratingVal = double.tryParse(d['rating']?.toString() ?? '5.0') ?? 5.0;
            final ridesVal = d['total_rides'] is int ? d['total_rides'] as int : (int.tryParse(d['total_rides']?.toString() ?? '0') ?? 0);
            
            String tier = 'Gold';
            if (ridesVal > 50 && ratingVal >= 4.9) {
              tier = 'Diamond';
            } else if (ridesVal > 20 && ratingVal >= 4.8) {
              tier = 'Platinum';
            } else if (ridesVal > 4.5) {
              tier = 'Gold';
            } else if (ratingVal >= 4.0) {
              tier = 'Silver';
            } else {
              tier = 'Bronze';
            }

            return {
              'id': d['id'].toString(),
              'driverId': d['id'].toString(),
              'userId': d['user_id']?.toString(),
              'name': user['full_name'] ?? 'Driver Partner',
              'vehicle': d['vehicle_name'] ?? 'Motor',
              'vehicleType': d['vehicle_type'] ?? 'Motor',
              'rating': ratingVal.toStringAsFixed(1),
              'status': d['is_available'] == true ? 'Available' : 'Busy',
              'type': tier,
              'tier': tier,
              'image': user['avatar_url'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
              'tag': d['vehicle_type'] ?? 'Motor',
              'isAvailable': d['is_available'] == true,
              'price': d['price_per_hour'] ?? 50000,
              'kpi': 95,
              'gender': user['gender'] ?? 'Laki-laki',
              'trips': ridesVal,
              'plateNumber': d['plate_number'] ?? 'B 1234 ABC',
              'description': 'Driver profesional dan terverifikasi siap menemani perjalanan atau aktivitas Anda dengan aman dan nyaman.',
            };
          }).toList();
        }
      } catch (err) {
        debugPrint('Direct Supabase fetchDrivers also failed: $err');
      }
    }

    _isLoading = false;
    notifyListeners();
  }
}
