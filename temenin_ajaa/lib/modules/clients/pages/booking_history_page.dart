// lib/modules/home/pages/booking_history_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/models/booking_model.dart';
import '../../../core/theme/app_theme.dart';
import '../services/booking_service.dart';
import '../booking/screens/tracking_driver_screen.dart';
import '../booking/screens/client_waiting_countdown_screen.dart';
import '../booking/screens/call_lobby_screen.dart';
import '../booking/screens/call_room_screen.dart';

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
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id ?? Supabase.instance.client.auth.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        _realtimeSub = Supabase.instance.client
            .from('bookings')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)
            .handleError((err) {
              debugPrint("BookingHistoryPage realtime stream error handled: $err");
            })
            .listen(
              (_) {
                if (mounted) {
                  _loadBookings(showLoading: false);
                }
              },
              onError: (err) {
                debugPrint("BookingHistoryPage realtime stream error: $err");
              },
              cancelOnError: false,
            );
      }
    } catch (e) {
      debugPrint("BookingHistoryPage realtime subscription error: $e");
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id ?? Supabase.instance.client.auth.currentUser?.id;
      
      List<BookingModel> loadedBookings = [];

      // 1. Fetch real bookings from Supabase database
      if (userId != null && userId.isNotEmpty) {
        try {
          final List<dynamic> rows = await Supabase.instance.client
              .from('bookings')
              .select('*, drivers(*, users(*))')
              .eq('user_id', userId)
              .order('created_at', ascending: false);

          if (rows.isNotEmpty) {
            loadedBookings = rows.map((r) => BookingModel.fromJson(r)).toList();
          }
        } catch (e) {
          debugPrint("Supabase fetch bookings with drivers error: $e. Retrying flat select...");
          try {
            final List<dynamic> flatRows = await Supabase.instance.client
                .from('bookings')
                .select('*')
                .eq('user_id', userId)
                .order('created_at', ascending: false);
            if (flatRows.isNotEmpty) {
              loadedBookings = flatRows.map((r) => BookingModel.fromJson(r)).toList();
            }
          } catch (err) {
            debugPrint("Supabase flat fetch bookings error: $err");
          }
        }
      }

      // 2. Fallback to API endpoint if Supabase fetch is empty
      if (loadedBookings.isEmpty && userId != null && userId.isNotEmpty) {
        final result = await _bookingService.getBookingHistory(userId);
        if (result['success'] == true && result['bookings'] != null) {
          loadedBookings = List<BookingModel>.from(result['bookings']);
        }
      }

      if (!mounted) return;

      setState(() {
        _bookings = loadedBookings;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bookings = [];
        _isLoading = false;
        _errorMessage = 'Terjadi kesalahan: $e';
      });
    }
  }

  List<BookingModel> get _filteredBookings {
    List<BookingModel> filtered = _bookings;
    if (_selectedFilter != 'All') {
      final filterLower = _selectedFilter.toLowerCase();
      filtered = filtered.where((b) {
        final statusLower = b.status.toLowerCase();
        if (filterLower == 'completed') {
          return b.isCompleted;
        }
        if (filterLower == 'ongoing') {
          return !b.isCompleted &&
                 (statusLower == 'ongoing' || 
                  statusLower == 'accepted' || 
                  statusLower == 'confirmed' ||
                  statusLower == 'started' || 
                  statusLower == 'on_the_way' || 
                  statusLower == 'arrived' || 
                  statusLower == 'pending' ||
                  statusLower == 'dp_paid');
        }
        if (filterLower == 'cancelled') {
          return statusLower == 'cancelled' || statusLower == 'canceled' || statusLower == 'rejected';
        }
        return statusLower == filterLower;
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((b) {
        final partnerName = (b.driver?.fullName ?? b.driver?.vehicleName ?? b.additionalDetails?['driverName'] ?? '').toLowerCase();
        return b.id.toLowerCase().contains(query) ||
               partnerName.contains(query) ||
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
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.primaryPink.withOpacity(0.18),
                                            AppTheme.fuchsiaLight.withOpacity(0.08),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.primaryPink.withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryPink.withOpacity(0.15),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          )
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long_rounded,
                                        size: 56,
                                        color: AppTheme.primaryPink,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Belum Ada Pesanan',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.textHighContrast,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Riwayat aktivitas, perjalanan, dan pendampingan Anda akan tersimpan rapi di sini.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: AppTheme.textMuted,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (Navigator.canPop(context)) {
                                          Navigator.pop(context);
                                        }
                                      },
                                      icon: const Icon(Icons.explore_rounded, size: 18),
                                      label: Text(
                                        'Mulai Jelajah Temen',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryPink,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 4,
                                        shadowColor: AppTheme.primaryPink.withOpacity(0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadBookings,
                              color: AppTheme.primaryPink,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                              color: booking.isCompleted
                                  ? AppTheme.success.withOpacity(0.12)
                                  : (booking.status.toLowerCase() == 'cancelled' || booking.status.toLowerCase() == 'canceled')
                                      ? AppTheme.danger.withOpacity(0.12)
                                      : AppTheme.primaryPink.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              booking.isCompleted
                                  ? 'SELESAI (COMPLETED)'
                                  : (booking.status.toLowerCase() == 'cancelled' || booking.status.toLowerCase() == 'canceled')
                                      ? 'DIBATALKAN'
                                      : 'SEDANG BERJALAN',
                              style: GoogleFonts.inter(
                                color: booking.isCompleted
                                    ? AppTheme.success
                                    : (booking.status.toLowerCase() == 'cancelled' || booking.status.toLowerCase() == 'canceled')
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
                              backgroundImage: (booking.driver?.avatarUrl != null && booking.driver!.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(booking.driver!.avatarUrl!)
                                  : null,
                              child: (booking.driver?.avatarUrl == null || booking.driver!.avatarUrl!.isEmpty)
                                  ? const Icon(Icons.person, color: AppTheme.primaryPink)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    booking.driver?.fullName ?? booking.driver?.vehicleName ?? booking.additionalDetails?['driverName'] ?? 'Partner Temenin',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.textHighContrast,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    booking.driver?.vehicleType ?? booking.additionalDetails?['serviceType'] ?? 'Layanan Pendampingan',
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
                                Text('Status Pembayaran', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (booking.isPaid ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    booking.isPaid ? 'LUNAS (100%)' : 'DP TERBAYAR (50%)',
                                    style: GoogleFonts.inter(
                                      color: booking.isPaid ? AppTheme.success : AppTheme.warning,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(color: AppTheme.border, height: 1),
                            ),
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
                                Text('DP 50% (Awal)', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                                Text('Rp ${_formatPrice(booking.downPayment)}', style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Pelunasan Sisa', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                                Text(
                                  booking.isPaid ? 'Rp ${_formatPrice(booking.remainingPayment)} (Lunas)' : 'Rp ${_formatPrice(booking.remainingPayment)} (Belum)',
                                  style: GoogleFonts.inter(
                                    color: booking.isPaid ? AppTheme.success : AppTheme.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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

                      if (booking.reviewRating != null || (booking.reviewComment != null && booking.reviewComment!.isNotEmpty)) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Ulasan & Penilaian Anda',
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Row(
                                    children: List.generate(5, (index) {
                                      final starVal = index + 1;
                                      final isFilled = starVal <= (booking.reviewRating ?? 5.0);
                                      return Icon(
                                        isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                                        color: const Color(0xFFF59E0B),
                                        size: 20,
                                      );
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${(booking.reviewRating ?? 5.0).toStringAsFixed(1)} / 5.0",
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textHighContrast,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              if (booking.reviewComment != null && booking.reviewComment!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '"${booking.reviewComment!}"',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textMuted,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      if (booking.driverRatingClient != null || (booking.driverCommentClient != null && booking.driverCommentClient!.isNotEmpty)) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Catatan & Penilaian dari Companion',
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
                            border: Border.all(color: const Color(0xFF00FF7F).withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Row(
                                    children: List.generate(5, (index) {
                                      final starVal = index + 1;
                                      final isFilled = starVal <= (booking.driverRatingClient ?? 5.0);
                                      return Icon(
                                        isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                                        color: const Color(0xFF00FF7F),
                                        size: 20,
                                      );
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${(booking.driverRatingClient ?? 5.0).toStringAsFixed(1)} / 5.0",
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textHighContrast,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              if (booking.driverCommentClient != null && booking.driverCommentClient!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '"${booking.driverCommentClient!}"',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textHighContrast,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      
                      // Action button for active/ongoing bookings
                      if (!booking.isCompleted && !booking.isCancelled) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _trackBooking(booking);
                            },
                            icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
                            label: Text(
                              booking.status.toLowerCase() == 'pending'
                                  ? 'Pantau Status / Tunggu Konfirmasi'
                                  : (booking.status.toLowerCase() == 'accepted'
                                      ? 'Lanjutkan Pembayaran DP'
                                      : (booking.isVirtual ? 'Buka Sesi Virtual' : 'Buka Halaman Pesanan Berlangsung')),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPink,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // Download Invoice Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
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
                          icon: const Icon(Icons.download_rounded, color: Colors.white70),
                          label: Text(
                            'Download Invoice / Faktur',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.border),
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
    final isDone = booking.isCompleted;
    final isCancelled = booking.isCancelled;
    final isOngoing = !isDone && !isCancelled && (
      booking.status.toLowerCase() == 'ongoing' ||
      booking.status.toLowerCase() == 'started' ||
      booking.status.toLowerCase() == 'in_progress' ||
      booking.status.toLowerCase() == 'on_the_way' ||
      booking.status.toLowerCase() == 'arrived'
    );

    Color statusColor;
    IconData statusIcon;
    String displayStatus;
    
    if (isDone) {
      statusColor = AppTheme.success;
      statusIcon = Icons.check_circle_outline;
      displayStatus = 'SELESAI';
    } else if (isCancelled) {
      statusColor = AppTheme.danger;
      statusIcon = Icons.cancel_outlined;
      displayStatus = 'DIBATALKAN';
    } else if (isOngoing) {
      statusColor = AppTheme.primaryPink;
      statusIcon = Icons.play_circle_outline;
      displayStatus = 'SEDANG BERJALAN';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
      displayStatus = booking.status.toUpperCase();
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
                  displayStatus,
                  style: GoogleFonts.plusJakartaSans(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                if (booking.isPaid) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      "LUNAS",
                      style: GoogleFonts.inter(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.fuchsiaLight,
                        borderRadius: BorderRadius.circular(12),
                        image: (booking.driver?.avatarUrl != null && booking.driver!.avatarUrl!.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(booking.driver!.avatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: (booking.driver?.avatarUrl == null || booking.driver!.avatarUrl!.isEmpty)
                          ? const Icon(
                              Icons.person_pin_rounded,
                              size: 24,
                              color: AppTheme.primaryPink,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.driver?.fullName ?? booking.driver?.vehicleName ?? booking.additionalDetails?['driverName'] ?? 'Partner Temenin',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textHighContrast,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            booking.driver?.vehicleType ?? booking.additionalDetails?['serviceType'] ?? 'Layanan Pendampingan',
                            style: GoogleFonts.inter(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          if (booking.reviewRating != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                                const SizedBox(width: 3),
                                Text(
                                  "${booking.reviewRating!.toStringAsFixed(1)} ★ Ulasan Anda",
                                  style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.fuchsiaLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.2)),
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
          
          // Action buttons (for all active / upcoming / ongoing bookings)
          if (!isDone && !isCancelled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  if (booking.status.toLowerCase() == 'pending' || booking.status.toLowerCase() == 'accepted')
                    Expanded(
                      flex: 2,
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
                  if (booking.status.toLowerCase() == 'pending' || booking.status.toLowerCase() == 'accepted')
                    const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: () => _trackBooking(booking),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      icon: Icon(
                        booking.isVirtual ? Icons.sports_esports_rounded : Icons.play_arrow_rounded,
                        size: 18,
                      ),
                      label: Text(
                        booking.status.toLowerCase() == 'pending'
                            ? 'Pantau Status'
                            : (booking.status.toLowerCase() == 'accepted'
                                ? 'Bayar DP'
                                : (booking.isVirtual ? 'Buka Sesi' : (isOngoing ? 'Lacak Driver' : 'Jadwal Reservasi'))),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
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
    const dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final dayName = dayNames[(date.weekday - 1) % 7];
    final monthName = monthNames[(date.month - 1) % 12];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$dayName, ${date.day} $monthName ${date.year} • $hour:$minute WIB';
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final numVal = num.tryParse(price.toString()) ?? 0;
    return numVal.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
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
    final st = booking.status.toLowerCase();
    final add = booking.additionalDetails;
    final sub = add?['sub_status']?.toString().toLowerCase();
    final isVirtual = booking.isVirtual;

    if (isVirtual) {
      final isOngoing = st == 'ongoing' || st == 'started' || st == 'in_progress' || sub == 'ongoing' || sub == 'started';
      final partnerName = booking.driver?.fullName ?? booking.driver?.vehicleName ?? add?['driverName'] ?? add?['partnerName'] ?? 'Mitra Gamer';
      final sType = booking.driver?.vehicleType ?? add?['serviceType'] ?? (add?['service_type'] ?? 'Pendampingan Virtual');
      final durationMins = booking.callDurationMinutes ?? (booking.duration != null && booking.duration! > 0 ? (booking.duration! > 24 ? booking.duration! : booking.duration! * 60) : 60);
      final isSleep = sType.toString().toLowerCase().contains('sleep');
      final topic = booking.chatTopic ?? add?['game_name'] ?? add?['chat_topic'] ?? 'Mabar & Voice Chat';

      if (isOngoing) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallRoomScreen(
              partnerName: partnerName.toString(),
              serviceType: sType.toString(),
              durationMinutes: durationMins,
              isSleepCall: isSleep,
              topicOrAlarm: topic.toString(),
              bookingId: booking.id,
            ),
          ),
        ).then((_) => _loadBookings(showLoading: false));
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallLobbyScreen(
              bookingDetails: booking.toJson(),
              bookingId: booking.id,
            ),
          ),
        ).then((_) => _loadBookings(showLoading: false));
      }
    } else {
      final isCountdownEnded = add?['countdown_ended'] == true;
      final isWaiting = (st == 'accepted' || st == 'dp_paid' || sub == 'dp_paid' || 
                        (sub == null && st != 'on_the_way' && st != 'arrived' && st != 'started' && st != 'ongoing' && st != 'completed' && st != 'paid'));

      if (st == 'pending') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrackingDriverScreen(
              bookingData: booking.toJson(),
              bookingId: booking.id,
            ),
          ),
        ).then((_) => _loadBookings(showLoading: false));
      } else if (isWaiting && !isCountdownEnded) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientWaitingCountdownScreen(
              bookingId: booking.id,
              bookingData: booking.toJson(),
            ),
          ),
        ).then((_) => _loadBookings(showLoading: false));
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrackingDriverScreen(
              bookingData: booking.toJson(),
              bookingId: booking.id,
            ),
          ),
        ).then((_) => _loadBookings(showLoading: false));
      }
    }
  }
}