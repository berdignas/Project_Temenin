import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temenin_ajaa/core/constants/api_constants.dart';

class DriverProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> get drivers => _drivers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDrivers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/api/drivers');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> driversList = data['data'];
          _drivers = driversList.map((d) {
            // Mapping from API response to UI expected format
            // In API we already mapped it nicely if we were using the new controller,
            // but wait, we are using the existing `getAllDrivers` from `driverController.js`
            // Let's map it safely here.
            
            final user = d['users'] ?? {};
            
            return {
              'id': d['id'].toString(),
              'name': user['full_name'] ?? 'Driver',
              'vehicle': d['vehicle_name'] ?? 'Unknown Vehicle',
              'rating': d['rating']?.toString() ?? '5.0',
              'status': d['is_available'] == true ? 'Available' : 'Busy',
              'type': d['vehicle_type'] ?? 'Standard',
              'image': user['avatar_url'] != null && user['avatar_url'].toString().startsWith('/')
                  ? '${ApiConstants.baseUrl}${user['avatar_url']}'
                  : user['avatar_url'] ?? 'https://ui-avatars.com/api/?name=Driver',
              'tag': d['vehicle_type'] ?? 'Standard',
              'isAvailable': d['is_available'] == true,
              'price': d['price_per_hour'] ?? 50000,
              'kpi': 95, // Default dummy KPI if not available in DB
              'gender': user['gender'] ?? 'Laki-laki',
            };
          }).toList();
        } else {
          _errorMessage = data['message'] ?? 'Failed to load drivers';
        }
      } else {
        _errorMessage = 'Server returned status ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Failed to load drivers: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
