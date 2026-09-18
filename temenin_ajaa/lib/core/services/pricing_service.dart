import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class PricingService {
  static final PricingService _instance = PricingService._internal();
  factory PricingService() => _instance;
  PricingService._internal();

  // In-memory cached pricing configuration
  int _pricePerKm = 5000;
  int _pricePerKmSporty = 7500;
  int _minRidePrice = 15000;
  int _baseHourlyPrice = 50000;
  int _minHourlyPrice = 35000;
  int _sleepCallPackagePrice = 45000;
  int _virtualCounselingHourlyPrice = 35000;
  int _gamingBuddyPerMatchPrice = 15000;
  bool _allowNegotiationFlexibleOnly = true;
  bool _isFetched = false;

  int get pricePerKm => _pricePerKm;
  int get pricePerKmSporty => _pricePerKmSporty;
  int get minRidePrice => _minRidePrice;
  int get baseHourlyPrice => _baseHourlyPrice;
  int get minHourlyPrice => _minHourlyPrice;
  int get sleepCallPackagePrice => _sleepCallPackagePrice;
  int get virtualCounselingHourlyPrice => _virtualCounselingHourlyPrice;
  int get gamingBuddyPerMatchPrice => _gamingBuddyPerMatchPrice;
  bool get allowNegotiationFlexibleOnly => _allowNegotiationFlexibleOnly;
  bool get isFetched => _isFetched;

  /// Fetch latest official pricing set by Admin
  Future<void> fetchPricingConfig() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/bookings/pricing-config');
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final data = body['data'];
          if (data['price_per_km'] != null) {
            _pricePerKm = (data['price_per_km'] as num).toInt();
          }
          if (data['price_per_km_sporty'] != null) {
            _pricePerKmSporty = (data['price_per_km_sporty'] as num).toInt();
          }
          if (data['min_ride_price'] != null) {
            _minRidePrice = (data['min_ride_price'] as num).toInt();
          }
          if (data['base_hourly_price'] != null) {
            _baseHourlyPrice = (data['base_hourly_price'] as num).toInt();
          }
          if (data['min_hourly_price'] != null) {
            _minHourlyPrice = (data['min_hourly_price'] as num).toInt();
          }
          if (data['sleep_call_package_price'] != null) {
            _sleepCallPackagePrice = (data['sleep_call_package_price'] as num).toInt();
          }
          if (data['virtual_counseling_hourly_price'] != null) {
            _virtualCounselingHourlyPrice = (data['virtual_counseling_hourly_price'] as num).toInt();
          }
          if (data['gaming_buddy_per_match_price'] != null) {
            _gamingBuddyPerMatchPrice = (data['gaming_buddy_per_match_price'] as num).toInt();
          }
          if (data['allow_negotiation_flexible_only'] != null) {
            _allowNegotiationFlexibleOnly = data['allow_negotiation_flexible_only'] == true;
          }
          _isFetched = true;
          debugPrint('✅ [PricingService] Official pricing loaded: Rp $_pricePerKm/Km, Rp $_baseHourlyPrice/Jam');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [PricingService] Could not fetch pricing config, using default (Rp $_pricePerKm/Km): $e');
    }
  }
}
