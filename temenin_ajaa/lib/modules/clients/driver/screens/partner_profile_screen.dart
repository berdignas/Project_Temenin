import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/modules/clients/chat/screens/chat_room_screen.dart';
import 'package:temenin_ajaa/modules/clients/booking/screens/hangout_booking_screen.dart';

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
  List<String> _skills = [];
  List<String> _languages = [];
  List<String> _activeServices = ['ride', 'sporty', 'hangout', 'freedom', 'counseling', 'curhat', 'detective', 'hiking', 'assistant'];
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
          } catch (e) {
            debugPrint('Error parsing vehicle_stnk metadata in client: $e');
          }
        } else if (vehicleStnk.isNotEmpty && !vehicleStnk.startsWith('http')) {
          _driverBio = vehicleStnk;
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
              'type': (vType != null && vType.isNotEmpty) ? vType : 'Motor',
              'name': vName,
              'plate_number': (vPlate != null && vPlate.isNotEmpty) ? vPlate : '',
              'image': (vImg != null && vImg.isNotEmpty) ? vImg : null,
              'age': '< 5 Tahun',
            });
          }
        }
      }

      final targetDriverId = _dbDriverData?['id'] ?? driverId;
      final targetUserId = _dbDriverData?['user_id'] ?? userId;
      if (targetDriverId != null || targetUserId != null) {
        // Fetch reviews
        final orFilter = targetUserId != null 
            ? 'driver_id.eq.$targetDriverId,user_id.eq.$targetUserId' 
            : 'driver_id.eq.$targetDriverId';
        final List<dynamic> revRows = await supabase
            .from('reviews')
            .select('*, users(full_name, avatar_url)')
            .or(orFilter)
            .order('created_at', ascending: false);

        if (revRows.isNotEmpty) {
          _dbReviews = revRows.map((r) {
            final userObj = r['users'] ?? {};
            return {
              'author': userObj['full_name'] ?? 'Pelanggan Temenin Ajaa',
              'avatar': userObj['avatar_url'] ?? '',
              'rating': double.tryParse(r['rating']?.toString() ?? '5.0') ?? 5.0,
              'text': r['comment'] ?? 'Sangat ramah, tepat waktu & pelayanan luar biasa.',
              'date': r['created_at']?.toString().split('T')[0] ?? '',
            };
          }).toList();
        }

        // Fetch real driver bookings for availability calendar
        final List<dynamic> bookingRows = await supabase
            .from('bookings')
            .select('*')
            .or(orFilter)
            .order('created_at', ascending: false);

        _driverBookings = List<Map<String, dynamic>>.from(bookingRows);
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
        : (_dbDriverData?['rating'] != null ? _dbDriverData!['rating'].toString() : rating);

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
    final priceVal = _dbDriverData?['price_per_hour'] ?? widget.partnerData?['price'] ?? 50000;
    final displayPrice = 'Rp ${priceVal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.'
    )}';

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

        Text(
          'Kendaraan Terdaftar (${_parsedVehicles.length})',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_parsedVehicles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'Belum ada kendaraan yang diatur oleh driver.',
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12.5, fontStyle: FontStyle.italic),
            ),
          )
        else
          Column(
            children: _parsedVehicles.map((v) {
              final vName = v['name'] ?? 'Kendaraan Driver';
              final vPlate = v['plate_number'] ?? '';
              final vType = v['type'] ?? 'Kendaraan';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.fuchsiaLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        vType.toString().toLowerCase().contains('mobil')
                            ? Icons.directions_car_rounded
                            : Icons.two_wheeler_rounded,
                        color: AppTheme.primaryPink,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vName,
                            style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          if (vPlate.isNotEmpty)
                            Text(
                              'Plat Nomor: $vPlate',
                              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                            ),
                          const SizedBox(height: 3),
                          Text(
                            'Tarif: $displayPrice / Jam',
                            style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Terverifikasi',
                        style: GoogleFonts.inter(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 20),

        Text(
          'Layanan yang Disediakan (${_activeServices.length})',
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

            if (key == 'ride') { title = '🚕 Ride Service'; icon = Icons.local_taxi_rounded; color = AppTheme.primaryPink; }
            else if (key == 'sporty') { title = '🏎️ Antar Jemput Sporty'; icon = Icons.sports_motorsports_rounded; color = Colors.orange; }
            else if (key == 'hangout') { title = '🍸 Hangout Companion'; icon = Icons.wine_bar_rounded; color = const Color(0xFFD97706); }
            else if (key == 'freedom') { title = '✨ Freedom Request'; icon = Icons.auto_awesome_rounded; color = const Color(0xFFFF8552); }
            else if (key == 'counseling') { title = '💬 Relationship Counseling'; icon = Icons.psychology_rounded; color = Colors.blueAccent; }
            else if (key == 'curhat') { title = '👂 Mendengarkan Curhat'; icon = Icons.hearing_rounded; color = Colors.teal; }
            else if (key == 'detective') { title = '🕵️ Detektif Relationship'; icon = Icons.policy_rounded; color = Colors.redAccent; }
            else if (key == 'hiking') { title = '🧗 Hiking Partner'; icon = Icons.landscape_rounded; color = Colors.green; }
            else if (key == 'assistant') { title = '💼 Personal Assistance'; icon = Icons.business_center_rounded; color = Colors.purple; }

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
        : (_dbDriverData?['rating'] != null ? _dbDriverData!['rating'].toString() : '5.0');

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
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildReviewCard(
                  r['author'] ?? 'Pelanggan',
                  (r['rating'] as num).toDouble(),
                  '"${r['text']}"',
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
          const SizedBox(height: 6),
          Text(
            text,
            style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12, height: 1.4, fontStyle: FontStyle.italic),
          ),
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
                      tag: name == 'Sarah Jessica' ? 'Platinum' : 'Gold',
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
                      };
                      if (service == 'ride') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HangoutBookingScreen(
                              selectedPartner: partnerInfo,
                              serviceType: 'regular',
                            ),
                          ),
                        );
                      } else if (service == 'sporty') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HangoutBookingScreen(
                              selectedPartner: partnerInfo,
                              serviceType: 'sporty',
                            ),
                          ),
                        );
                      } else if (service == 'freedom') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HangoutBookingScreen(
                              selectedPartner: partnerInfo,
                              serviceType: 'freedom',
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HangoutBookingScreen(
                              selectedPartner: partnerInfo,
                              serviceType: service,
                            ),
                          ),
                        );
                      }
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
                    children: [
                      if (_activeServices.contains('ride')) ...[
                        _buildModalOption(
                          context,
                          icon: Icons.local_taxi_rounded,
                          title: '🚕 Ride Service',
                          subtitle: 'Diantar perjalanan aman & nyaman',
                          color: AppTheme.primaryPink,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                              serviceType: 'regular',
                              selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                            )));
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (_activeServices.contains('sporty')) ...[
                        _buildModalOption(
                          context,
                          icon: Icons.sports_motorsports_rounded,
                          title: '🏎️ Antar Jemput Sporty',
                          subtitle: 'Kendaraan mewah & performa tinggi',
                          color: Colors.orange,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                              serviceType: 'sporty',
                              selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                            )));
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (_activeServices.contains('hangout')) ...[
                        _buildModalOption(
                          context,
                          icon: Icons.wine_bar_rounded,
                          title: '🍸 Hangout Service',
                          subtitle: 'Teman nongkrong di cafe/restoran',
                          color: const Color(0xFFD97706),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                              serviceType: 'hangout',
                              selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                            )));
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (_activeServices.contains('freedom')) ...[
                        _buildModalOption(
                          context,
                          icon: Icons.auto_awesome_rounded,
                          title: '✨ Freedom Request (Negosiasi)',
                          subtitle: 'Tentukan acara & tawar harga sendiri',
                          color: const Color(0xFFFF8552),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                              serviceType: 'freedom',
                              selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                            )));
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (_activeServices.contains('counseling')) ...[
                        _buildModalOption(
                          context,
                          icon: Icons.psychology_rounded,
                          title: '💬 Relationship Counseling',
                          subtitle: 'Konsultasi masalah asmara profesional',
                          color: Colors.blueAccent,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                              serviceType: 'counseling',
                              selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                            )));
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (_activeServices.contains('curhat')) ...[
                        _buildModalOption(
                          context,
                          icon: Icons.hearing_rounded,
                          title: '👂 Mendengarkan Curhat',
                          subtitle: 'Teman cerita yang penuh empati',
                          color: Colors.teal,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                              serviceType: 'curhat',
                              selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                            )));
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (_activeServices.contains('detective')) ...[
                        _buildModalOption(
                          context,
                          icon: Icons.policy_rounded,
                          title: '🕵️ Detektif Relationship',
                          subtitle: 'Penyelidikan rahasia & pemantauan',
                          color: Colors.redAccent,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                              serviceType: 'detective',
                              selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                            )));
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (_activeServices.contains('hiking')) ...[
                        _buildModalOption(
                          context,
                          icon: Icons.landscape_rounded,
                          title: '🧗 Hiking Partner',
                          subtitle: 'Teman mendaki alam yang seru',
                          color: Colors.green,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                              serviceType: 'hiking',
                              selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                            )));
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (_activeServices.contains('assistant')) ...[
                        _buildModalOption(
                          context,
                          icon: Icons.business_center_rounded,
                          title: '💼 Personal Assistance',
                          subtitle: 'Bantuan harian (bawa barang, dll)',
                          color: Colors.purple,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => HangoutBookingScreen(
                              serviceType: 'assistant',
                              selectedPartner: {'id': widget.partnerData?['id'] ?? 'drv-1', 'name': name, 'vehicle': vehicle, 'rating': rating, 'image': image, 'price': price, 'type': widget.partnerData?['type'] ?? 'Platinum'},
                            )));
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
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
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: calendarDays.length,
            itemBuilder: (context, index) {
              final date = calendarDays[index];
              final isSelected = index == _selectedScheduleDayIndex;

              // Calculate real bookings for this specific date
              final dayBookings = _driverBookings.where((b) {
                final rawDateStr = b['scheduled_at'] ?? b['created_at'] ?? '';
                if (rawDateStr == null || rawDateStr.toString().isEmpty) return false;
                try {
                  final d = DateTime.parse(rawDateStr.toString());
                  return d.year == date.year && d.month == date.month && d.day == date.day && b['status'] != 'cancelled';
                } catch (_) {
                  return false;
                }
              }).toList();

              final count = dayBookings.length;
              Color badgeColor;
              String statusLabel;

              if (count == 0) {
                badgeColor = const Color(0xFF10B981); // Green
                statusLabel = "Kosong";
              } else if (count <= 2) {
                badgeColor = const Color(0xFFF59E0B); // Orange
                statusLabel = "Sedikit";
              } else {
                badgeColor = const Color(0xFFEF4444); // Red
                statusLabel = "Sibuk";
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedScheduleDayIndex = index;
                  });
                  _showDayScheduleBottomSheet(context, date, statusLabel, badgeColor, count, dayBookings);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryPink.withOpacity(0.15) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryPink : AppTheme.border,
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: badgeColor, width: 1),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            color: badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
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
            final dayBookings = _driverBookings.where((b) {
              final rawDateStr = b['scheduled_at'] ?? b['created_at'] ?? '';
              if (rawDateStr == null || rawDateStr.toString().isEmpty) return false;
              try {
                final d = DateTime.parse(rawDateStr.toString());
                return d.year == selectedDate.year && d.month == selectedDate.month && d.day == selectedDate.day && b['status'] != 'cancelled';
              } catch (_) {
                return false;
              }
            }).toList();

            final count = dayBookings.length;
            Color badgeColor = count == 0 ? const Color(0xFF10B981) : (count <= 2 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
            String statusLabel = count == 0 ? "Driver Tersedia Bebas" : (count <= 2 ? "Ada Beberapa Pesanan" : "Jadwal Padat / Sibuk");

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
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
                          "$count Pesanan",
                          style: GoogleFonts.inter(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    statusLabel,
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count == 0
                        ? "Driver memiliki waktu luang penuh di tanggal ini. Siap menerima orderan Anda kapan saja!"
                        : "Terdapat $count kegiatan terdaftar. Anda tetap dapat mengajukan pemesanan di jam yang belum terisi.",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5, height: 1.4),
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
  ) {
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
              maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                            "$bookingCount Aktivitas Terjadwal",
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
                const SizedBox(height: 16),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 10),

                Flexible(
                  child: dayBookings.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event_available_rounded, color: Color(0xFF10B981), size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  "Jadwal Masih Kosong",
                                  style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Driver siap melayani sepanjang hari ini. Pesan sekarang untuk mengamankan jadwal!",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: dayBookings.length,
                          itemBuilder: (context, idx) {
                            final b = dayBookings[idx];
                            final timeStr = (b['scheduled_at'] ?? b['created_at'] ?? '').toString();
                            String formattedTime = 'Waktu Fleksibel';
                            try {
                              if (timeStr.isNotEmpty) {
                                final dt = DateTime.parse(timeStr);
                                formattedTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB';
                              }
                            } catch (_) {}

                            final service = b['service_type'] ?? 'Companion Service';
                            final duration = b['duration_hours'] != null ? '${b['duration_hours']} Jam' : 'Sesi Pemesanan';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.cardDeep,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryPink.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.access_time_rounded, color: AppTheme.primaryPink, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          service,
                                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 12.5, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$formattedTime • Durasi: $duration',
                                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Terjadwal',
                                      style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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