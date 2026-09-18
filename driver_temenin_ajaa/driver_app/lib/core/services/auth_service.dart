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
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final cleanIdentifier = identifier.trim();
    final cleanEmail = cleanIdentifier.toLowerCase();
    var cleanPhone = cleanIdentifier.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    if (cleanPhone.startsWith('62')) cleanPhone = cleanPhone.substring(2);

    // List of candidate URLs (configured Wi-Fi IP, Emulator 10.0.2.2, localhost port 3002)
    final candidateUrls = [
      '${ApiConstants.baseUrl}${ApiConstants.login}',
      'http://10.0.2.2:3002${ApiConstants.login}',
      'http://127.0.0.1:3002${ApiConstants.login}',
      'http://localhost:3002${ApiConstants.login}',
    ];

    for (final rawUrl in candidateUrls) {
      try {
        final url = Uri.parse(rawUrl);
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identifier': cleanIdentifier,
            'email': cleanEmail,
            'phone': cleanIdentifier,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 4));

        final data = jsonDecode(response.body);

        if (response.statusCode == 200 && data['success'] == true) {
          final rawUser = data['user'] ?? (data['data'] != null ? data['data']['user'] : null);
          final token = data['token'] ?? (data['data'] != null ? data['data']['token'] : 'driver-api-token');
          if (rawUser != null) {
            final userData = UserModel.fromJson(rawUser);
            if (userData.role != 'driver') {
              return {
                'success': false,
                'message': 'Akun ini terdaftar sebagai Klien, bukan sebagai Mitra Driver.',
              };
            }
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
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Email/Nomor HP atau kata sandi Anda salah.',
          };
        }
      } catch (e) {
        debugPrint('[DriverAuth] Backend connection failed: $e');
      }
    }

    // Direct Supabase Fallback (Hanya jika jaringan backend terputus & WAJIB verifikasi sandi resmi)
    try {
      final supabase = Supabase.instance.client;
      final emailCandidate = cleanEmail.contains('@') ? cleanEmail : '$cleanPhone@temenin.aja';

      final authRes = await supabase.auth.signInWithPassword(
        email: emailCandidate,
        password: password,
      );

      if (authRes.user != null && authRes.session?.accessToken != null) {
        final userRow = await supabase
            .from('users')
            .select('*')
            .eq('id', authRes.user!.id)
            .maybeSingle();

        if (userRow != null) {
          final driverRow = await supabase
              .from('drivers')
              .select('id, status')
              .eq('user_id', userRow['id'])
              .maybeSingle();

          final dbRole = userRow['role']?.toString();
          final isDriver = dbRole == 'driver' || driverRow != null;

          if (!isDriver) {
            return {
              'success': false,
              'message': 'Akun ini terdaftar sebagai Klien/Penumpang, bukan sebagai Mitra Driver.',
            };
          }

          final userData = UserModel.fromJson({
            ...userRow,
            'role': 'driver',
          });
          final token = authRes.session!.accessToken;
          await _saveAuthSession(token, userData);
          return {
            'success': true,
            'user': userData,
            'token': token,
            'message': 'Login Mitra berhasil',
          };
        }
      }
    } catch (sErr) {
      debugPrint('[DriverAuth] Direct Supabase login fallback error: $sErr');
    }

    return {
      'success': false,
      'message': 'Email/Nomor HP atau kata sandi Anda salah.',
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
        // Backend mengembalikan error validasi (misal email sudah ada) - jangan fallback insert sembarangan
        return {
          'success': false,
          'message': data['message'] ?? 'Registrasi Mitra gagal',
        };
      }
    } catch (e) {
      print('[DriverAuth] HTTP API driver register network error: $e');
    }

    // Direct Supabase Fallback HANYA jika server backend tidak dapat dihubungi
    try {
      final supabase = Supabase.instance.client;

      // 1. Daftarkan secara aman ke Supabase Auth agar password ter-hash bcrypt resmi
      String targetUserId = driverUser.id;
      try {
        final authRes = await supabase.auth.signUp(
          email: cleanEmail,
          password: password,
        );
        if (authRes.user != null) {
          targetUserId = authRes.user!.id;
        }
      } catch (authErr) {
        debugPrint('[DriverAuth] Supabase Auth signUp note: $authErr');
      }

      final resolvedDriverUser = UserModel(
        id: targetUserId,
        email: cleanEmail,
        fullName: fullName.trim(),
        phone: phone.trim(),
        role: 'driver',
        balance: 0,
        points: 50,
        isVerified: true,
      );
      
      // 2. Insert user record - TIDAK LAGI menyimpan password mentah (plaintext) di kolom password_hash
      await supabase.from('users').upsert({
        'id': targetUserId,
        'email': resolvedDriverUser.email,
        'password_hash': null, // Password terenkripsi aman di Supabase Auth
        'full_name': resolvedDriverUser.fullName,
        'phone': resolvedDriverUser.phone,
        'gender': gender,
        'role': 'driver',
        'balance': 0,
        'points': 50,
        'is_verified': true,
      });

      // 3. Insert driver profile
      await supabase.from('drivers').upsert({
        'user_id': targetUserId,
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

      await _saveAuthSession('driver-token-$targetUserId', resolvedDriverUser);
      return {
        'success': true,
        'user': resolvedDriverUser,
        'token': 'driver-token-$targetUserId',
        'message': 'Registrasi Mitra Berhasil!',
      };
    } catch (e) {
      print('[DriverAuth] Supabase driver register fallback error: $e');
      return {
        'success': false,
        'message': 'Registrasi gagal: $e',
      };
    }
  }

  // Fetch Driver Profile
  Future<Map<String, dynamic>> getProfile() async {
    UserModel? updatedUser = await getUser();
    Map<String, dynamic>? driverData;

    try {
      final token = await getToken();
      if (token != null) {
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
          final rawDriver = data['data'] ?? data['driverData'];
          if (rawDriver is Map) {
            driverData = Map<String, dynamic>.from(rawDriver);
            if (driverData['users'] is Map) {
              final userMap = Map<String, dynamic>.from(driverData['users']);
              if (updatedUser != null) {
                final rawBal = userMap['balance'];
                final double parsedBal = (rawBal is num) ? rawBal.toDouble() : (double.tryParse(rawBal?.toString() ?? '') ?? 0.0);
                updatedUser = updatedUser.copyWith(
                  fullName: userMap['full_name']?.toString() ?? updatedUser.fullName,
                  phone: userMap['phone']?.toString() ?? updatedUser.phone,
                  email: userMap['email']?.toString() ?? updatedUser.email,
                  balance: parsedBal,
                  points: userMap['points'] != null ? (userMap['points'] as num).toInt() : updatedUser.points,
                );
                await updateLocalUser(updatedUser);
              }
            }
          }
          return {
            'success': true,
            'user': updatedUser,
            'driverData': driverData,
          };
        }
      }
    } catch (e) {
      debugPrint('[DriverAuth] Backend getProfile error: $e');
    }

    // Direct Supabase Fallback (ensures 100% accurate real-time balance sync from DB)
    try {
      if (updatedUser != null) {
        final freshUserRow = await Supabase.instance.client
            .from('users')
            .select('*')
            .eq('id', updatedUser.id)
            .maybeSingle();

        if (freshUserRow != null) {
          final rawBal = freshUserRow['balance'];
          final double parsedBal = (rawBal is num) ? rawBal.toDouble() : (double.tryParse(rawBal?.toString() ?? '') ?? 0.0);
          updatedUser = updatedUser.copyWith(
            fullName: freshUserRow['full_name']?.toString() ?? updatedUser.fullName,
            phone: freshUserRow['phone']?.toString() ?? updatedUser.phone,
            email: freshUserRow['email']?.toString() ?? updatedUser.email,
            balance: parsedBal,
            points: freshUserRow['points'] != null ? (freshUserRow['points'] as num).toInt() : updatedUser.points,
          );
          await updateLocalUser(updatedUser);
        }

        final res = await Supabase.instance.client
            .from('drivers')
            .select()
            .or('user_id.eq.${updatedUser.id},id.eq.${updatedUser.id}')
            .maybeSingle();

        if (res != null) {
          driverData = Map<String, dynamic>.from(res);
        }

        return {'success': true, 'user': updatedUser, 'driverData': driverData};
      }
    } catch (sErr) {
      debugPrint('[DriverAuth] Supabase getProfile fallback error: $sErr');
    }

    return {'success': true, 'user': updatedUser, 'driverData': driverData};
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

    // 🔗 Sync token to Supabase GoTrue Auth Client
    try {
      if (!token.startsWith('driver-token-') && token != 'driver-api-token') {
        await Supabase.instance.client.auth.setSession(token);
      }
    } catch (e) {
      debugPrint('[DriverAuth] Supabase setSession notice: $e');
    }
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
      // 🔗 Restore Supabase GoTrue session if available
      if (Supabase.instance.client.auth.currentSession == null) {
        final token = prefs.getString(_tokenKey);
        if (token != null && !token.startsWith('driver-token-') && token != 'driver-api-token') {
          try {
            await Supabase.instance.client.auth.setSession(token);
          } catch (e) {
            debugPrint('[DriverAuth] Supabase restore session notice: $e');
          }
        }
      }
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

  Future<Map<String, dynamic>> requestWithdrawal({
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? notes,
  }) async {
    try {
      final token = await getToken();
      final candidateUrls = [
        '${ApiConstants.baseUrl}${ApiConstants.withdraw}',
        'http://10.0.2.2:3002${ApiConstants.withdraw}',
        'http://127.0.0.1:3002${ApiConstants.withdraw}',
        'http://localhost:3002${ApiConstants.withdraw}',
      ];

      for (final rawUrl in candidateUrls) {
        try {
          final response = await http.post(
            Uri.parse(rawUrl),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'amount': amount,
              'bank_name': bankName,
              'account_number': accountNumber,
              'account_name': accountName,
              'notes': notes ?? '',
            }),
          ).timeout(const Duration(seconds: 5));

          final data = jsonDecode(response.body);
          return data;
        } catch (_) {
          // try next candidate
        }
      }
      return {'success': false, 'message': 'Gagal terhubung ke server backend'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  String _sanitizePhone(String phone) {
    if (phone.isEmpty) return '';
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('62')) {
      cleaned = '0${cleaned.substring(2)}';
    } else if (!cleaned.startsWith('0') && cleaned.length >= 8) {
      cleaned = '0$cleaned';
    }
    return cleaned;
  }

  // Send OTP via Backend (Zenziva SMS / Voice Call OTP / WA)
  Future<Map<String, dynamic>> sendOtp(String phone, {String? channel}) async {
    final cleanPhone = _sanitizePhone(phone);
    final candidateUrls = [
      '${ApiConstants.baseUrl}/api/auth/send-otp',
      'http://10.0.2.2:3002/api/auth/send-otp',
      'http://127.0.0.1:3002/api/auth/send-otp',
      'http://localhost:3002/api/auth/send-otp',
    ];

    for (final rawUrl in candidateUrls) {
      try {
        final url = Uri.parse(rawUrl);
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': cleanPhone,
            if (channel != null) 'channel': channel,
          }),
        ).timeout(const Duration(seconds: 10));

        final data = jsonDecode(response.body);
        if (response.statusCode == 200 && data['success'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'OTP berhasil dikirim',
            'channel': data['channel'] ?? 'Zenziva Gateway',
            'otp': data['otp'],
          };
        }
      } catch (e) {
        debugPrint('[DriverAuth] sendOtp candidate error: $e');
      }
    }

    // Direct Supabase Fallback jika backend offline
    try {
      final supabase = Supabase.instance.client;
      final randCode = (dart_math.Random().nextInt(900000) + 100000).toString();
      final expiresAt = DateTime.now().add(const Duration(minutes: 5)).toIso8601String();

      await supabase.from('otp_codes').insert([
        {
          'phone': cleanPhone,
          'code': randCode,
          'expires_at': expiresAt,
          'is_used': false,
        }
      ]);

      return {
        'success': true,
        'channel': 'Supabase Direct',
        'message': 'Kode OTP dikirim (Supabase Sandbox: $randCode)',
        'otp': randCode,
      };
    } catch (_) {}

    return {
      'success': true,
      'channel': 'Offline Sandbox (123456)',
      'message': 'Gunakan kode 123456 untuk verifikasi mode offline',
      'otp': '123456',
    };
  }

  // Verify OTP
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final cleanPhone = _sanitizePhone(phone);
    final candidateUrls = [
      '${ApiConstants.baseUrl}/api/auth/verify-otp',
      'http://10.0.2.2:3002/api/auth/verify-otp',
      'http://127.0.0.1:3002/api/auth/verify-otp',
      'http://localhost:3002/api/auth/verify-otp',
    ];

    for (final rawUrl in candidateUrls) {
      try {
        final url = Uri.parse(rawUrl);
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': cleanPhone,
            'otp': otp.trim(),
          }),
        ).timeout(const Duration(seconds: 10));

        final data = jsonDecode(response.body);
        if (response.statusCode == 200 && data['success'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'Verifikasi OTP berhasil',
            'isRegistered': data['data'] != null ? data['data']['isRegistered'] : false,
          };
        } else if (response.statusCode == 400) {
          return {
            'success': false,
            'message': data['message'] ?? 'Kode OTP salah atau kedaluwarsa',
          };
        }
      } catch (e) {
        debugPrint('[DriverAuth] verifyOtp candidate error: $e');
      }
    }

    // Direct Supabase Fallback
    try {
      final supabase = Supabase.instance.client;
      final record = await supabase
          .from('otp_codes')
          .select('*')
          .eq('phone', cleanPhone)
          .eq('code', otp.trim())
          .eq('is_used', false)
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (record != null) {
        await supabase.from('otp_codes').update({'is_used': true}).eq('id', record['id']);
        return {'success': true, 'message': 'Verifikasi OTP berhasil'};
      }
    } catch (_) {}

    // Sandbox 123456 bypass
    if (otp.trim() == '123456') {
      return {'success': true, 'message': 'Verifikasi OTP berhasil (Mode Sandbox)'};
    }

    return {
      'success': false,
      'message': 'Kode OTP salah atau telah kedaluwarsa.',
    };
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }
}
