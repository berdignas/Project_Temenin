import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/auth_service.dart';
import '../data/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _errorMessage;
  bool _isAvailable = false;
  Map<String, dynamic>? _driverProfileData;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;
  bool get isAvailable => _isAvailable;
  Map<String, dynamic>? get driverProfileData => _driverProfileData;

  // Check initial login status
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _authService.getToken();
      final savedUser = await _authService.getUser();
      
      if (token != null && savedUser != null) {
        _user = savedUser;
        _isAuthenticated = true;
        // Fetch fresh profile details from DB
        await refreshProfile();
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      _isAuthenticated = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  // Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);
      
      if (result['success'] == true) {
        _user = result['user'];
        _isAuthenticated = true;
        await refreshProfile();
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Login gagal';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Register Driver
  Future<bool> register({
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        gender: gender,
        vehicleType: vehicleType,
        vehicleName: vehicleName,
        plateNumber: plateNumber,
        vehicleStnk: vehicleStnk,
      );

      if (result['success'] == true) {
        _user = result['user'];
        _isAuthenticated = true;
        await refreshProfile();

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Refresh Profile
  Future<void> refreshProfile() async {
    try {
      final result = await _authService.getProfile();
      if (result['success'] == true) {
        if (result['user'] != null) {
          _user = result['user'];
        }
        if (result['driverData'] != null) {
          _driverProfileData = Map<String, dynamic>.from(result['driverData']);
          _isAvailable = _driverProfileData?['is_available'] ?? false;
        } else {
          _driverProfileData = {
            'vehicle_name': 'Belum diatur',
            'experience_years': 0,
            'rating': 5.0,
            'completed_trips': 0,
            'price_per_hour': 50000,
            'vehicle_stnk': '',
          };
        }
      } else {
        final errorMsg = result['message']?.toString().toLowerCase() ?? '';
        if (errorMsg.contains('not found') || errorMsg.contains('tidak ditemukan') || errorMsg.contains('unauthorized')) {
           debugPrint('[AuthProvider] User not found or invalid token, logging out...');
           await logout();
           return;
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] Error refreshing profile: $e');
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('not found') || errorMsg.contains('tidak ditemukan') || errorMsg.contains('unauthorized')) {
         await logout();
         return;
      }
    }
    notifyListeners();
  }

  // Update Driver Profile
  Future<bool> updateProfile({
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.updateProfile(
        fullName: fullName,
        phone: phone,
        gender: gender,
        vehicleName: vehicleName,
        plateNumber: plateNumber,
        pricePerHour: pricePerHour,
        experienceYears: experienceYears,
        bio: bio,
        vehicleStnk: vehicleStnk,
      );

      if (result['success'] == true) {
        if (result['user'] != null) {
          _user = result['user'];
        }
        if (result['driverData'] != null) {
          _driverProfileData = result['driverData'];
        } else {
          await refreshProfile();
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Gagal memperbarui profil';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Toggle Driver Online Status
  Future<bool> toggleAvailability() async {
    final target = !_isAvailable;
    
    // Simulate updating coordinate tracking (Senayan City Mall GPS coordinates)
    final double simLat = -6.2278; 
    final double simLng = 106.7972;

    try {
      final currentAuthUser = Supabase.instance.client.auth.currentUser;
      final driverId = _driverProfileData?['id'] as String? ?? _user?.id ?? currentAuthUser?.id;
      
      if (driverId != null) {
        await Supabase.instance.client
            .from('drivers')
            .update({
              'is_available': target,
              'status': 'approved',
              'latitude': simLat,
              'longitude': simLng,
            })
            .or('id.eq.$driverId,user_id.eq.$driverId');
        debugPrint("✅ Updated driver availability in Supabase: is_available = $target ($driverId)");
      }
    } catch (e) {
      debugPrint("⚠️ Error updating driver availability in Supabase: $e");
    }

    final result = await _authService.updateStatus(target, lat: simLat, lng: simLng);
    if (result['success'] == true) {
      _isAvailable = target;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }

  // Helper to upload any image file to Supabase Storage
  Future<String> uploadImageFile(File file, {String folder = 'uploads'}) async {
    try {
      final bytes = await file.readAsBytes();
      final fileName = '$folder/${folder}_${_user?.id ?? 'guest'}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      try {
        await Supabase.instance.client.storage
            .from('community-media')
            .uploadBinary(fileName, bytes, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));
        return Supabase.instance.client.storage.from('community-media').getPublicUrl(fileName);
      } catch (_) {
        try {
          await Supabase.instance.client.storage
              .from('public')
              .uploadBinary(fileName, bytes, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));
          return Supabase.instance.client.storage.from('public').getPublicUrl(fileName);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('ℹ️ Image upload fallback error: $e');
    }
    return file.path;
  }

  // Update Avatar Profile Photo
  Future<void> updateAvatar(String newAvatarUrl) async {
    if (_user != null) {
      String finalAvatarUrl = newAvatarUrl;

      // If local file, upload binary to Supabase Storage bucket 'community-media'
      if (!kIsWeb && File(newAvatarUrl).existsSync()) {
        finalAvatarUrl = await uploadImageFile(File(newAvatarUrl), folder: 'avatars');
      }

      _user = _user!.copyWith(avatarUrl: finalAvatarUrl);
      if (_driverProfileData != null) {
        _driverProfileData!['image'] = finalAvatarUrl;
      }
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('driver_user_data', jsonEncode(_user!.toJson()));
      } catch (e) {
        debugPrint('ℹ️ Local avatar cache error: $e');
      }

      try {
        await Supabase.instance.client
            .from('users')
            .update({'avatar_url': finalAvatarUrl})
            .eq('id', _user!.id);
      } catch (e) {
        debugPrint('ℹ️ Supabase users avatar update info: $e');
      }

      try {
        await Supabase.instance.client
            .from('drivers')
            .update({'image': finalAvatarUrl})
            .eq('user_id', _user!.id);
      } catch (e) {
        debugPrint('ℹ️ Supabase drivers image update info: $e');
      }
    }
  }

  // Logout
  Future<void> logout() async {
    // Set status to offline before logout
    if (_isAvailable) {
      await _authService.updateStatus(false);
    }
    await _authService.logout();
    _user = null;
    _isAuthenticated = false;
    _isAvailable = false;
    _driverProfileData = null;
    notifyListeners();
  }
}
