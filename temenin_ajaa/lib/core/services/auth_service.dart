import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


import 'package:temenin_ajaa/core/constants/api_constants.dart';
import 'package:temenin_ajaa/data/models/user_model.dart';

const String BASE_URL = ApiConstants.baseUrl;

class Log {
  static void d(String message) {
    if (kDebugMode) {
      print('[DEBUG] $message');
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

  Future<Map<String, dynamic>> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 5));

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
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Email atau password salah',
      };
    } catch (e) {
      Log.e('Login error: $e');
      return {
        'success': false,
        'message': 'Gagal menghubungkan ke server: $e',
      };
    }
  }

  Future<Map<String, dynamic>> loginWithPhone(String phone, String otp) async {
    final cleanPhone = _sanitizePhone(phone);
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/auth/login-otp');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': cleanPhone,
        }),
      ).timeout(const Duration(seconds: 5));

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
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Login gagal',
      };
    } catch (e) {
      Log.e('Login with phone error: $e');
      return {
        'success': false,
        'message': 'Gagal menghubungkan ke server: $e',
      };
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = _sanitizePhone(phone);
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'password': password,
          'full_name': fullName.trim(),
          'phone': cleanPhone,
          'role': 'client',
        }),
      ).timeout(const Duration(seconds: 5));

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
    File? avatarFile,
  }) async {
    final cleanPhone = _sanitizePhone(phone);
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/auth/register-otp');
      var request = http.MultipartRequest('POST', url);
      
      request.fields['phone'] = cleanPhone;
      request.fields['full_name'] = fullName.trim();
      request.fields['otp'] = otp;
      
      if (avatarFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profile_picture',
          avatarFile.path,
        ));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 5));
      final response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
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
      Log.e('Register with phone error: $e');
      return {
        'success': false,
        'message': 'Gagal menghubungkan ke server: $e',
      };
    }
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final cleanPhone = _sanitizePhone(phone);
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/auth/send-otp');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': cleanPhone}),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'OTP berhasil dikirim',
          'otp': data['otp'],
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal mengirim OTP',
      };
    } catch (e) {
      Log.e('Send OTP error: $e');
      return {
        'success': false,
        'message': 'Gagal menghubungkan ke server: $e',
      };
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final cleanPhone = _sanitizePhone(phone);
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/auth/verify-otp');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': cleanPhone,
          'otp': otp,
        }),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'OTP valid',
          'isRegistered': data['data'] != null ? data['data']['isRegistered'] : false,
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'OTP tidak valid',
      };
    } catch (e) {
      Log.e('Verify OTP error: $e');
      return {
        'success': false,
        'message': 'Gagal menghubungkan ke server: $e',
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