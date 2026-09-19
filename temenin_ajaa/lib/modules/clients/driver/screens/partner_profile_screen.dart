import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/modules/clients/chat/screens/chat_room_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/booking_order_type_screen.dart';
import '../../../../core/utils/booking_date_helper.dart';

class PartnerProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? partnerData;
  final String? serviceType;

  const PartnerProfileScreen({super.key, this.partnerData, this.serviceType});

  @override
  State<PartnerProfileScreen> createState() => _PartnerProfileScreenState();
}

class _PartnerProfileScreenState extends State<PartnerProfileScreen> {
  String _activeSubtab = 'profil';
  Map<String, dynamic>? _dbDriverData;
  List<Map<String, dynamic>> _dbReviews = [];
  List<Map<String, dynamic>> _parsedVehicles = [];
  List<Map<String, dynamic>> _driverBookings = [];
  List<Map<String, dynamic>> _driverAddons = [];
  List<String> _skills = [];
  List<String> _languages = [];
  List<String> _activeServices = ['hangout', 'freedom', 'detektif', 'sporty_ride', 'counseling', 'hiking', 'assistant', 'sleep', 'telepon'];
  String _driverBio = '';
  List<String> _operationalCities = [];
  int _experienceYears = 1;
  int _selectedScheduleDayIndex = 0;
  bool _isBioExpanded = false;

  String _getDayName(int weekday) {
    const names = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return names[(weekday - 1) % 7];
  }

  String _getShortDayName(int weekday) {
    const names = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MING'];
    return names[(weekday - 1) % 7];
  }

  String _getFullMonthName(int month) {
    const names = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return names[(month - 1) % 12];
  }

  int _extractBookingDurationHours(Map<String, dynamic> b) {
    final add = b['additional_details'] is Map ? b['additional_details'] as Map : null;
    final rawDur = b['duration'] ?? add?['duration'] ?? add?['duration_hours'] ?? add?['hangoutDurationHours'] ?? add?['totalHours'] ?? add?['hours'];
    if (rawDur != null) {
      final n = int.tryParse(rawDur.toString().replaceAll(RegExp(r'[^0-9]'), ''));
      if (n != null && n > 0) {
        if (n >= 30 && n % 30 == 0 && n > 24) {
          return (n / 60).ceil();
        }
        return n;
      }
    }
    return 2; // Default 2 jam
  }

  DateTime? _extractBookingDateTime(Map<String, dynamic> b) {
    final dt = BookingDateHelper.extractScheduledDateTime(b);
    if (dt != null) return dt;
    final rawCreatedAt = b['created_at']?.toString();
    if (rawCreatedAt != null && rawCreatedAt.isNotEmpty) {
      return DateTime.tryParse(rawCreatedAt);
    }
    return null;
  }

  bool _isBookingActive(String status) {
    final s = status.toLowerCase();
    return s != 'cancelled' && s != 'rejected' && s != 'declined';
  }

  bool _isBookingWaitingOrActive(String status) {
    final s = status.toLowerCase();
    return s == 'waiting_dp' ||
        s == 'dp_paid' ||
        s == 'pending' ||
        s == 'accepted' ||
        s == 'waiting_client' ||
        s == 'arrived' ||
        s == 'in_trip' ||
        s == 'ongoing' ||
        s == 'confirmed' ||
        s == 'waiting_final_payment';
  }

  List<Map<String, dynamic>> _getBookingsForDate(DateTime date) {
    return _driverBookings.where((b) {
      final status = (b['status'] ?? '').toString();
      if (!_isBookingActive(status)) return false;

      final dt = _extractBookingDateTime(b);
      if (dt == null) return false;

      return dt.year == date.year && dt.month == date.month && dt.day == date.day;
    }).toList();
  }

  List<Map<String, dynamic>> _computeHourlySlots(DateTime date, List<Map<String, dynamic>> dayBookings) {
    final List<Map<String, dynamic>> slots = [];

    // Operating hours: 08:00 to 22:00
    for (int h = 8; h < 22; h++) {
      final slotStart = DateTime(date.year, date.month, date.day, h, 0);
      final slotEnd = DateTime(date.year, date.month, date.day, h + 1, 0);
      final slotLabel = "${h.toString().padLeft(2, '0')}:00 - ${(h + 1).toString().padLeft(2, '0')}:00";

      Map<String, dynamic>? overlappingBooking;
      DateTime? bStart;
      DateTime? bEnd;
      int bDur = 2;

      for (final b in dayBookings) {
        final start = _extractBookingDateTime(b);
        if (start == null) continue;
        final dur = _extractBookingDurationHours(b);
        final end = start.add(Duration(hours: dur));

        if (slotStart.isBefore(end) && slotEnd.isAfter(start)) {
          overlappingBooking = b;
          bStart = start;
          bEnd = end;
          bDur = dur;
          break;
        }
      }

      if (overlappingBooking != null && bStart != null && bEnd != null) {
        final add = overlappingBooking['additional_details'] is Map ? overlappingBooking['additional_details'] as Map : null;
        final serviceName = overlappingBooking['service_type']?.toString() ??
            add?['service_name']?.toString() ??
            add?['service_type']?.toString() ??
            'Layanan Pendamping';
        final status = overlappingBooking['status']?.toString() ?? 'pending';
        final timeRangeStr = "${bStart.hour.toString().padLeft(2, '0')}:${bStart.minute.toString().padLeft(2, '0')} - ${bEnd.hour.toString().padLeft(2, '0')}:${bEnd.minute.toString().padLeft(2, '0')} WIB";

        slots.add({
          'hour': h,
          'label': slotLabel,
          'isLocked': true,
          'booking': overlappingBooking,
          'serviceName': serviceName,
          'timeRangeString': timeRangeStr,
          'durationHours': bDur,
          'status': status,
        });
      } else {
        slots.add({
          'hour': h,
          'label': slotLabel,
          'isLocked': false,
          'booking': null,
          'serviceName': null,
          'timeRangeString': null,
          'durationHours': 0,
          'status': 'available',
        });
      }
    }

    return slots;
  }

  @override
  void initState() {
    super.initState();
    _fetchRealDriverDetails();
  }

  Future<void> _fetchRealDriverDetails() async {
    final driverId = widget.partnerData?['id'] ?? widget.partnerData?['driverId'];
    final userId = widget.partnerData?['userId'];

    if (driverId == null && userId == null) return;

    try {
      final supabase = Supabase.instance.client;
      var query = supabase.from('drivers').select('*, users(*)');

      if (driverId != null) {
        query = query.or('id.eq.$driverId,user_id.eq.$driverId');
      } else if (userId != null) {
        query = query.eq('user_id', userId);
      }

      final res = await query.maybeSingle();
      if (res != null) {
        _dbDriverData = res;
        _experienceYears = res['experience_years'] ?? 1;

        final String vehicleStnk = res['vehicle_stnk'] ?? '';
        if (vehicleStnk.startsWith('{')) {
          try {
            final Map<String, dynamic> metadata = jsonDecode(vehicleStnk);
            if (metadata['bio'] != null && metadata['bio'].toString().isNotEmpty) {
              _driverBio = metadata['bio'];
            }
            if (metadata['operational_cities'] != null) {
              _operationalCities = List<String>.from(metadata['operational_cities']);
            }
            if (metadata['skills'] != null) {
              _skills = List<String>.from(metadata['skills']);
            }
            if (metadata['languages'] != null) {
              _languages = List<String>.from(metadata['languages']);
            }
            if (metadata['active_services'] != null) {
              _activeServices = List<String>.from(metadata['active_services']);
            }
            if (metadata['vehicles'] != null) {
              _parsedVehicles = List<Map<String, dynamic>>.from(
                (metadata['vehicles'] as List).map((v) => Map<String, dynamic>.from(v)),
              );
            }
            if (metadata['addons'] != null && metadata['addons'] is List) {
              _driverAddons = List<Map<String, dynamic>>.from(
                (metadata['addons'] as List).map((a) => Map<String, dynamic>.from(a)),
              );
            }
          } catch (e) {
            debugPrint('Error parsing vehicle_stnk metadata in client: $e');
          }
        } else if (vehicleStnk.isNotEmpty && !vehicleStnk.startsWith('http')) {
          _driverBio = vehicleStnk;
        }

        if (_driverAddons.isEmpty && widget.partnerData?['addons'] != null) {
          _driverAddons = List<Map<String, dynamic>>.from(widget.partnerData!['addons']);
        }

        if (_driverBio.isEmpty) {
          _driverBio = res['bio'] ?? widget.partnerData?['description'] ?? widget.partnerData?['bio'] ?? '';
        }

        if (_parsedVehicles.isEmpty) {
          final vName = res['vehicle_name']?.toString().trim();
          final vPlate = res['plate_number']?.toString().trim();
          final vType = res['vehicle_type']?.toString().trim();
          final vImg = (res['vehicle_image'] ?? res['vehicle_photo'] ?? res['image'])?.toString().trim();

          if (vName != null && vName.isNotEmpty && vName != 'Belum diatur') {
            _parsedVehicles.add({
              'type': _detectVehicleCategory(vName, vType),
              'name': vName,
              'plate_number': (vPlate != null && vPlate.isNotEmpty) ? vPlate : '',
              'image': (vImg != null && vImg.isNotEmpty) ? vImg : null,
              'age': '< 3 Tahun',
            });
          }
        }
      }

      if (_parsedVehicles.isEmpty) {
        final pVeh = widget.partnerData?['vehicle']?.toString().trim();
        final vName = (pVeh != null && pVeh.isNotEmpty && pVeh != 'Kendaraan Driver')
            ? pVeh
            : 'Honda Vario 160';
        final vImg = widget.partnerData?['vehicle_image'] ?? widget.partnerData?['image'];
        final detectedCat = _detectVehicleCategory(vName, widget.partnerData?['vehicle_type']);
        _parsedVehicles.add({
          'type': detectedCat,
          'name': vName,
          'image': (vImg != null && vImg.toString().isNotEmpty && !vImg.toString().contains('dummy') && !vImg.toString().contains('ui-avatars')) ? vImg.toString() : null,
          'age': '< 3 Tahun',
        });
      }

      final targetDriverId = _dbDriverData?['id'] ?? driverId;
      final targetUserId = _dbDriverData?['user_id'] ?? userId;
      if (targetDriverId != null || targetUserId != null) {
        // Fetch reviews
        final orFilter = (targetUserId != null && targetUserId != targetDriverId)
            ? 'driver_id.eq.$targetDriverId,driver_id.eq.$targetUserId' 
            : 'driver_id.eq.$targetDriverId';

        final List<Map<String, dynamic>> loadedReviews = [];
        final Set<String> seenIds = {};

        try {
          final List<dynamic> revRows = await supabase
              .from('reviews')
              .select('*, users(full_name, avatar_url)')
              .or(orFilter)
              .order('created_at', ascending: false);

          for (final r in revRows) {
            final userObj = r['users'] ?? {};
            final comment = r['comment']?.toString().trim() ?? '';
            final bId = r['booking_id']?.toString() ?? r['id']?.toString() ?? '';
            if (seenIds.contains(bId)) continue;
            seenIds.add(bId);

            final authorName = userObj['full_name']?.toString().trim();
            loadedReviews.add({
              'author': (authorName != null && authorName.isNotEmpty) ? authorName : 'Pelanggan',
              'avatar': userObj['avatar_url']?.toString() ?? '',
              'rating': double.tryParse(r['rating']?.toString() ?? '5.0') ?? 5.0,
              'text': comment,
              'date': r['created_at']?.toString().split('T')[0] ?? '',
            });
          }
        } catch (e) {
          debugPrint('Error fetching reviews table in partner_profile: $e');
        }

        // Fetch real driver bookings for availability calendar and review fallback
        try {
          final bookingFilter = (targetUserId != null && targetUserId != targetDriverId)
              ? 'driver_id.eq.$targetDriverId,driver_id.eq.$targetUserId'
              : 'driver_id.eq.$targetDriverId';

          final List<dynamic> bookingRows = await supabase
              .from('bookings')
              .select('*')
              .or(bookingFilter)
              .order('created_at', ascending: false);

          _driverBookings = List<Map<String, dynamic>>.from(bookingRows);

          for (final b in bookingRows) {
            final bId = b['id']?.toString() ?? '';
            if (seenIds.contains(bId)) continue;

            final details = b['additional_details'] is Map
                ? Map<String, dynamic>.from(b['additional_details'] as Map)
                : <String, dynamic>{};

            final hasReviewed = details['has_reviewed'] == true || details['rating'] != null;
            final clientRating = details['rating'] ?? details['review']?['rating'];
            final clientComment = details['comment']?.toString().trim() ?? details['review']?['comment']?.toString().trim() ?? '';

            if (hasReviewed && clientRating != null) {
              seenIds.add(bId);
              final clientName = details['client_name'] ?? details['userName'] ?? details['user_name'] ?? 'Pelanggan';
              final clientAvatar = details['client_avatar'] ?? details['user_avatar'] ?? '';
              final ratingNum = double.tryParse(clientRating.toString()) ?? 5.0;

              loadedReviews.add({
                'author': clientName.toString().trim().isNotEmpty ? clientName.toString().trim() : 'Pelanggan',
                'avatar': clientAvatar.toString(),
                'rating': ratingNum,
                'text': clientComment,
                'date': b['created_at']?.toString().split('T')[0] ?? '',
              });
            }
          }
        } catch (e) {
          debugPrint('Error fetching driver bookings in partner_profile: $e');
        }

        _dbReviews = loadedReviews;
      }
    } catch (e) {
      debugPrint('Error fetching real driver details: $e');
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final partnerName = widget.partnerData?['name'] ?? "Driver Partner";
    final partnerRating = widget.partnerData?['rating']?.toString() ?? "5.0";
    final partnerVehicle = widget.partnerData?['vehicle'] ?? "Kendaraan Driver";
    final partnerType = widget.partnerData?['type'] ?? "★ GOLD TIER";

    final rawImage = _dbDriverData?['users']?['avatar_url'] ?? widget.partnerData?['image'];
    final partnerImage = (rawImage != null &&
            rawImage.toString().isNotEmpty &&
            !rawImage.toString().contains('placeholder') &&
            !rawImage.toString().contains('dummy') &&
            !rawImage.toString().contains('unsplash'))
        ? rawImage.toString()
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(partnerName)}&background=D64573&color=fff&bold=true';

    final bool isAvailable = _dbDriverData != null
        ? (_dbDriverData!['is_available'] == true || _dbDriverData!['status']?.toString().toLowerCase() == 'available')
        : (widget.partnerData?['isAvailable'] == true ||
            widget.partnerData?['status']?.toString().toLowerCase() == 'available' ||
            widget.partnerData?['status']?.toString().toLowerCase() == 'tersedia');
    final partnerStatus = isAvailable ? "Tersedia" : "Offline";
    final partnerPriceVal = widget.partnerData?['price'] ?? 50000;
    
    final formattedPrice = 'Rp ${partnerPriceVal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.'
    )}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroHeader(context, partnerName, partnerType, partnerRating, partnerImage, partnerStatus),
                  
                  _buildSubtabRow(),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: _buildActiveSubtabContent(partnerName, partnerVehicle, formattedPrice),
                  ),
                  
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomAction(
              context, 
              partnerName, 
              partnerVehicle, 
              partnerRating, 
              partnerImage, 
              partnerPriceVal,
              formattedPrice,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, String name, String type, String rating, String image, String status) {
    final city = _operationalCities.isNotEmpty 
        ? _operationalCities.first 
        : (_dbDriverData?['city'] ?? widget.partnerData?['location'] ?? 'Indonesia');
    
    final reviewText = _dbReviews.isNotEmpty 
        ? '(${_dbReviews.length} Ulasan)' 
        : '(Belum ada ulasan)';

    final effectiveRating = _dbReviews.isNotEmpty
        ? (_dbReviews.map((r) => (r['rating'] as num).toDouble()).reduce((a, b) => a + b) / _dbReviews.length).toStringAsFixed(1)
        : (_dbDriverData?['rating'] != null && (_dbDriverData!['total_rides'] ?? 0) > 0 ? _dbDriverData!['rating'].toString() : '0.0');

    return Stack(
      children: [
        SizedBox(
          height: 360,
          width: double.infinity,
          child: Image.network(
            image,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppTheme.cardDeep,
                child: const Icon(Icons.person, color: AppTheme.textMuted, size: 80),
              );
            },
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.3),
                  AppTheme.background,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  type,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: GoogleFonts.inter(
                  color: AppTheme.textHighContrast,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        effectiveRating,
                        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        ' $reviewText • 📍 $city',
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  Builder(
                    builder: (context) {
                      final bool isOnline = status.toLowerCase() == 'tersedia' || status.toLowerCase() == 'available';
                      final Color statusColor = isOnline ? AppTheme.success : AppTheme.textMuted;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status,
                              style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubtabRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSubtabButton('profil', 'Profil'),
          _buildSubtabButton('ketersediaan', 'Ketersediaan'),
          _buildSubtabButton('pengalaman', 'Pengalaman'),
          _buildSubtabButton('ulasan', 'Ulasan'),
        ],
      ),
    );
  }

  Widget _buildSubtabButton(String key, String label) {
    final isActive = _activeSubtab == key;
    return GestureDetector(
      onTap: () => setState(() => _activeSubtab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: isActive
              ? const Border(bottom: BorderSide(color: AppTheme.primaryPink, width: 2.5))
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isActive ? AppTheme.primaryPink : AppTheme.textMuted,
            fontSize: 12.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _detectVehicleCategory(String name, [String? rawType]) {
    final lowerName = name.toLowerCase();
    final lowerType = (rawType ?? '').toLowerCase();

    if (lowerType.contains('sport') ||
        lowerName.contains('cbr') ||
        lowerName.contains('ninja') ||
        lowerName.contains('r15') ||
        lowerName.contains('r25') ||
        lowerName.contains('zx') ||
        lowerName.contains('gsx') ||
        lowerName.contains('sport')) {
      return 'Motor Sport';
    }

    if (lowerType.contains('classic') ||
        lowerType.contains('retro') ||
        lowerName.contains('vespa') ||
        lowerName.contains('xsr') ||
        lowerName.contains('w175') ||
        lowerName.contains('cb') ||
        lowerName.contains('scoopy') ||
        lowerName.contains('fazzio') ||
        lowerName.contains('filano') ||
        lowerName.contains('enfield')) {
      return 'Motor Classic';
    }

    if (lowerType.contains('bebek') ||
        lowerName.contains('supra') ||
        lowerName.contains('jupiter') ||
        lowerName.contains('revo') ||
        lowerName.contains('blade') ||
        lowerName.contains('mx king')) {
      return 'Motor Bebek';
    }

    if (lowerType.contains('mobil') ||
        lowerType.contains('car') ||
        lowerName.contains('avanza') ||
        lowerName.contains('brio') ||
        lowerName.contains('innova') ||
        lowerName.contains('mobil')) {
      return 'Mobil';
    }

    return 'Motor Matic';
  }

  String _getDefaultVehiclePhoto(String category, String name) {
    if (category == 'Motor Sport') {
      return 'https://images.unsplash.com/photo-1568772585407-9361f9bf3a87?q=80&w=800&auto=format&fit=crop';
    } else if (category == 'Motor Classic') {
      return 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?q=80&w=800&auto=format&fit=crop';
    } else if (category == 'Mobil') {
      return 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?q=80&w=800&auto=format&fit=crop';
    } else if (category == 'Motor Bebek') {
      return 'https://images.unsplash.com/photo-1558981806-ec527fa84c39?q=80&w=800&auto=format&fit=crop';
    }
    // Default Motor Matic
    return 'https://images.unsplash.com/photo-1558981408-db0ecd8a1ee4?q=80&w=800&auto=format&fit=crop';
  }

  void _showClientVehicleDetailModal(BuildContext context, Map<String, dynamic> v) {
    final vName = v['name'] ?? 'Kendaraan Driver';
    final vCategory = _detectVehicleCategory(vName, v['type']);
    final rawImg = (v['image'] != null && v['image'].toString().isNotEmpty && !v['image'].toString().contains('dummy') && !v['image'].toString().contains('ui-avatars'))
        ? v['image'].toString()
        : _getDefaultVehiclePhoto(vCategory, vName);
    final age = v['age'] ?? '< 3 Tahun';

    IconData catIcon = Icons.two_wheeler_rounded;
    if (vCategory == 'Motor Sport') {
      catIcon = Icons.sports_motorsports_rounded;
    } else if (vCategory == 'Motor Classic') {
      catIcon = Icons.moped_rounded;
    } else if (vCategory == 'Mobil') {
      catIcon = Icons.directions_car_rounded;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Detail Unit Kendaraan",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textHighContrast,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          "Fasilitas & Standar Kenyamanan Unit",
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.success.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: AppTheme.success, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "Terverifikasi",
                            style: GoogleFonts.inter(color: AppTheme.success, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Vehicle Big Image with category pill
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        rawImg,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          height: 200,
                          width: double.infinity,
                          color: AppTheme.cardDeep,
                          child: Icon(catIcon, color: AppTheme.primaryPink, size: 64),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primaryPink.withOpacity(0.6)),
                        ),
                        child: Row(
                          children: [
                            Icon(catIcon, color: AppTheme.primaryPink, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              vCategory,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Vehicle Title and Specs
                Text(
                  vName,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textHighContrast,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Kategori: $vCategory • Usia Unit: $age",
                  style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Amenities / Comfort list
                Text(
                  "Fasilitas & Standar Kebersihan:",
                  style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildAmenityRow(Icons.sports_motorsports_rounded, "Helm Penumpang SNI", "Bersih, harum & higienis, kaca anti silau & terawat"),
                _buildAmenityRow(Icons.umbrella_rounded, "Jas Hujan 2 Set", "Jas hujan bersih siap sedia saat cuaca hujan"),
                _buildAmenityRow(Icons.masks_rounded, "Hairnet & Masker Gratis", "Disediakan baru dan higienis untuk setiap penumpang"),
                _buildAmenityRow(Icons.cleaning_services_rounded, "Unit Bersih & Servis Prima", "Dicuci berkala dan mesin dirawat sesuai standar pabrikan"),
                const SizedBox(height: 14),

                // Privacy Notice Box (Plat & STNK disembunyikan demi privasi)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded, color: AppTheme.primaryPink, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Demi privasi dan keamanan mitra, dokumen STNK dan nomor plat lengkap disimpan aman terenkripsi serta telah diverifikasi 100% oleh Tim Operasional Temenin Ajaa.",
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Close button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      "TUTUP",
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmenityRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.fuchsiaLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryPink, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSubtabContent(String partnerName, String vehicle, String formattedPrice) {
    switch (_activeSubtab) {
      case 'profil':
        return _buildProfilTabContent(partnerName, vehicle, formattedPrice);
      case 'ketersediaan':
        return _buildKetersediaanTabContent();
      case 'pengalaman':
        return _buildPengalamanTabContent();
      case 'ulasan':
        return _buildUlasanTabContent();
      default:
        return _buildProfilTabContent(partnerName, vehicle, formattedPrice);
    }
  }

  Widget _buildProfilTabContent(String partnerName, String vehicle, String formattedPrice) {
    final bioText = _driverBio.trim().isNotEmpty
        ? _driverBio
        : "Belum ada biografi yang ditulis oleh driver.";

    final bool isLongBio = bioText.length > 180;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Biografi',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          firstChild: Text(
            bioText,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: _driverBio.trim().isNotEmpty ? AppTheme.textHighContrast : AppTheme.textMuted,
              fontSize: 13,
              height: 1.5,
              fontStyle: _driverBio.trim().isNotEmpty ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          secondChild: Text(
            bioText,
            style: GoogleFonts.inter(
              color: _driverBio.trim().isNotEmpty ? AppTheme.textHighContrast : AppTheme.textMuted,
              fontSize: 13,
              height: 1.5,
              fontStyle: _driverBio.trim().isNotEmpty ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          crossFadeState: (_isBioExpanded || !isLongBio) ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        if (isLongBio)
          GestureDetector(
            onTap: () => setState(() => _isBioExpanded = !_isBioExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _isBioExpanded ? 'Sembunyikan ▲' : 'Lihat Selengkapnya ▼',
                style: GoogleFonts.inter(
                  color: AppTheme.primaryPink,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kendaraan Terdaftar (${_parsedVehicles.length})',
              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.fuchsiaLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
              ),
              child: Text(
                'Ketuk untuk lihat foto unit',
                style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: _parsedVehicles.map((v) {
            final vName = v['name'] ?? 'Kendaraan Driver';
            final vCategory = _detectVehicleCategory(vName, v['type']);
            final vImg = (v['image'] != null && v['image'].toString().isNotEmpty && !v['image'].toString().contains('dummy') && !v['image'].toString().contains('ui-avatars'))
                ? v['image'].toString()
                : _getDefaultVehiclePhoto(vCategory, vName);

            IconData catIcon = Icons.two_wheeler_rounded;
            if (vCategory == 'Motor Sport') {
              catIcon = Icons.sports_motorsports_rounded;
            } else if (vCategory == 'Motor Classic') {
              catIcon = Icons.moped_rounded;
            } else if (vCategory == 'Mobil') {
              catIcon = Icons.directions_car_rounded;
            }

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showClientVehicleDetailModal(context, v),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPink.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          vImg,
                          width: 76,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            width: 76,
                            height: 64,
                            color: AppTheme.fuchsiaLight,
                            child: Icon(catIcon, color: AppTheme.primaryPink, size: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vName,
                              style: GoogleFonts.inter(
                                color: AppTheme.textHighContrast,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.fuchsiaLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.primaryPink.withOpacity(0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(catIcon, color: AppTheme.primaryPink, size: 11),
                                      const SizedBox(width: 4),
                                      Text(
                                        vCategory,
                                        style: GoogleFonts.inter(
                                          color: AppTheme.primaryPink,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Terverifikasi ✔',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.success,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  "Lihat foto & fasilitas unit",
                                  style: GoogleFonts.inter(
                                    color: AppTheme.primaryPink,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryPink, size: 10),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        Text(
          'Layanan yang Disediakan',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _activeServices.map((key) {
            String title = key;
            IconData icon = Icons.check_circle_rounded;
            Color color = AppTheme.primaryPink;

            final k = key.toLowerCase();
            if (k == 'sleep' || k == 'sleep_call') {
              title = '🌙 Sleep Call Companion';
              icon = Icons.bedtime_rounded;
              color = const Color(0xFF6366F1);
            } else if (k == 'telepon' || k == 'counseling' || k == 'curhat' || k == 'virtual') {
              title = '📞 Telepon Curhat & Konseling';
              icon = Icons.phone_in_talk_rounded;
              color = const Color(0xFF6366F1);
            } else if (k == 'counseling_offline') {
              title = '🛋️ Konseling Curhat Offline';
              icon = Icons.psychology_rounded;
              color = AppTheme.primaryPink;
            } else if (k == 'gaming' || k == 'game' || k == 'mabar') {
              title = '🎮 Gaming Buddy (Mabar)';
              icon = Icons.sports_esports_rounded;
              color = const Color(0xFF6366F1);
            } else if (k == 'sporty_ride' || k == 'sporty' || k == 'motor_sport') {
              title = '🏍️ Antar Jemput Sporty';
              icon = Icons.two_wheeler_rounded;
              color = const Color(0xFF06B6D4);
            } else if (k == 'ride' || k == 'antar_jemput' || k == 'regular') {
              title = '🚕 Antar Jemput Aman';
              icon = Icons.local_taxi_rounded;
              color = AppTheme.primaryPink;
            } else if (k == 'hangout') {
              title = '🍸 Hangout Partner';
              icon = Icons.wine_bar_rounded;
              color = AppTheme.primaryPink;
            } else if (k == 'hiking') {
              title = '🏔️ Hiking Partner (Gunung)';
              icon = Icons.terrain_rounded;
              color = const Color(0xFF10B981);
            } else if (k == 'assistant') {
              title = '💼 Personal Assistant';
              icon = Icons.business_center_rounded;
              color = const Color(0xFF8B5CF6);
            } else if (k == 'detektif') {
              title = '🕵️ Detektif Relationship';
              icon = Icons.search_rounded;
              color = const Color(0xFFE11D48);
            } else if (k == 'freedom') {
              title = '✨ Freedom Request (Jasa Suruh)';
              icon = Icons.auto_awesome_rounded;
              color = const Color(0xFFF97316);
            } else {
              title = '💼 $key';
              icon = Icons.stars_rounded;
              color = AppTheme.primaryPink;
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: AppTheme.textHighContrast,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        if (_driverAddons.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Add-ons & Fasilitas Mitra (${_driverAddons.length})',
            style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Column(
            children: _driverAddons.map((addon) {
              final title = addon['title'] ?? addon['name'] ?? 'Add-on';
              final desc = addon['description'] ?? '';
              final cat = addon['category'] ?? 'Layanan';
              final price = addon['price'] is int ? addon['price'] as int : (int.tryParse(addon['price']?.toString() ?? '0') ?? 0);
              final priceFmt = 'Rp ${price.toString().replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.'
              )}';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cat.toUpperCase(),
                        style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      priceFmt,
                      style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPengalamanTabContent() {
    final expYears = _experienceYears;
    final totalRides = _dbDriverData?['total_rides'] ?? widget.partnerData?['trips'] ?? 0;
    final cityText = _operationalCities.isNotEmpty
        ? _operationalCities.join(', ')
        : (_dbDriverData?['city'] ?? 'Belum diatur oleh driver');

    final ratingVal = _dbReviews.isNotEmpty
        ? (_dbReviews.map((r) => (r['rating'] as num).toDouble()).reduce((a, b) => a + b) / _dbReviews.length).toStringAsFixed(1)
        : (_dbDriverData?['rating'] != null && (_dbDriverData!['total_rides'] ?? 0) > 0 ? _dbDriverData!['rating'].toString() : '0.0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rekam Jejak & Pengalaman',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: [
            _buildExpStatCard('$expYears+ Thn', 'Pengalaman Companion', AppTheme.primaryPink),
            _buildExpStatCard('$totalRides+', 'Trip Selesai', const Color(0xFFD97706)),
            _buildExpStatCard(ratingVal, 'Rating Rata-rata', const Color(0xFFF59E0B)),
            _buildExpStatCard('${_dbReviews.length}', 'Ulasan Terverifikasi', AppTheme.success),
          ],
        ),
        const SizedBox(height: 20),

        Text(
          'Lokasi & Area Operasional',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppTheme.primaryPink, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cityText,
                  style: GoogleFonts.inter(
                    color: _operationalCities.isNotEmpty ? AppTheme.textHighContrast : AppTheme.textMuted,
                    fontSize: 12.5,
                    fontWeight: _operationalCities.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                    fontStyle: _operationalCities.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // SEPARATED SKILLS SECTION
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Keahlian Khusus Driver (${_skills.length})',
              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_skills.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'Driver belum menambahkan keahlian khusus.',
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skills.map((skill) => _buildSkillChip(skill)).toList(),
          ),
        const SizedBox(height: 20),

        // SEPARATED LANGUAGES SECTION
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kemampuan Bahasa (${_languages.length})',
              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_languages.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'Driver belum menambahkan kemampuan bahasa.',
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _languages.map((lang) => _buildLanguageChip(lang)).toList(),
          ),
      ],
    );
  }

  Widget _buildUlasanTabContent() {
    final totalRevCount = _dbReviews.isNotEmpty ? _dbReviews.length : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ulasan Pelanggan ($totalRevCount)',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_dbReviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.rate_review_outlined, color: AppTheme.textMuted, size: 36),
                const SizedBox(height: 8),
                Text(
                  'Belum ada ulasan tertulis',
                  style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ulasan dari pelanggan yang telah memesan driver ini akan muncul di sini.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          )
        else
          Column(
            children: _dbReviews.map((r) {
              final comment = r['text']?.toString().trim() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildReviewCard(
                  r['author'] ?? 'Pelanggan',
                  (r['rating'] as num).toDouble(),
                  comment.isNotEmpty ? '"$comment"' : '',
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildReviewCard(String author, double rating, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(author, style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12.5, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                  const SizedBox(width: 3),
                  Text(
                    rating.toString(),
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              text,
              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, height: 1.4, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomAction(
    BuildContext context,
    String name,
    String vehicle,
    String rating,
    String image,
    int price,
    String formattedPrice,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1.0)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatRoomScreen(
                      recipientName: name,
                      recipientImage: image,
                      status: "Online",
                      tag: widget.partnerData?['tier']?.toString() ?? widget.partnerData?['category']?.toString() ?? 'Partner',
                    ),
                  ),
                );
              },
              child: Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: AppTheme.fuchsiaLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryPink, size: 20),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final service = widget.serviceType;
                    if (service != null && service != 'all' && service != 'all-grid') {
                      final partnerInfo = {
                        'id': widget.partnerData?['id'] ?? 'drv-1',
                        'name': name,
                        'vehicle': vehicle,
                        'rating': rating,
                        'image': image,
                        'price': price,
                        'type': widget.partnerData?['type'] ?? 'Platinum',
                        'addons': _driverAddons,
                      };
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingOrderTypeScreen(
                            partnerData: partnerInfo,
                            serviceType: service,
                          ),
                        ),
                      );
                    } else {
                      _showBookingOptionsDialog(
                        context, 
                        name, 
                        vehicle, 
                        rating, 
                        image, 
                        price,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    (widget.serviceType != null && widget.serviceType != 'all' && widget.serviceType != 'all-grid')
                        ? 'PESAN SEKARANG'
                        : 'PILIH LAYANAN',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5, letterSpacing: 0.5, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingOptionsDialog(
    BuildContext context,
    String name,
    String vehicle,
    String rating,
    String image,
    int price,
  ) {
    final partnerInfo = {
      'id': widget.partnerData?['id'] ?? 'drv-1',
      'name': name,
      'vehicle': vehicle,
      'rating': rating,
      'image': image,
      'price': price,
      'type': widget.partnerData?['type'] ?? 'Platinum',
      'addons': _driverAddons,
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        bottom: true,
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '$name (⭐ $rating)',
                style: GoogleFonts.inter(
                  color: AppTheme.textHighContrast,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pilih jenis layanan yang ingin Anda pesan:',
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- PILAR 1: VIRTUAL COMPANION ---
                      _buildPillarSectionHeader("PILAR 1: VIRTUAL COMPANION (ONLINE)", Icons.phone_iphone_rounded, const Color(0xFF6366F1)),
                      const SizedBox(height: 10),
                      _buildModalOption(
                        context,
                        icon: Icons.bedtime_rounded,
                        title: '🌙 Sleep Call Companion',
                        subtitle: 'Teman tidur malam hari & alarm bangun pagi',
                        color: const Color(0xFF6366F1),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BookingOrderTypeScreen(
                            serviceType: 'sleep',
                            partnerData: partnerInfo,
                          )));
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildModalOption(
                        context,
                        icon: Icons.phone_in_talk_rounded,
                        title: '📞 Telepon Curhat & Konseling',
                        subtitle: 'Ruang aman pribadi via panggilan suara',
                        color: const Color(0xFF6366F1),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BookingOrderTypeScreen(
                            serviceType: 'telepon',
                            partnerData: partnerInfo,
                          )));
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildModalOption(
                        context,
                        icon: Icons.sports_esports_rounded,
                        title: '🎮 Gaming Buddy (Mabar)',
                        subtitle: 'Teman main game online bareng & push rank',
                        color: const Color(0xFF6366F1),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF6366F1),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              content: Row(
                                children: [
                                  const Icon(Icons.engineering_rounded, color: Colors.white),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Fitur Gaming Buddy (Mabar) sedang dalam tahap pengembangan!",
                                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      // --- PILAR 2: OFFLINE COMPANION ---
                      _buildPillarSectionHeader("PILAR 2: OFFLINE COMPANION (TATAP MUKA)", Icons.people_alt_rounded, AppTheme.primaryPink),
                      const SizedBox(height: 10),
                      _buildModalOption(
                        context,
                        icon: Icons.wine_bar_rounded,
                        title: '🍸 Hangout Partner',
                        subtitle: 'Teman nongkrong di cafe, mall, bioskop, atau kondangan',
                        color: AppTheme.primaryPink,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BookingOrderTypeScreen(
                            serviceType: 'hangout',
                            partnerData: partnerInfo,
                          )));
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildModalOption(
                        context,
                        icon: Icons.psychology_rounded,
                        title: '🛋️ Relationship Counseling (Offline)',
                        subtitle: 'Mendengarkan curhat tatap muka di tempat santai/kafe',
                        color: AppTheme.primaryPink,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BookingOrderTypeScreen(
                            serviceType: 'counseling_offline',
                            partnerData: partnerInfo,
                          )));
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildModalOption(
                        context,
                        icon: Icons.terrain_rounded,
                        title: '🏔️ Hiking Partner (Mendaki Gunung)',
                        subtitle: 'Jasa menemani naik gunung, tracking alam & camping aman',
                        color: const Color(0xFF10B981),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BookingOrderTypeScreen(
                            serviceType: 'hiking',
                            partnerData: partnerInfo,
                          )));
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildModalOption(
                        context,
                        icon: Icons.two_wheeler_rounded,
                        title: '🏍️ Antar Jemput Sporty (Motor Sport)',
                        subtitle: 'Dianterin / dijemput naik motor sport keren (ZX25R/CBR/Ninja)',
                        color: const Color(0xFF06B6D4),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BookingOrderTypeScreen(
                            serviceType: 'sporty_ride',
                            partnerData: partnerInfo,
                          )));
                        },
                      ),
                      const SizedBox(height: 18),

                      // --- PILAR 3: JASA SURUH & ASISTEN PRIBADI ---
                      _buildPillarSectionHeader("PILAR 3: JASA SURUH & ASISTEN PRIBADI", Icons.auto_awesome_rounded, const Color(0xFFF97316)),
                      const SizedBox(height: 10),
                      _buildModalOption(
                        context,
                        icon: Icons.auto_awesome_rounded,
                        title: '✨ Freedom Request (Jasa Suruh)',
                        subtitle: 'Permintaan bebas apa saja & tawar harga sendiri',
                        color: const Color(0xFFF97316),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BookingOrderTypeScreen(
                            serviceType: 'freedom',
                            partnerData: partnerInfo,
                          )));
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildModalOption(
                        context,
                        icon: Icons.business_center_rounded,
                        title: '💼 Personal Assistant Service',
                        subtitle: 'Asisten harian: bawain koper, belanjaan, bodyguard di club',
                        color: const Color(0xFF8B5CF6),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BookingOrderTypeScreen(
                            serviceType: 'assistant',
                            partnerData: partnerInfo,
                          )));
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildModalOption(
                        context,
                        icon: Icons.search_rounded,
                        title: '🕵️ Detektif Relationship',
                        subtitle: 'Investigasi kesetiaan pasangan & observasi aman terpercaya',
                        color: const Color(0xFFE11D48),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BookingOrderTypeScreen(
                            serviceType: 'detektif',
                            partnerData: partnerInfo,
                          )));
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Tutup Modal',
                    style: GoogleFonts.inter(
                      color: AppTheme.textHighContrast,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillarSectionHeader(String title, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardDeep,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildKetersediaanTabContent() {
    final now = DateTime.now();
    final calendarDays = List.generate(14, (i) => now.add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Status Ketersediaan Driver",
              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryPink, size: 20),
              onPressed: () {
                _fetchRealDriverDetails();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Status: ONLINE & TERSEDIA",
                      style: GoogleFonts.inter(color: AppTheme.success, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Pilih tanggal di bawah untuk melihat slot jam kosong & jadwal pemesanan driver.",
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Legend Indicators
        Text(
          "Indikator Ketersediaan Harian",
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildLegendBadge(const Color(0xFF10B981), "Hijau: Kosong"),
            const SizedBox(width: 8),
            _buildLegendBadge(const Color(0xFFF59E0B), "Orange: Sedikit"),
            const SizedBox(width: 8),
            _buildLegendBadge(const Color(0xFFEF4444), "Merah: Sibuk"),
          ],
        ),
        const SizedBox(height: 20),

        Text(
          "Pilih Tanggal Booking",
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Date Strip
        SizedBox(
          height: 106,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: calendarDays.length,
            itemBuilder: (context, index) {
              final date = calendarDays[index];
              final isSelected = index == _selectedScheduleDayIndex;

              // Calculate real bookings for this specific date
              final dayBookings = _getBookingsForDate(date);
              final slots = _computeHourlySlots(date, dayBookings);
              final count = dayBookings.length;
              final hasActive = dayBookings.any((b) => _isBookingWaitingOrActive(b['status']?.toString() ?? ''));

              Color badgeColor;
              String statusLabel;

              if (count == 0) {
                badgeColor = const Color(0xFF10B981); // Green
                statusLabel = "Kosong";
              } else if (hasActive) {
                badgeColor = const Color(0xFFF59E0B); // Orange
                statusLabel = "⚠️ Terisi ($count)";
              } else if (count >= 3) {
                badgeColor = const Color(0xFFEF4444); // Red
                statusLabel = "Sibuk ($count)";
              } else {
                badgeColor = const Color(0xFF3B82F6); // Blue
                statusLabel = "$count Selesai";
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedScheduleDayIndex = index;
                  });
                  _showDayScheduleBottomSheet(
                    context,
                    date,
                    statusLabel,
                    badgeColor,
                    count,
                    dayBookings,
                    slots,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 76,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryPink.withOpacity(0.15)
                        : (hasActive ? badgeColor.withOpacity(0.08) : AppTheme.surface),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryPink
                          : (hasActive ? badgeColor.withOpacity(0.6) : AppTheme.border),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getShortDayName(date.weekday),
                        style: GoogleFonts.inter(
                          color: isSelected ? AppTheme.primaryPink : AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${date.day}",
                        style: GoogleFonts.inter(
                          color: AppTheme.textHighContrast,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: badgeColor, width: 1),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            color: badgeColor,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Detail Card for currently selected day
        Builder(
          builder: (context) {
            final selectedDate = calendarDays[_selectedScheduleDayIndex < calendarDays.length ? _selectedScheduleDayIndex : 0];
            final dayBookings = _getBookingsForDate(selectedDate);
            final slots = _computeHourlySlots(selectedDate, dayBookings);
            final lockedHours = slots.where((s) => s['isLocked'] == true).length;
            final freeHours = 14 - lockedHours;
            final count = dayBookings.length;
            final hasActive = dayBookings.any((b) => _isBookingWaitingOrActive(b['status']?.toString() ?? ''));

            Color badgeColor = count == 0
                ? const Color(0xFF10B981)
                : (hasActive ? const Color(0xFFF59E0B) : (count >= 3 ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)));
            String statusLabel = count == 0
                ? "Driver Tersedia Bebas"
                : (hasActive ? "⚠️ Ada Jadwal Terkunci ($count)" : "Jadwal Selesai ($count)");

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasActive ? badgeColor.withOpacity(0.6) : AppTheme.border,
                  width: hasActive ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "${_getDayName(selectedDate.weekday)}, ${selectedDate.day} ${_getFullMonthName(selectedDate.month)} ${selectedDate.year}",
                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13.5, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: badgeColor),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.inter(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (hasActive) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Terdapat pesanan yang mengunci jam tertentu driver ($lockedHours Jam Terkunci). Anda tetap dapat memesan di slot jam yang masih FREE.",
                              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11.5, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Text(
                      count == 0
                          ? "Driver memiliki waktu luang penuh di tanggal ini. Siap menerima orderan Anda kapan saja!"
                          : "Terdapat $count kegiatan terdaftar. Anda tetap dapat mengajukan pemesanan di jam yang belum terisi.",
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Hours chips
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_rounded, color: Color(0xFFEF4444), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                "$lockedHours Jam Terkunci",
                                style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                "$freeHours Jam Free",
                                style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showDayScheduleBottomSheet(
                          context,
                          selectedDate,
                          statusLabel,
                          badgeColor,
                          count,
                          dayBookings,
                          slots,
                        );
                      },
                      icon: const Icon(Icons.schedule_rounded, size: 16),
                      label: const Text("LIHAT DETAIL JAM TERKUNCI & FREE"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryPink,
                        side: const BorderSide(color: AppTheme.primaryPink),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showDayScheduleBottomSheet(
    BuildContext context,
    DateTime date,
    String statusLabel,
    Color badgeColor,
    int bookingCount,
    List<Map<String, dynamic>> dayBookings,
    List<Map<String, dynamic>> slots,
  ) {
    final lockedHours = slots.where((s) => s['isLocked'] == true).length;
    final freeHours = 14 - lockedHours;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          bottom: true,
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${_getDayName(date.weekday)}, ${date.day} ${_getFullMonthName(date.month)} ${date.year}",
                            style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$bookingCount Aktivitas Terjadwal ($lockedHours Jam Terkunci)",
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: badgeColor),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Summary chips
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDeep,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text("Total Order: $bookingCount", style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      Container(height: 16, width: 1, color: AppTheme.border),
                      Text("Terkunci: $lockedHours Jam", style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 11.5, fontWeight: FontWeight.bold)),
                      Container(height: 16, width: 1, color: AppTheme.border),
                      Text("Free: $freeHours Jam", style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 8),

                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Ketersediaan Jam (08:00 - 22:00 WIB)",
                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),

                        // Timeline slots
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: slots.length,
                          itemBuilder: (ctx, sIdx) {
                            final slot = slots[sIdx];
                            final isLocked = slot['isLocked'] == true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isLocked ? const Color(0xFFEF4444).withOpacity(0.08) : AppTheme.cardDeep,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isLocked ? const Color(0xFFEF4444).withOpacity(0.4) : AppTheme.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isLocked ? Icons.lock_rounded : Icons.check_circle_outline_rounded,
                                    color: isLocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          slot['label'] as String,
                                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isLocked ? "Terkunci (${slot['timeRangeString']})" : "Driver Bebas / Siap Menerima Pesanan",
                                          style: GoogleFonts.inter(color: isLocked ? const Color(0xFFEF4444) : AppTheme.textMuted, fontSize: 10.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isLocked ? const Color(0xFFEF4444).withOpacity(0.15) : const Color(0xFF10B981).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isLocked ? "TERKUNCI" : "FREE",
                                      style: GoogleFonts.inter(
                                        color: isLocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        Text(
                          "Rincian Pesanan Terjadwal ($bookingCount)",
                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),

                        if (dayBookings.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                const Icon(Icons.event_available_rounded, color: Color(0xFF10B981), size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  "Jadwal Masih Kosong Penuh",
                                  style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Driver siap melayani Anda sepanjang hari ini.",
                                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: dayBookings.length,
                            itemBuilder: (context, idx) {
                              final b = dayBookings[idx];
                              final bStart = _extractBookingDateTime(b);
                              final dur = _extractBookingDurationHours(b);
                              final bEnd = bStart?.add(Duration(hours: dur));

                              final timeFormatted = bStart != null && bEnd != null
                                  ? "${bStart.hour.toString().padLeft(2, '0')}:${bStart.minute.toString().padLeft(2, '0')} - ${bEnd.hour.toString().padLeft(2, '0')}:${bEnd.minute.toString().padLeft(2, '0')} WIB"
                                  : "Waktu Fleksibel";

                              final service = b['service_type'] ?? 'Companion Service';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardDeep,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          service.toString(),
                                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12.5, fontWeight: FontWeight.bold),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Terkunci',
                                            style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.lock_clock_rounded, color: Color(0xFFEF4444), size: 15),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$timeFormatted • Durasi: $dur Jam',
                                          style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 11.5, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Tutup',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendBadge(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildExpStatCard(String value, String title, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: GoogleFonts.inter(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSkillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.fuchsiaLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildLanguageChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language_rounded, color: Colors.blueAccent, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}