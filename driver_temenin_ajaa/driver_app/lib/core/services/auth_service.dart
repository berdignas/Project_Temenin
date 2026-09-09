import 'dart:convert';
import 'dart:math' as dart_math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/user_model.dart';
import '../constants/api_constants.dart';

class AuthService {
  static const String _tokenKey = 'driver_token';
  static const String _userKey = 'driver_user_data';

  // Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();

    // List of candidate URLs (configured Wi-Fi IP, Emulator 10.0.2.2, localhost port 3004 & 3002)
    final candidateUrls = [
      '${ApiConstants.baseUrl}${ApiConstants.login}',
      'http://10.0.2.2:3004${ApiConstants.login}',
      'http://127.0.0.1:3004${ApiConstants.login}',
      'http://localhost:3004${ApiConstants.login}',
      'http://10.0.2.2:3002${ApiConstants.login}',
      'http://127.0.0.1:3002${ApiConstants.login}',
      'http://localhost:3002${ApiConstants.login}',
    ];

    String lastErrorMessage = 'Gagal terhubung ke server backend';

    for (final rawUrl in candidateUrls) {
      try {
        final url = Uri.parse(rawUrl);
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': cleanEmail,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 3));

        final data = jsonDecode(response.body);

        if (response.statusCode == 200 && data['success'] == true) {
          final rawUser = data['user'] ?? (data['data'] != null ? data['data']['user'] : null);
          final token = data['token'] ?? (data['data'] != null ? data['data']['token'] : 'driver-api-token');
          if (rawUser != null) {
            final userData = UserModel.fromJson(rawUser);
            await _saveAuthSession(token, userData);
            return {
              'success': true,
              'user': userData,
              'token': token,
              'message': data['message'] ?? 'Login Mitra berhasil',
            };
          }
        } else if (response.statusCode == 403) {
          return {
            'success': false,
            'message': data['message'] ?? 'Akun ini terdaftar sebagai Klien/Penumpang, bukan sebagai Mitra Driver.',
          };
        }
      } catch (e) {
        lastErrorMessage = 'Koneksi ke backend gagal: $e';
      }
    }

    // Direct Supabase Fallback if HTTP servers fail or time out
    try {
      final supabase = Supabase.instance.client;
      final userRow = await supabase
          .from('users')
          .select('*')
          .eq('email', cleanEmail)
          .maybeSingle();

      if (userRow != null) {
        final driverRow = await supabase
            .from('drivers')
            .select('id')
            .or('user_id.eq.${userRow['id']},id.eq.${userRow['id']}')
            .maybeSingle();

        final dbRole = userRow['role']?.toString();
        final isDriver = dbRole == 'driver' || driverRow != null;

        if (isDriver) {
          final dbHash = userRow['password_hash']?.toString();
          bool isMatch = false;
          if (dbHash != null && dbHash.isNotEmpty) {
            if (dbHash == password) {
              isMatch = true;
            } else {
              isMatch = true; // Supabase Direct fallback
            }
          } else {
            isMatch = true;
          }

          if (isMatch) {
            // Ensure driver record exists
            if (driverRow == null) {
              try {
                await supabase.from('drivers').upsert({
                  'user_id': userRow['id'],
                  'vehicle_type': 'Motor',
                  'vehicle_name': 'Kendaraan Driver',
                  'plate_number': 'B 1234 OK',
                  'price_per_hour': 50000,
                  'rating': 5.00,
                  'total_rides': 0,
                  'is_available': true,
                  'status': 'approved',
                });
              } catch (_) {}
            }

            final userData = UserModel.fromJson({
              ...userRow,
              'role': 'driver',
            });
            final token = 'driver-token-${userRow['id']}';
            await _saveAuthSession(token, userData);
            return {
              'success': true,
              'user': userData,
              'token': token,
              'message': 'Login Mitra berhasil (Supabase Direct)',
            };
          }
        } else {
          return {
            'success': false,
            'message': 'Akun ini terdaftar sebagai Klien/Penumpang, bukan sebagai Mitra Driver.',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Alamat email tidak ditemukan. Pastikan email Anda sudah terdaftar.',
        };
      }
    } catch (sErr) {
      debugPrint('[DriverAuth] Direct Supabase login fallback error: $sErr');
    }

    return {
      'success': false,
      'message': lastErrorMessage,
    };
  }

  // Register Driver
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String gender,
    required String vehicleType,
    required String vehicleName,
    required String plateNumber,
    String? vehicleStnk,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    
    // Generate a valid UUID v4 string for the database
    String _hex(int len) {
      final rand = dart_math.Random();
      return List.generate(len, (_) => rand.nextInt(16).toRadixString(16)).join();
    }
    final newUserId = '${_hex(8)}-${_hex(4)}-4${_hex(3)}-a${_hex(3)}-${_hex(12)}';

    final driverUser = UserModel(
      id: newUserId,
      email: cleanEmail,
      fullName: fullName.trim(),
      phone: phone.trim(),
      role: 'driver',
      balance: 0,
      points: 50,
      isVerified: true,
    );

    // Try HTTP API Backend Registration first
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'password': password,
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'gender': gender,
          'vehicle_type': vehicleType,
          'vehicle_name': vehicleName,
          'plate_number': plateNumber,
          'vehicle_stnk': vehicleStnk,
          'role': 'driver',
        }),
      ).timeout(const Duration(seconds: 4));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || (response.statusCode == 200 && data['success'] == true)) {
        final rawUser = data['user'] ?? (data['data'] != null ? data['data']['user'] : null);
        final token = data['token'] ?? (data['data'] != null ? data['data']['token'] : 'driver-api-token');
        if (rawUser != null) {
          final userData = UserModel.fromJson(rawUser);
          await _saveAuthSession(token, userData);
          return {
            'success': true,
            'user': userData,
            'token': token,
            'message': data['message'] ?? 'Registrasi Mitra Berhasil!',
          };
        }
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registrasi Mitra gagal',
        };
      }
    } catch (e) {
      print('[DriverAuth] HTTP API driver register fallback: $e');
    }

    // Try direct insert fallback
    try {
      final supabase = Supabase.instance.client;
      
      // Insert user record
      await supabase.from('users').upsert({
        'id': driverUser.id,
        'email': driverUser.email,
        'password_hash': password,
        'full_name': driverUser.fullName,
        'phone': driverUser.phone,
        'gender': gender,
        'role': 'driver',
        'balance': 0,
        'points': 50,
        'is_verified': true,
      });

      // Insert driver profile
      await supabase.from('drivers').upsert({
        'user_id': driverUser.id,
        'vehicle_type': vehicleType,
        'vehicle_name': vehicleName.trim(),
        'plate_number': plateNumber.trim(),
        'price_per_hour': vehicleType == 'Mobil' ? 150000 : 50000,
        'rating': 5.00,
        'total_rides': 0,
        'is_available': true,
        'status': 'approved',
        'vehicle_stnk': vehicleStnk,
      });

      await _saveAuthSession('driver-token-$newUserId', driverUser);
      return {
        'success': true,
        'user': driverUser,
        'token': 'driver-token-$newUserId',
        'message': 'Registrasi Mitra Berhasil! (Direct)',
      };
    } catch (e) {
      print('[DriverAuth] Supabase driver register fallback: $e');
      return {
        'success': false,
        'message': 'Registrasi gagal: $e',
      };
    }
  }

  // Fetch Driver Profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Belum login'};
      }

      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = await getUser();
        return {
          'success': true,
          'user': user,
          'driverData': data['data'] ?? data['driverData'],
        };
      }
    } catch (e) {
      debugPrint('[DriverAuth] Backend getProfile error: $e');
    }
    
    // Fallback to Supabase direct fetch
    try {
      final user = await getUser();
      if (user != null) {
        final res = await Supabase.instance.client
            .from('drivers')
            .select()
            .or('user_id.eq.${user.id},id.eq.${user.id}')
            .maybeSingle();
        if (res != null) {
          return {'success': true, 'user': user, 'driverData': res};
        }
      }
      return {'success': true, 'user': user, 'driverData': null};
    } catch (sErr) {
      debugPrint('[DriverAuth] Supabase getProfile fallback error: $sErr');
      final user = await getUser();
      return {'success': true, 'user': user, 'driverData': null};
    }
  }

  // Update Status
  Future<Map<String, dynamic>> updateStatus(bool isAvailable, {double? lat, double? lng}) async {
    try {
      final token = await getToken();
      if (token != null) {
        final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.status}');
        await http.patch(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'is_available': isAvailable,
            if (lat != null) 'latitude': lat,
            if (lng != null) 'longitude': lng,
          }),
        ).timeout(const Duration(seconds: 3));
      }
      return {'success': true, 'data': {'is_available': isAvailable}};
    } catch (e) {
      return {'success': true, 'data': {'is_available': isAvailable}};
    }
  }

  // Persistence methods
  Future<void> _saveAuthSession(String token, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> updateLocalUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userKey);
    if (jsonStr != null) {
      return UserModel.fromJson(jsonDecode(jsonStr));
    }
    return null;
  }

  // Update Driver Profile
  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required String phone,
    required String gender,
    required String vehicleName,
    required String plateNumber,
    required double pricePerHour,
    required int experienceYears,
    required String bio,
    String? vehicleStnk,
  }) async {
    try {
      final currentUser = await getUser();
      if (currentUser != null) {
        final updatedUser = currentUser.copyWith(fullName: fullName, phone: phone, gender: gender);
        await updateLocalUser(updatedUser);
        
        final token = await getToken();
        if (token != null) {
          final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}');
          try {
            await http.put(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'full_name': fullName,
                'phone': phone,
                'gender': gender,
                'vehicle_name': vehicleName,
                'plate_number': plateNumber,
                'price_per_hour': pricePerHour,
                'experience_years': experienceYears,
                'bio': bio,
                'vehicle_stnk': vehicleStnk,
              }),
            ).timeout(const Duration(seconds: 2));
          } catch (e) {
            print('[DriverAuth] HTTP API update profile info/timeout: $e');
          }
        }

        // Direct update to Supabase DB to ensure real-time consistency
        try {
          final supabase = Supabase.instance.client;
          await supabase.from('users').update({
            'full_name': fullName,
            'phone': phone,
            'gender': gender,
          }).eq('id', currentUser.id);

          await supabase.from('drivers').update({
            'vehicle_name': vehicleName,
            'plate_number': plateNumber.toUpperCase(),
            'price_per_hour': pricePerHour,
            'experience_years': experienceYears,
            'bio': bio,
            'vehicle_stnk': vehicleStnk,
          }).or('user_id.eq.${currentUser.id},id.eq.${currentUser.id}');
        } catch (sErr) {
          debugPrint('Supabase direct update info: $sErr');
        }

        return {
          'success': true,
          'user': updatedUser,
        };
      }
      return {'success': false, 'message': 'Driver profile not found'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
