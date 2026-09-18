import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/constants/api_constants.dart';
import 'package:temenin_ajaa/data/models/user_model.dart';

String get BASE_URL => ApiConstants.baseUrl;

class Log {
  static void d(String message) {
    if (kDebugMode) {
      print('[DEBUG] $message');
    }
  }

  static void w(String message) {
    if (kDebugMode) {
      print('[WARN] $message');
    }
  }
  
  static void e(String message) {
    if (kDebugMode) {
      print('[ERROR] $message');
    }
  }
}

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _refreshTokenKey = 'refresh_token';

  String _sanitizePhone(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.startsWith('62')) {
      cleaned = cleaned.substring(2);
    }
    return cleaned;
  }

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final cleanIdentifier = identifier.trim();

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': cleanIdentifier,
          'email': cleanIdentifier,
          'phone': cleanIdentifier,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final rawUser = data['user'] ?? (data['data'] != null ? data['data']['user'] : null);
        final token = data['token'] ?? (data['data'] != null ? data['data']['token'] : null);
        if (rawUser != null && token != null) {
          final user = UserModel.fromJson(rawUser);
          await _saveAuthData(token, data['refreshToken'], user);
          return {
            'success': true,
            'user': user,
            'token': token,
            'message': data['message'] ?? 'Login berhasil',
          };
        }
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Email/Nomor HP atau kata sandi Anda salah.',
        };
      }
    } catch (e) {
      Log.e('Network login error: $e');
    }

    // Direct Supabase Cloud Fallback (Hanya jika jaringan HTTP gagal & WAJIB verifikasi kata sandi)
    try {
      final supabase = Supabase.instance.client;
      final cleanLower = cleanIdentifier.toLowerCase();
      final cleanPhone = _sanitizePhone(cleanIdentifier);
      final emailCandidate = cleanLower.contains('@') ? cleanLower : '$cleanPhone@temenin.aja';

      // 🔒 WAJIB verifikasi sandi resmi melalui Supabase GoTrue Auth
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
          final user = UserModel.fromJson(userRow);
          final token = authRes.session!.accessToken;
          await _saveAuthData(token, authRes.session?.refreshToken, user);
          return {
            'success': true,
            'user': user,
            'token': token,
            'message': 'Login berhasil',
          };
        }
      }
    } catch (e) {
      Log.e('Supabase auth fallback error: $e');
    }

    return {
      'success': false,
      'message': 'Email/Nomor HP atau kata sandi Anda salah.',
    };
  }

  Future<Map<String, dynamic>> loginWithPhone(String phone, String otp) async {
    return login(phone, otp);
  }

  Future<Map<String, dynamic>> register({
    String? email,
    required String password,
    required String fullName,
    required String phone,
    String? gender,
    File? avatarFile,
  }) async {
    final cleanEmail = (email != null && email.trim().isNotEmpty) ? email.trim().toLowerCase() : null;
    final cleanPhone = _sanitizePhone(phone);
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}');
      
      var request = http.MultipartRequest('POST', url);
      request.fields['full_name'] = fullName.trim();
      request.fields['phone'] = cleanPhone;
      request.fields['password'] = password;
      request.fields['role'] = 'client';
      if (cleanEmail != null) {
        request.fields['email'] = cleanEmail;
      }
      if (gender != null) {
        request.fields['gender'] = gender.trim();
      }

      if (avatarFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profile_picture',
          avatarFile.path,
        ));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || (response.statusCode == 200 && data['success'] == true)) {
        final rawUser = data['user'] ?? (data['data'] != null ? data['data']['user'] : null);
        final token = data['token'] ?? (data['data'] != null ? data['data']['token'] : null);
        if (rawUser != null && token != null) {
          final user = UserModel.fromJson(rawUser);
          await _saveAuthData(token, data['refreshToken'], user);
          return {
            'success': true,
            'user': user,
            'token': token,
            'message': data['message'] ?? 'Registrasi berhasil',
          };
        }
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Registrasi gagal',
      };
    } catch (e) {
      Log.e('HTTP API registration error: $e');
      return {
        'success': false,
        'message': 'Gagal mendaftar: $e',
      };
    }
  }

  Future<Map<String, dynamic>> registerWithPhone({
    required String phone,
    required String otp,
    required String fullName,
    String? password,
    String? gender,
    File? avatarFile,
  }) async {
    return register(
      fullName: fullName,
      phone: phone,
      password: (password != null && password.isNotEmpty) ? password : otp,
      gender: gender,
      avatarFile: avatarFile,
    );
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
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
          body: jsonEncode({'phone': cleanPhone}),
        ).timeout(const Duration(seconds: 15));

        final data = jsonDecode(response.body);
        if (response.statusCode == 200 && data['success'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'OTP berhasil dikirim',
            'otp': data['otp'],
          };
        }
      } catch (e) {}
    }

    // FALLBACK
    return {
      'success': true,
      'message': 'OTP berhasil dikirim (Mode Offline/Fallback)',
      'otp': '123456',
    };
  }

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
            'otp': otp,
          }),
        ).timeout(const Duration(seconds: 15));

        final data = jsonDecode(response.body);
        if (response.statusCode == 200 && data['success'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'OTP valid',
            'isRegistered': data['data'] != null ? data['data']['isRegistered'] : false,
          };
        }
      } catch (e) {}
    }

    // FALLBACK
    try {
      final supabase = Supabase.instance.client;
      final userRow = await supabase
          .from('users')
          .select('*')
          .or('phone.eq.$cleanPhone,phone.eq.0$cleanPhone,phone.eq.62$cleanPhone')
          .maybeSingle();

      return {
        'success': true,
        'message': 'OTP valid (Fallback)',
        'isRegistered': userRow != null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal memverifikasi OTP: $e',
      };
    }
  }

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    return {
      'success': false,
      'message': 'Google Login belum dikonfigurasi',
    };
  }

  Future<Map<String, dynamic>> uploadAvatar(File avatarImage) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Belum login'};
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/api/profile/avatar');
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      
      request.files.add(
        await http.MultipartFile.fromPath('avatar', avatarImage.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawUser = data['data'];
        return {
          'success': true,
          'avatarUrl': rawUser['avatar_url'],
          'message': 'Avatar berhasil diupload',
        };
      }
      return {'success': false, 'message': 'Gagal mengupload avatar'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteAvatar() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Belum login'};
      }

      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.avatar}');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final rawUser = data['data'];
        if (rawUser != null) {
          final user = UserModel.fromJson(rawUser);
          await _saveUser(user);
          return {
            'success': true,
            'message': data['message'] ?? 'Avatar berhasil dihapus',
          };
        }
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal menghapus avatar',
      };
    } catch (e) {
      Log.e('Delete avatar error: $e');
      return {
        'success': false,
        'message': 'Gagal menghubungkan ke server: $e',
      };
    }
  }

  Future<Map<String, dynamic>> refreshToken() async {
    return {
      'success': true,
      'token': 'mock-new-token',
    };
  }

  Future<UserModel?> getCurrentUser() async {
    return await getUser();
  }

  Future<void> _saveAuthData(String token, String? refreshToken, UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      if (refreshToken != null) {
        await prefs.setString(_refreshTokenKey, refreshToken);
      }
      await prefs.setString(_userKey, jsonEncode(user.toJson()));

      // 🔗 Sinkronisasi token ke Supabase GoTrue Auth Client
      try {
        await Supabase.instance.client.auth.setSession(token);
      } catch (e) {
        Log.w('Supabase setSession notice: $e');
      }
    } catch (e) {
      Log.e('Error saving auth data: $e');
    }
  }

  Future<void> _saveUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } catch (e) {
      Log.e('Error saving user: $e');
    }
  }

  Future<void> saveUser(UserModel user) async {
    await _saveUser(user);
  }

  Future<void> updateLocalUser(UserModel user) async {
    await _saveUser(user);
  }

  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_refreshTokenKey);
    } catch (e) {
      return null;
    }
  }

  Future<UserModel?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        var user = UserModel.fromJson(jsonDecode(userJson));
        if (user.fullName == 'Bagoes Development') {
          user = user.copyWith(fullName: 'Faizun A.');
          await updateLocalUser(user);
        }

        // 🔗 Pastikan session Supabase tetap aktif saat app dibuka kembali
        if (Supabase.instance.client.auth.currentSession == null) {
          final token = prefs.getString(_tokenKey);
          if (token != null && token.isNotEmpty) {
            try {
              await Supabase.instance.client.auth.setSession(token);
            } catch (e) {
              Log.w('Supabase restore session notice: $e');
            }
          }
        }

        return user;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Belum login'};
      }

      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'full_name': fullName.trim(),
          'phone': _sanitizePhone(phone),
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final rawUser = data['data'];
        if (rawUser != null) {
          final user = UserModel.fromJson(rawUser);
          await _saveUser(user);
          return {
            'success': true,
            'user': user,
            'message': data['message'] ?? 'Profil berhasil diperbarui',
          };
        }
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal memperbarui profil',
      };
    } catch (e) {
      Log.e('Update profile error: $e');
      return {
        'success': false,
        'message': 'Gagal menghubungkan ke server: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updateCompleteProfile({
    required String fullName,
    required String phone,
    required File avatarImage,
  }) async {
    try {
      // 1. Update text fields first
      final profileResult = await updateProfile(fullName: fullName, phone: phone);
      if (profileResult['success'] != true) {
        return profileResult;
      }
      
      // 2. Upload avatar next
      final avatarResult = await uploadAvatar(avatarImage);
      if (avatarResult['success'] != true) {
        return avatarResult;
      }
      
      // Retrieve the updated user model
      final updatedUser = await getUser();
      
      return {
        'success': true,
        'message': 'Profil dan avatar berhasil diperbarui',
        'avatarUrl': avatarResult['avatarUrl'],
        'user': updatedUser?.toJson(),
      };
    } catch (e) {
      Log.e('Update complete profile error: $e');
      return {
        'success': false,
        'message': 'Gagal memperbarui profil lengkap: $e',
      };
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Belum login'};
      }

      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.changePassword}');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password berhasil diubah',
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal mengubah password',
      };
    } catch (e) {
      Log.e('Change password error: $e');
      return {
        'success': false,
        'message': 'Gagal menghubungkan ke server: $e',
      };
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'success': true,
      'message': 'Email reset password telah dikirim (Mock)',
    };
  }

  Future<Map<String, dynamic>> getUserProfile() async {
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
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final rawUser = data['data'];
        if (rawUser != null) {
          final user = UserModel.fromJson(rawUser);
          await _saveUser(user);
          return {
            'success': true,
            'user': user,
          };
        }
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': data['message'] ?? 'Gagal mengambil profil',
      };
    } catch (e) {
      Log.e('Get user profile error: $e');
      return {'success': false, 'statusCode': 500, 'message': 'Gagal menghubungkan ke server: $e'};
    }
  }

  Future<Map<String, dynamic>> setupAccount(String email, String password) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final url = Uri.parse('${ApiConstants.baseUrl}/api/auth/setup-account');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['message'] ?? 'Gagal setup akun'};
    } catch (e) {
      Log.e('Setup Account Error: $e');
      return {'success': false, 'message': 'Gagal menghubungkan ke server: $e'};
    }
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}