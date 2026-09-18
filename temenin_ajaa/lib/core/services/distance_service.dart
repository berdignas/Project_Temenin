// lib/core/services/distance_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:temenin_ajaa/core/config/mapbox_config.dart';
import 'package:temenin_ajaa/core/services/location_service.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/interactive_map_picker_screen.dart';

/// Service untuk kalkulasi jarak rute jalan raya dan pencarian lokasi real-time.
///
/// Arsitektur:
/// 1. Jarak Rute: Mapbox Directions API (dengan fallback otomatis ke OSRM & Haversine)
/// 2. Pencarian Tempat Detail: Mapbox Geocoding API dengan Proximity GPS (POI, Cafe, Resto, Venue, Alamat) + Fallback Photon & Nominatim
/// 3. Reverse Geocoding: Mapbox Reverse Geocoding API (dengan fallback otomatis ke Photon & Nominatim OSM)
class DistanceService {
  static const String _mapboxDirectionsBaseUrl = 'https://api.mapbox.com/directions/v5/mapbox/driving';
  static const String _mapboxGeocodingBaseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';
  static const String _osrmBaseUrl = 'https://router.project-osrm.org/route/v1/driving';
  static const String _photonBaseUrl = 'https://photon.komoot.io/api';
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org/search';

  /// 1. Menghitung jarak rute jalan nyata (KM) & estimasi durasi (Menit) antara dua titik koordinat.
  /// Menggunakan Mapbox Directions API dengan fallback ke OSRM.
  static Future<Map<String, dynamic>> calculateRouteDistance({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
  }) async {
    // Validasi koordinat tidak boleh 0.0 atau identik
    if ((startLat == 0.0 && startLng == 0.0) || (destLat == 0.0 && destLng == 0.0)) {
      return _getFallbackResult(startLat, startLng, destLat, destLng, defaultKm: 5.0);
    }

    if ((startLat - destLat).abs() < 0.0001 && (startLng - destLng).abs() < 0.0001) {
      return {
        'success': true,
        'distanceKm': 1.0,
        'durationMinutes': 5,
        'source': 'Identical Points',
      };
    }

    final token = MapboxConfig.accessToken;

    // A. Primary: Mapbox Directions API
    if (token.isNotEmpty) {
      try {
        final mapboxUrl = Uri.parse(
          '$_mapboxDirectionsBaseUrl/$startLng,$startLat;$destLng,$destLat?geometries=geojson&overview=simplified&steps=false&access_token=$token',
        );
        final response = await http.get(mapboxUrl).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
            final route = data['routes'][0];
            double meters = (route['distance'] as num).toDouble();
            double seconds = (route['duration'] as num).toDouble();

            double distanceKm = meters / 1000.0;
            if (distanceKm < 0.5) distanceKm = 1.0;

            int durationMinutes = (seconds / 60.0).round();
            if (durationMinutes < 3) durationMinutes = 5;

            return {
              'success': true,
              'distanceKm': double.parse(distanceKm.toStringAsFixed(1)),
              'durationMinutes': durationMinutes,
              'source': 'Mapbox Directions API',
            };
          }
        }
      } catch (e) {
        debugPrint('⚠️ Mapbox Directions API issue: $e');
      }
    }

    // B. Secondary: OpenStreetMap OSRM Routing Engine
    try {
      final osrmUrl = Uri.parse(
        '$_osrmBaseUrl/$startLng,$startLat;$destLng,$destLat?overview=false&alternatives=false&steps=false',
      );
      final response = await http.get(osrmUrl).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          double meters = (route['distance'] as num).toDouble();
          double seconds = (route['duration'] as num).toDouble();

          double distanceKm = meters / 1000.0;
          if (distanceKm < 0.5) distanceKm = 1.0;

          int durationMinutes = (seconds / 60.0).round();
          if (durationMinutes < 3) durationMinutes = 5;

          return {
            'success': true,
            'distanceKm': double.parse(distanceKm.toStringAsFixed(1)),
            'durationMinutes': durationMinutes,
            'source': 'OpenStreetMap OSRM',
          };
        }
      }
    } catch (e) {
      debugPrint('⚠️ OSRM Route calculation network issue: $e');
    }

    // C. Fallback: Haversine Formula dengan Road Curvature Correction Factor (1.35x)
    return _getFallbackResult(startLat, startLng, destLat, destLng);
  }

  /// 2. Autocomplete Pencarian Nama Tempat / Hangout / Alamat Detail di Indonesia
  /// Menggunakan Mapbox Geocoding dengan Proximity GPS terdekat + fallback OSM
  /// 2. Pencarian Tempat Detail & Spot Hangout (POI, Cafe, Resto, Venue, Alamat)
  /// Menggunakan query paralel Photon Komoot OSM + Mapbox Geocoding dengan ranking jarak terdekat
  static Future<List<Map<String, dynamic>>> searchPlaces(
    String query, {
    double? proximityLat,
    double? proximityLng,
    String? customToken,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    final token = (customToken != null && customToken.isNotEmpty)
        ? customToken
        : MapboxConfig.accessToken;
    final googleKey = MapboxConfig.googleMapsApiKey;

    final results = <Map<String, dynamic>>[];
    final seenCoords = <String>{};
    final seenNames = <String>{};

    // Tentukan titik proximity pengguna untuk hasil pencarian lokal yang akurat
    double userLat = proximityLat ?? LocationService.lastKnownPosition?.latitude ?? -6.2088;
    double userLng = proximityLng ?? LocationService.lastKnownPosition?.longitude ?? 106.8456;

    void addResult(Map<String, dynamic> item) {
      final nameKey = (item['name'] as String? ?? '').toLowerCase().trim();
      final lat = (item['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (item['lng'] as num?)?.toDouble() ?? 0.0;
      final coordKey = "${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}";

      if (nameKey.isNotEmpty && (!seenNames.contains(nameKey) || !seenCoords.contains(coordKey))) {
        seenNames.add(nameKey);
        if (lat != 0.0 && lng != 0.0) {
          seenCoords.add(coordKey);
          final dLat = lat - userLat;
          final dLng = lng - userLng;
          final distScore = (dLat * dLat) + (dLng * dLng);
          item['distScore'] = distScore;
        } else {
          item['distScore'] = 0.01; // Prioritas tinggi untuk Google Places
        }
        results.add(item);
      }
    }

    // 🌟 1. GOOGLE PLACES API (NEW) AUTOCOMPLETE - Super Cerdas (NLP, Typo Tolerant, Hangout Spots)
    final googleFuture = (() async {
      if (googleKey.isEmpty) return;
      try {
        final url = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');
        final body = json.encode({
          'input': cleanQuery,
          'includedRegionCodes': ['id'],
          'locationBias': {
            'circle': {
              'center': {
                'latitude': userLat,
                'longitude': userLng,
              },
              'radius': 50000.0,
            }
          }
        });

        final res = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': googleKey,
          },
          body: body,
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = json.decode(utf8.decode(res.bodyBytes));
          final suggestions = data['suggestions'] as List? ?? [];

          for (var item in suggestions) {
            final pred = item['placePrediction'] as Map<String, dynamic>? ?? {};
            final placeId = pred['placeId']?.toString() ?? '';
            final structured = pred['structuredFormat'] as Map<String, dynamic>? ?? {};
            final mainText = structured['mainText']?['text']?.toString() ??
                pred['text']?['text']?.toString() ??
                cleanQuery;
            final secondaryText = structured['secondaryText']?['text']?.toString() ?? '';
            final fullAddress = pred['text']?['text']?.toString() ??
                (secondaryText.isNotEmpty ? '$mainText, $secondaryText' : mainText);

            if (placeId.isNotEmpty) {
              addResult({
                'placeId': placeId,
                'name': mainText,
                'address': secondaryText.isNotEmpty ? secondaryText : fullAddress,
                'fullAddress': fullAddress,
                'source': 'google',
                'lat': 0.0,
                'lng': 0.0,
              });
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Google Places Autocomplete error: $e');
      }
    })();

    // 🚀 2. Photon (OSM Local Hangouts/Cafes)
    final photonFuture = (() async {
      try {
        final url = Uri.parse(
          '$_photonBaseUrl?q=${Uri.encodeComponent(cleanQuery)}&limit=8&lat=$userLat&lon=$userLng',
        );
        final response = await http.get(url, headers: {'User-Agent': 'TemeninAjaa/1.0'}).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final features = data['features'] as List? ?? [];

          for (var f in features) {
            final props = f['properties'] as Map<String, dynamic>? ?? {};
            final geometry = f['geometry'] as Map<String, dynamic>? ?? {};
            final coordinates = geometry['coordinates'] as List? ?? [];

            if (coordinates.length >= 2) {
              final lng = (coordinates[0] as num).toDouble();
              final lat = (coordinates[1] as num).toDouble();

              final name = props['name'] ?? props['street'] ?? cleanQuery;
              final parts = <String>[];
              if (props['street'] != null && props['street'] != name) parts.add(props['street']);
              if (props['district'] != null) parts.add(props['district']);
              if (props['city'] != null) parts.add(props['city']);
              if (props['state'] != null) parts.add(props['state']);

              final subtitle = parts.isNotEmpty ? parts.join(', ') : 'Spot Hangout';

              addResult({
                'name': name.toString(),
                'address': subtitle,
                'fullAddress': '$name, $subtitle',
                'lat': lat,
                'lng': lng,
                'source': 'osm',
              });
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Photon Search error: $e');
      }
    })();

    // 🗺️ 3. Mapbox Geocoding (Addresses/Places)
    final mapboxFuture = (() async {
      if (token.isEmpty) return;
      try {
        final proximityParam = '&proximity=$userLng,$userLat';
        final mapboxUrl = Uri.parse(
          '$_mapboxGeocodingBaseUrl/${Uri.encodeComponent(cleanQuery)}.json?country=id&language=id$proximityParam&fuzzyMatch=true&autocomplete=true&limit=6&access_token=$token',
        );
        final res = await http.get(mapboxUrl).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = json.decode(utf8.decode(res.bodyBytes));
          final features = data['features'] as List? ?? [];

          for (var feature in features) {
            final placeTypes = feature['place_type'] as List? ?? [];
            if (placeTypes.contains('country') || placeTypes.contains('region')) {
              continue;
            }

            final text = feature['text']?.toString() ?? cleanQuery;
            final placeName = feature['place_name']?.toString() ?? text;
            final center = feature['center'] as List? ?? [];

            if (center.length >= 2) {
              final lng = (center[0] as num).toDouble();
              final lat = (center[1] as num).toDouble();

              String subAddress = placeName;
              if (placeName.startsWith(text) && placeName.length > text.length) {
                subAddress = placeName.substring(text.length).trim();
                if (subAddress.startsWith(',')) {
                  subAddress = subAddress.substring(1).trim();
                }
              }

              addResult({
                'name': text,
                'address': subAddress.isNotEmpty ? subAddress : placeName,
                'fullAddress': placeName,
                'lat': lat,
                'lng': lng,
                'source': 'mapbox',
              });
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Mapbox Geocoding Search error: $e');
      }
    })();

    await Future.wait([googleFuture, photonFuture, mapboxFuture]);

    // Jika masih kosong sama sekali, fallback ke Nominatim
    if (results.isEmpty) {
      try {
        final nomUrl = Uri.parse(
          '$_nominatimBaseUrl?q=${Uri.encodeComponent(cleanQuery)}&format=json&limit=6&countrycodes=id',
        );
        final response = await http.get(
          nomUrl,
          headers: {'User-Agent': 'TemeninAjaaApp/1.0 (contact@temeninajaa.id)'},
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final list = json.decode(utf8.decode(response.bodyBytes)) as List? ?? [];
          for (var item in list) {
            final displayName = item['display_name']?.toString() ?? cleanQuery;
            final split = displayName.split(',');
            final mainName = split.first.trim();
            final restAddress = split.skip(1).take(3).join(',').trim();

            addResult({
              'name': mainName,
              'address': restAddress.isNotEmpty ? restAddress : displayName,
              'fullAddress': displayName,
              'lat': double.tryParse(item['lat']?.toString() ?? '0') ?? userLat,
              'lng': double.tryParse(item['lon']?.toString() ?? '0') ?? userLng,
              'source': 'nominatim',
            });
          }
        }
      } catch (e) {
        debugPrint('⚠️ Nominatim Search error: $e');
      }
    }

    return results;
  }

  /// 🌟 Mengambil Titik Koordinat Presisi dari Google Place ID
  static Future<Map<String, double>?> getGooglePlaceCoordinates(String placeId) async {
    try {
      final key = MapboxConfig.googleMapsApiKey;
      if (key.isEmpty || placeId.isEmpty) return null;

      final url = Uri.parse('https://places.googleapis.com/v1/places/$placeId');
      final res = await http.get(
        url,
        headers: {
          'X-Goog-Api-Key': key,
          'X-Goog-FieldMask': 'id,displayName,formattedAddress,location',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        final loc = data['location'] as Map<String, dynamic>? ?? {};
        final lat = (loc['latitude'] as num?)?.toDouble();
        final lng = (loc['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          return {'lat': lat, 'lng': lng};
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching Google Place coordinates: $e');
    }
    return null;
  }

  /// 3. Reverse Geocoding: Dapatkan nama lokasi & alamat lengkap dari koordinat Lat/Lng
  /// Menggunakan Mapbox Geocoding dengan fallback ke Photon & Nominatim
  static Future<Map<String, String>> reverseGeocode(double lat, double lng, {String? customToken}) async {
    final token = (customToken != null && customToken.isNotEmpty)
        ? customToken
        : MapboxConfig.accessToken;

    // A. Primary: Mapbox Reverse Geocoding
    if (token.isNotEmpty) {
      try {
        final url = Uri.parse(
          '$_mapboxGeocodingBaseUrl/$lng,$lat.json?types=address,poi,neighborhood,locality,place&language=id&access_token=$token',
        );
        final res = await http.get(url).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = json.decode(utf8.decode(res.bodyBytes));
          final features = data['features'] as List? ?? [];
          if (features.isNotEmpty) {
            final first = features.first;
            final text = first['text']?.toString() ?? "Titik di Peta";
            final placeName = first['place_name']?.toString() ?? text;

            return {
              'title': text,
              'fullAddress': placeName,
            };
          }
        }
      } catch (e) {
        debugPrint('⚠️ Mapbox Reverse Geocode error: $e');
      }
    }

    // B. Secondary: Photon Komoot Reverse Geocoding
    try {
      final url = Uri.parse('https://photon.komoot.io/reverse?lat=$lat&lon=$lng');
      final res = await http.get(url, headers: {'User-Agent': 'TemeninAjaa/1.0'}).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        final features = data['features'] as List? ?? [];
        if (features.isNotEmpty) {
          final props = features.first['properties'] as Map<String, dynamic>? ?? {};
          final name = props['name'] ?? props['street'] ?? props['district'] ?? "Titik di Peta";

          final parts = <String>[];
          if (props['street'] != null && props['street'] != name) parts.add(props['street']);
          if (props['district'] != null) parts.add(props['district']);
          if (props['city'] != null) parts.add(props['city']);
          if (props['state'] != null) parts.add(props['state']);

          final subAddress = parts.isNotEmpty
              ? parts.join(', ')
              : "Koordinat: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}";

          return {
            'title': name.toString(),
            'fullAddress': "$name, $subAddress",
          };
        }
      }
    } catch (e) {
      debugPrint("⚠️ Photon reverse geocode error: $e");
    }

    // C. Fallback ke Nominatim Reverse Geocoding
    try {
      final nomUrl = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');
      final nomRes = await http.get(nomUrl, headers: {'User-Agent': 'TemeninAjaaApp/1.0 (contact@temeninajaa.id)'}).timeout(const Duration(seconds: 4));
      if (nomRes.statusCode == 200) {
        final data = json.decode(utf8.decode(nomRes.bodyBytes));
        final address = data['address'] as Map<String, dynamic>? ?? {};
        final road = address['road'] ?? address['suburb'] ?? address['amenity'] ?? data['name'] ?? 'Titik di Peta';
        final displayName = data['display_name']?.toString() ?? road;

        return {
          'title': road.toString(),
          'fullAddress': displayName,
        };
      }
    } catch (e) {
      debugPrint("⚠️ Nominatim reverse geocode error: $e");
    }

    return {
      'title': "Titik Koordinat Terpilih",
      'fullAddress': "Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}",
    };
  }

  /// 4. Geocoding Otomatis: Dapatkan Lat/Lng dari teks alamat jika pengguna mengetik manual
  static Future<Map<String, double>?> geocodeAddress(String address) async {
    if (address.trim().isEmpty) return null;
    final results = await searchPlaces(address);
    if (results.isNotEmpty) {
      return {
        'lat': results.first['lat'] as double,
        'lng': results.first['lng'] as double,
      };
    }
    return null;
  }

  /// 5. Membuka Layar Interactive Map Picker Visual
  static Future<void> showLocationPickerModal(
    BuildContext context, {
    required String title,
    required String initialValue,
    double initialLat = -6.2099,
    double initialLng = 106.8502,
    required Function(String address, double lat, double lng) onSelected,
  }) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => InteractiveMapPickerScreen(
          title: title,
          initialAddress: initialValue,
          initialLat: initialLat,
          initialLng: initialLng,
        ),
      ),
    );

    if (result != null && result['address'] != null) {
      onSelected(
        result['address'] as String,
        (result['lat'] as num?)?.toDouble() ?? initialLat,
        (result['lng'] as num?)?.toDouble() ?? initialLng,
      );
    }
  }

  /// Helper untuk kalkulasi Haversine jika offline/fallback
  static Map<String, dynamic> _getFallbackResult(
    double lat1, double lon1, double lat2, double lon2, {double? defaultKm}
  ) {
    if (defaultKm != null) {
      return {
        'success': true,
        'distanceKm': defaultKm,
        'durationMinutes': (defaultKm * 2.5).round(),
        'source': 'Default Estimate',
      };
    }

    const double earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final straightDistance = earthRadiusKm * c;

    // Road winding curvature multiplier di jalan raya Indonesia (~1.35x dari garis lurus)
    double roadDistance = straightDistance * 1.35;
    if (roadDistance < 1.0) roadDistance = 1.0;

    return {
      'success': true,
      'distanceKm': double.parse(roadDistance.toStringAsFixed(1)),
      'durationMinutes': (roadDistance * 2.8).round(),
      'source': 'Haversine Road Estimated',
    };
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }
}
