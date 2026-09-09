// lib/modules/driver/screens/partner_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/providers/driver_provider.dart';
import 'partner_profile_screen.dart';

class PartnerListScreen extends StatefulWidget {
  const PartnerListScreen({super.key});

  @override
  State<PartnerListScreen> createState() => _PartnerListScreenState();
}

class _PartnerListScreenState extends State<PartnerListScreen> {
  String _activeFilter = 'All';
  String _activeGenderFilter = 'Semua';
  String _activeServiceFilter = 'Semua Layanan';

  final List<String> _filters = ['All', 'Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'VVIP'];
  final List<String> _genderFilters = ['Semua', 'Perempuan', 'Laki-laki'];
  final List<String> _serviceFilters = ['Semua Layanan', 'Ride', 'Hangout', 'Counseling', 'Curhat', 'Detective', 'Hiking', 'Assistant'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverProvider>().subscribeToDriversRealtime();
      context.read<DriverProvider>().fetchDrivers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final driverProvider = context.watch<DriverProvider>();
    final List<Map<String, dynamic>> drivers = driverProvider.drivers;

    // Filter list by class, gender AND service
    final filteredList = drivers.where((partner) {
      final matchesFilter = _activeFilter == 'All' || partner['type'] == _activeFilter;
      final matchesGender = _activeGenderFilter == 'Semua' || partner['gender'] == _activeGenderFilter;
      
      bool matchesService = true;
      if (_activeServiceFilter != 'Semua Layanan') {
        final activeServices = partner['activeServices'] as List<String>? ?? [];
        final serviceKey = _activeServiceFilter.toLowerCase();
        matchesService = activeServices.contains(serviceKey);
      }
      
      return matchesFilter && matchesGender && matchesService;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          "Temenin Ajaa",
          style: GoogleFonts.inter(
            color: AppTheme.primaryPink,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  "Daftar Partner",
                  style: GoogleFonts.inter(
                    color: AppTheme.textHighContrast,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Temukan partner terbaik sesuai kelas dan kebutuhan Anda.",
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 15),
                
                // Filter Chips (Membership Class)
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    itemBuilder: (context, index) {
                      final filterName = _filters[index];
                      final isActive = _activeFilter == filterName;
                      return GestureDetector(
                        onTap: () => setState(() => _activeFilter = filterName),
                        child: _buildFilterChip(filterName, isActive: isActive),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Filter Chips (Services)
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _serviceFilters.length,
                    itemBuilder: (context, index) {
                      final filterName = _serviceFilters[index];
                      final isActive = _activeServiceFilter == filterName;
                      return GestureDetector(
                        onTap: () => setState(() => _activeServiceFilter = filterName),
                        child: _buildFilterChip(filterName, isActive: isActive),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Gender Preference Toggle
                Text(
                  "PREFERENSI GENDER",
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: _genderFilters.map((g) {
                    final isSelected = _activeGenderFilter == g;
                    return GestureDetector(
                      onTap: () => setState(() => _activeGenderFilter = g),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryPink : AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryPink : AppTheme.border,
                          ),
                        ),
                        child: Text(
                          g,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white : AppTheme.textHighContrast,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
          
          // List Drivers
          Expanded(
            child: driverProvider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryPink),
                  )
                : filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, color: AppTheme.textMuted, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              "Tidak ada partner ditemukan",
                              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final partner = filteredList[index];
                          return _buildPartnerCard(
                            id: partner['id'] ?? '',
                            name: partner['name'] ?? '',
                            vehicle: partner['vehicle'] ?? '',
                            rating: partner['rating']?.toString() ?? '5.0',
                            status: partner['status'] ?? 'Available',
                            type: partner['type'] ?? 'Gold',
                            image: partner['image'] ?? '',
                            gender: partner['gender'] ?? 'Laki-laki',
                            kpi: partner['kpi'] ?? 80,
                            description: partner['description'] ?? '',
                            price: partner['price'] ?? 50000,
                            trips: (partner['kpi'] ?? 60) * 2,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isActive = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryPink : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppTheme.primaryPink : AppTheme.border,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isActive ? Colors.white : AppTheme.textHighContrast,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerCard({
    required dynamic id,
    required String name,
    required String vehicle,
    required String rating,
    required String status,
    required String type,
    required String image,
    required String gender,
    required int kpi,
    required String description,
    required int price,
    required int trips,
  }) {
    final isAvailable = status.toLowerCase() == 'available' || status.toLowerCase() == 'tersedia';
    
    Color classColor = const Color(0xFFEAB308); // Gold default
    if (type == 'Bronze') classColor = const Color(0xFFCD7F32);
    if (type == 'Silver') classColor = const Color(0xFF94A3B8);
    if (type == 'Platinum') classColor = const Color(0xFF0284C7);
    if (type == 'Diamond') classColor = const Color(0xFF9333EA);
    if (type == 'VVIP') classColor = AppTheme.primaryPink;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.network(
                  (image.isNotEmpty && !image.contains('placeholder') && !image.contains('dummy'))
                      ? image
                      : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name.isNotEmpty ? name : "Temen")}&background=D64573&color=fff&bold=true', 
                  height: 190, 
                  width: double.infinity, 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.network(
                      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name.isNotEmpty ? name : "Temen")}&background=D64573&color=fff&bold=true',
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: classColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    type.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: Colors.white, size: 10),
                      SizedBox(width: 4),
                      Text("TERVERIFIKASI", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 4),
                      Text(rating, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name, 
                              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              gender == 'Perempuan' ? Icons.female_rounded : Icons.male_rounded,
                              color: gender == 'Perempuan' ? AppTheme.primaryPink : const Color(0xFF0284C7),
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.directions_bike_rounded, size: 14, color: AppTheme.textMuted),
                            const SizedBox(width: 6),
                            Text(vehicle, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isAvailable ? AppTheme.success.withOpacity(0.12) : AppTheme.cardDeep,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isAvailable ? AppTheme.success : AppTheme.border),
                      ),
                      child: Text(
                        isAvailable ? "Tersedia" : "Sibuk",
                        style: TextStyle(
                          color: isAvailable ? AppTheme.success : AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: AppTheme.border, height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.fuchsiaLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Performa KPI: $kpi%",
                        style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: isAvailable ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PartnerProfileScreen(
                              partnerData: {
                                'id': id,
                                'name': name,
                                'vehicle': vehicle,
                                'rating': rating,
                                'status': status,
                                'type': type,
                                'image': image,
                                'gender': gender,
                                'kpi': kpi,
                                'description': description,
                                'price': price,
                                'trips': trips,
                              },
                            ),
                          ),
                        );
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        elevation: 0,
                      ),
                      child: const Text("Pilih Partner", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}