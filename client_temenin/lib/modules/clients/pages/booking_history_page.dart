// lib/modules/home/pages/booking_history_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/models/booking_model.dart';
import '../../../core/theme/app_theme.dart';
import '../services/booking_service.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({super.key});

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  final BookingService _bookingService = BookingService();
  List<BookingModel> _bookings = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'All';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _filters = ['All', 'Ongoing', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id ?? '';
      final result = await _bookingService.getBookingHistory(userId);
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        setState(() {
          _bookings = result['bookings'];
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _bookings = [];
          _isLoading = false;
          _errorMessage = result['message'] ?? 'Gagal memuat riwayat booking';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bookings = [];
        _isLoading = false;
        _errorMessage = 'Terjadi kesalahan: $e';
      });
    }
  }

  List<BookingModel> _getRichMockBookings() {
    return [
      BookingModel(
        id: 'BKG-9842',
        userId: 'usr-1',
        driverId: 'drv-1',
        status: 'Ongoing',
        pickupLocation: 'Senayan City Mall (Lobby South)',
        dropoffLocation: 'Cafe Batavia, Kota Tua',
        totalPrice: 150000,
        bookingDate: DateTime.now().subtract(const Duration(minutes: 30)),
        driver: DriverModel(
          vehicleName: 'Sarah Jessica',
          vehicleType: 'Hangout & Sesi Curhat',
          plateNumber: 'B 1982 NOAH',
          pricePerHour: 150000,
          rating: 4.9,
        ),
      ),
      BookingModel(
        id: 'BKG-8712',
        userId: 'usr-1',
        driverId: 'drv-2',
        status: 'Completed',
        pickupLocation: 'Pondok Indah Mall 2',
        dropoffLocation: 'BSD Breeze Food Court',
        totalPrice: 175000,
        bookingDate: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        driver: DriverModel(
          vehicleName: 'Rayhan Putra',
          vehicleType: 'Ride & City Tour Vespa',
          plateNumber: 'B 1234 XY',
          pricePerHour: 175000,
          rating: 4.8,
        ),
      ),
      BookingModel(
        id: 'BKG-5431',
        userId: 'usr-1',
        driverId: 'drv-3',
        status: 'Completed',
        pickupLocation: 'Semanang Park',
        dropoffLocation: 'Gunung Gede Nature Reserve',
        totalPrice: 200000,
        bookingDate: DateTime.now().subtract(const Duration(days: 3)),
        driver: DriverModel(
          vehicleName: 'Dimas Setiawan',
          vehicleType: 'Hiking Companion',
          plateNumber: 'B 8888 DM',
          pricePerHour: 200000,
          rating: 5.0,
        ),
      ),
      BookingModel(
        id: 'BKG-3129',
        userId: 'usr-1',
        driverId: 'drv-4',
        status: 'Cancelled',
        pickupLocation: 'Online Voice Call',
        dropoffLocation: '-',
        totalPrice: 120000,
        bookingDate: DateTime.now().subtract(const Duration(days: 5)),
        driver: DriverModel(
          vehicleName: 'Amanda Wijaya',
          vehicleType: 'Counseling & Discussion',
          plateNumber: '-',
          pricePerHour: 120000,
          rating: 4.7,
        ),
      ),
    ];
  }

  List<BookingModel> get _filteredBookings {
    List<BookingModel> filtered = _bookings;
    if (_selectedFilter != 'All') {
      filtered = filtered.where((b) => b.status == _selectedFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((b) {
        return b.id.toLowerCase().contains(query) ||
               (b.driver?.vehicleName?.toLowerCase().contains(query) ?? false) ||
               (b.pickupLocation?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.inter(color: AppTheme.textHighContrast),
                decoration: InputDecoration(
                  hintText: 'Cari riwayat booking...',
                  hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : Text(
                'Riwayat Booking',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textHighContrast,
                  fontWeight: FontWeight.bold,
                ),
              ),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search_rounded,
              color: AppTheme.textHighContrast,
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: Container(
        color: AppTheme.background,
        child: Column(
          children: [
            // Filter tabs
            Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppTheme.primaryGradient : null,
                        color: isSelected ? null : AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected 
                              ? Colors.transparent
                              : AppTheme.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          filter,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white : AppTheme.textMuted,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryPink,
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadBookings,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryPink,
                                ),
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        )
                      : _filteredBookings.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    size: 80,
                                    color: AppTheme.textMuted.withOpacity(0.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Tidak ada riwayat booking',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredBookings.length,
                              itemBuilder: (context, index) {
                                final booking = _filteredBookings[index];
                                return GestureDetector(
                                  onTap: () => _showBookingDetail(context, booking),
                                  child: _buildBookingCard(booking),
                                );
                              },
                            ),
            ),
            const SizedBox(height: 100), // Prevent bottom overflow
          ],
        ),
      ),
    );
  }

  void _showBookingDetail(BuildContext context, BookingModel booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Detail Pesanan',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textHighContrast,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: booking.status.toLowerCase() == 'completed'
                                  ? AppTheme.success.withOpacity(0.12)
                                  : booking.status.toLowerCase() == 'cancelled'
                                      ? AppTheme.danger.withOpacity(0.12)
                                      : AppTheme.primaryPink.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              booking.status.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: booking.status.toLowerCase() == 'completed'
                                    ? AppTheme.success
                                    : booking.status.toLowerCase() == 'cancelled'
                                        ? AppTheme.danger
                                        : AppTheme.primaryPink,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ID: ${booking.id}',
                        style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Driver Detail
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppTheme.fuchsiaLight,
                              child: const Icon(Icons.person, color: AppTheme.primaryPink),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    booking.driver?.vehicleName ?? 'Partner Name',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.textHighContrast,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    booking.driver?.vehicleType ?? 'Service Type',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Location & Time
                      Text(
                        'Informasi Perjalanan',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textHighContrast,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(Icons.calendar_today, 'Waktu', _formatDate(booking.bookingDate)),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: AppTheme.border, height: 1),
                            ),
                            _buildDetailRow(Icons.location_on, 'Penjemputan', booking.pickupLocation ?? '-'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: AppTheme.border, height: 1),
                            ),
                            _buildDetailRow(Icons.location_off, 'Tujuan', booking.dropoffLocation ?? '-'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Payment Info
                      Text(
                        'Ringkasan Pembayaran',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textHighContrast,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Biaya Layanan', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                                Text('Rp ${_formatPrice(booking.totalPrice)}', style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Biaya Aplikasi', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                                Text('Rp 5.000', style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: AppTheme.border, height: 1),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Pembayaran', style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold)),
                                Text(
                                  'Rp ${_formatPrice((booking.totalPrice ?? 0) + 5000)}',
                                  style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Download Invoice Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Mengunduh Invoice PDF untuk pesanan ${booking.id}...'),
                                backgroundColor: AppTheme.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.download_rounded, color: Colors.white),
                          label: Text(
                            'Download Invoice / Faktur',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPink,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryPink, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: AppTheme.textHighContrast,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    Color statusColor;
    IconData statusIcon;
    
    switch (booking.status.toLowerCase()) {
      case 'ongoing':
        statusColor = AppTheme.primaryPink;
        statusIcon = Icons.play_circle_outline;
        break;
      case 'completed':
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'cancelled':
        statusColor = AppTheme.danger;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  booking.status.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(booking.bookingDate),
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.fuchsiaLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_pin_rounded,
                        size: 24,
                        color: AppTheme.primaryPink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.driver?.vehicleName ?? 'Partner Name',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textHighContrast,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            booking.driver?.vehicleType ?? 'Service',
                            style: GoogleFonts.inter(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.fuchsiaLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.2)),
                      ),
                      child: Text(
                        'Rp ${_formatPrice(booking.totalPrice)}',
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryPink,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.border, height: 1),
                const SizedBox(height: 16),
                // Pickup location
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: AppTheme.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        booking.pickupLocation ?? 'Lokasi Penjemputan',
                        style: GoogleFonts.inter(
                          color: AppTheme.textHighContrast,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (booking.dropoffLocation != null && booking.dropoffLocation != '-') ...[
                  const SizedBox(height: 8),
                  // Dropoff location
                  Row(
                    children: [
                      const Icon(Icons.location_off, size: 16, color: AppTheme.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.dropoffLocation!,
                          style: GoogleFonts.inter(
                            color: AppTheme.textHighContrast,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Action buttons (if ongoing)
          if (booking.status.toLowerCase() == 'ongoing')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showCancelDialog(context, booking),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        side: const BorderSide(color: AppTheme.danger),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Batalkan', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _trackBooking(booking),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Lacak', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatPrice(int? price) {
    if (price == null) return '0';
    return price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  void _showCancelDialog(BuildContext context, BookingModel booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Batalkan Pesanan',
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan pesanan ini?',
          style: GoogleFonts.inter(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tidak', style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pesanan berhasil dibatalkan')),
              );
              _loadBookings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Ya, Batalkan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _trackBooking(BookingModel booking) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Melacak pesanan: ${booking.id}')),
    );
  }
}