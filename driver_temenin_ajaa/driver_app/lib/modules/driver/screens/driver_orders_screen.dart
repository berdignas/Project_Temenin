import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/booking_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/booking_provider.dart';
import 'active_booking_screen.dart';
import 'chat_room_screen.dart';
import 'driver_waiting_countdown_screen.dart';
import 'driver_waiting_dp_screen.dart';

class DriverOrdersScreen extends StatefulWidget {
  final int initialTabIndex;
  const DriverOrdersScreen({super.key, this.initialTabIndex = 0});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleRefresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final booking = Provider.of<BookingProvider>(context, listen: false);
    final driverId = auth.driverProfileData?['id']?.toString() ?? 
                     auth.user?.id ?? 
                     Supabase.instance.client.auth.currentUser?.id ?? 
                     '';
    if (driverId.isNotEmpty) {
      booking.subscribeToBookings(driverId, userId: auth.user?.id);
    }
    await Future.delayed(const Duration(milliseconds: 600));
  }

  String _formatCurrency(num amount) {
    return 'Rp ${amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Waktu tidak ditentukan';
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(local.year, local.month, local.day);
    final diffDays = targetDay.difference(today).inDays;

    final hourStr = local.hour.toString().padLeft(2, '0');
    final minuteStr = local.minute.toString().padLeft(2, '0');
    final timeStr = '$hourStr:$minuteStr WIB';

    final monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final dateStr = '${local.day} ${monthNames[local.month]} ${local.year}';

    if (diffDays == 0) {
      return 'Hari Ini, $timeStr';
    } else if (diffDays == 1) {
      return 'Besok, $timeStr';
    } else if (diffDays == -1) {
      return 'Kemarin, $timeStr';
    } else {
      return '$dateStr • $timeStr';
    }
  }

  String _getServiceLabel(String? serviceType) {
    final type = (serviceType ?? '').toLowerCase();
    if (type.contains('antar') || type.contains('jemput')) {
      return 'Antar Jemput';
    } else if (type.contains('hangout')) {
      return 'Teman Hangout';
    } else if (type.contains('sleep') || type.contains('call')) {
      return 'Sleep / Virtual Call';
    } else if (type.contains('game') || type.contains('gaming')) {
      return 'Gaming Buddy';
    } else if (type.contains('curhat') || type.contains('counseling')) {
      return 'Teman Curhat';
    }
    return 'Pendampingan Pribadi';
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();

    final upcoming = booking.upcomingBookings;
    final ongoing = booking.ongoingTrip;
    final completed = booking.completedBookings;
    final cancelled = booking.cancelledBookings;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF16151A),
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryPink, size: 18),
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Aktivitas & Riwayat Pesanan",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              "${completed.length} Selesai • ${upcoming.length} Booking Terjadwal",
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 11,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF2A2832), width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppTheme.primaryPink,
              indicatorWeight: 3,
              labelColor: AppTheme.primaryPink,
              unselectedLabelColor: Colors.white60,
              labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: [
                Tab(
                  child: Row(
                    children: [
                      const Text("Jadwal Mendatang"),
                      if (upcoming.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _buildBadgeCount(upcoming.length, AppTheme.primaryPink),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Text("Sedang Berjalan"),
                      if (ongoing != null) ...[
                        const SizedBox(width: 6),
                        _buildLiveDot(),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Text("Selesai"),
                      if (completed.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _buildBadgeCount(completed.length, const Color(0xFF10B981)),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Text("Dibatalkan"),
                      if (cancelled.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _buildBadgeCount(cancelled.length, Colors.redAccent),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Tab Jadwal Booking Mendatang
          _buildUpcomingBookingsTab(upcoming),

          // 2. Tab Sedang Berjalan (Live Ongoing Trip)
          _buildOngoingTripTab(ongoing),

          // 3. Tab Riwayat Selesai
          _buildCompletedBookingsTab(completed),

          // 4. Tab Dibatalkan
          _buildCancelledBookingsTab(cancelled),
        ],
      ),
    );
  }

  Widget _buildBadgeCount(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5), width: 0.8),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLiveDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFF10B981),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.6),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: JADWAL BOOKING MENDATANG (SCHEDULED RESERVATIONS)
  // ===========================================================================
  Widget _buildUpcomingBookingsTab(List<BookingModel> bookings) {
    if (bookings.isEmpty) {
      return _buildEmptyState(
        icon: Icons.calendar_today_rounded,
        title: "Belum Ada Jadwal Mendatang",
        message: "Anda belum memiliki jadwal reservasi booking mendatang.\nRadar standby Anda di beranda tetap aktif untuk menerima order langsung.",
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppTheme.primaryPink,
      backgroundColor: const Color(0xFF1F1D2B),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final b = bookings[index];
          return _buildUpcomingBookingCard(b);
        },
      ),
    );
  }

  Widget _buildUpcomingBookingCard(BookingModel b) {
    final clientName = b.client?.fullName ?? 'Pelanggan';
    final service = _getServiceLabel(b.additionalDetails?['serviceType']);
    final isDpPaid = b.status == 'dp_paid' ||
        b.additionalDetails?['dp_paid'] == true ||
        b.additionalDetails?['sub_status'] == 'dp_paid';

    final dpAmount = b.additionalDetails?['dp_amount'] ?? (b.totalPrice * 0.5);
    final remainingPelunasan = b.totalPrice - (dpAmount is num ? dpAmount.toDouble() : 0.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDpPaid ? AppTheme.primaryPink.withOpacity(0.3) : const Color(0xFFF59E0B).withOpacity(0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar: Tanggal & Badge Status DP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDpPaid
                  ? AppTheme.primaryPink.withOpacity(0.08)
                  : const Color(0xFFF59E0B).withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(19),
                topRight: Radius.circular(19),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDpPaid ? AppTheme.primaryPink.withOpacity(0.15) : const Color(0xFFF59E0B).withOpacity(0.15),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: Colors.white70, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      _formatDateTime(b.bookingDate ?? b.createdAt),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDpPaid ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDpPaid ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFF59E0B).withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isDpPaid 
                        ? "🔒 JADWAL TERKUNCI • DP 50% TERBAYAR" 
                        : (b.status == 'pending' ? "⏳ PERLU PERSETUJUAN" : "⏳ BELUM BAYAR DP"),
                    style: GoogleFonts.plusJakartaSans(
                      color: isDpPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Client Profile & Service
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF2A2832),
                      backgroundImage: (b.client?.avatarUrl != null && b.client!.avatarUrl!.isNotEmpty)
                          ? NetworkImage(b.client!.avatarUrl!)
                          : null,
                      child: (b.client?.avatarUrl == null || b.client!.avatarUrl!.isEmpty)
                          ? const Icon(Icons.person, color: Colors.white54, size: 22)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$service • Durasi ${b.duration} Jam",
                            style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(b.totalPrice),
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.primaryPink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          isDpPaid ? "Pelunasan: ${_formatCurrency(remainingPelunasan)}" : "Menunggu DP",
                          style: GoogleFonts.inter(
                            color: isDpPaid ? Colors.white38 : const Color(0xFFF59E0B),
                            fontSize: 10,
                            fontWeight: isDpPaid ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Rute Penjemputan & Tujuan
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131218),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.my_location_rounded, color: AppTheme.primaryPink, size: 15),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              b.pickupLocation.isNotEmpty ? b.pickupLocation : "Lokasi Penjemputan Klien",
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 7),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            height: 10,
                            child: VerticalDivider(color: Colors.white24, width: 1),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Color(0xFF10B981), size: 15),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              b.dropoffLocation.isNotEmpty ? b.dropoffLocation : "Tujuan Pendampingan",
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DriverChatRoomScreen(
                                bookingId: b.id,
                                clientName: clientName,
                                clientImage: b.client?.avatarUrl ?? '',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: const Text("Chat Klien"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF3A3845)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (b.status == 'pending') {
                            final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
                            await bookingProvider.acceptBooking(b.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pesanan disetujui! Menunggu pembayaran DP dari klien.'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          } else if (isDpPaid) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DriverWaitingCountdownScreen(bookingData: b),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DriverWaitingDpScreen(bookingData: b),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          b.status == 'pending'
                              ? Icons.check_circle_outline_rounded
                              : (isDpPaid ? Icons.lock_clock_rounded : Icons.account_balance_wallet_outlined),
                          size: 16,
                        ),
                        label: Text(
                          b.status == 'pending'
                              ? "Setujui Pesanan"
                              : (isDpPaid ? "Jadwal Terkunci" : "Cek Status DP"),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: b.status == 'pending'
                              ? AppTheme.primaryPink
                              : (isDpPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
  }

  // ===========================================================================
  // TAB 2: SEDANG BERJALAN (LIVE ONGOING TRIP)
  // ===========================================================================
  Widget _buildOngoingTripTab(BookingModel? trip) {
    if (trip == null) {
      return _buildEmptyState(
        icon: Icons.two_wheeler_rounded,
        title: "Tidak Ada Perjalanan Berlangsung",
        message: "Anda sedang tidak dalam perjalanan aktif bersama klien.\nStatus Anda saat ini adalah Standby dan siap menerima pesanan langsung.",
      );
    }

    final clientName = trip.client?.fullName ?? 'Pelanggan';
    final service = _getServiceLabel(trip.additionalDetails?['serviceType']);
    final subStatus = trip.additionalDetails?['sub_status']?.toString() ?? trip.status;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppTheme.primaryPink,
      backgroundColor: const Color(0xFF1F1D2B),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1B1A22),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF10B981), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.15),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header Ongoing
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildLiveDot(),
                        const SizedBox(width: 8),
                        Text(
                          "PERJALANAN SEDANG BERLANGSUNG",
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        subStatus.toUpperCase().replaceAll('_', ' '),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFF2A2832),
                          backgroundImage: (trip.client?.avatarUrl != null && trip.client!.avatarUrl!.isNotEmpty)
                              ? NetworkImage(trip.client!.avatarUrl!)
                              : null,
                          child: (trip.client?.avatarUrl == null || trip.client!.avatarUrl!.isEmpty)
                              ? const Icon(Icons.person, color: Colors.white54, size: 26)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clientName,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$service • ${_formatCurrency(trip.totalPrice)}",
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Lokasi
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131218),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.my_location_rounded, color: AppTheme.primaryPink, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  trip.pickupLocation,
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.flag_rounded, color: Color(0xFF10B981), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  trip.dropoffLocation,
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action: Buka Layar Navigasi & Live Control
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DriverActiveBookingScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.navigation_rounded),
                        label: const Text("BUKA LAYAR KONTROL PERJALANAN"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DriverChatRoomScreen(
                                bookingId: trip.id,
                                clientName: clientName,
                                clientImage: trip.client?.avatarUrl ?? '',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_rounded, size: 16),
                        label: const Text("Chat Langsung Klien"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF3A3845)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: RIWAYAT PESANAN SELESAI (COMPLETED TRIPS)
  // ===========================================================================
  Widget _buildCompletedBookingsTab(List<BookingModel> bookings) {
    if (bookings.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: "Belum Ada Riwayat Perjalanan",
        message: "Riwayat pesanan yang telah Anda selesaikan akan muncul di sini beserta rincian pendapatan bagi hasil 90%.",
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppTheme.primaryPink,
      backgroundColor: const Color(0xFF1F1D2B),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final b = bookings[index];
          final clientName = b.client?.fullName ?? 'Pelanggan Temenin';
          final service = _getServiceLabel(b.additionalDetails?['serviceType']);
          final driverIncome = b.totalPrice * 0.9;
          final rating = b.reviewRating;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1920),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF2E2C38)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDateTime(b.bookingDate ?? b.createdAt),
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "SELESAI (LUNAS)",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF10B981),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            service,
                            style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(driverIncome),
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF10B981),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          "Bersih (90%)",
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                if (rating != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      if (b.reviewComment != null && b.reviewComment!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '"${b.reviewComment}"',
                            style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TAB 4: RIWAYAT DIBATALKAN (CANCELLED TRIPS)
  // ===========================================================================
  Widget _buildCancelledBookingsTab(List<BookingModel> bookings) {
    if (bookings.isEmpty) {
      return _buildEmptyState(
        icon: Icons.cancel_outlined,
        title: "Tidak Ada Pesanan Dibatalkan",
        message: "Performa Anda luar biasa! Tidak ada riwayat pesanan yang dibatalkan.",
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppTheme.primaryPink,
      backgroundColor: const Color(0xFF1F1D2B),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final b = bookings[index];
          final clientName = b.client?.fullName ?? 'Pelanggan';
          final cancelReason = b.additionalDetails?['cancellation_reason'] ?? 
                               b.additionalDetails?['cancel_reason'] ?? 
                               'Dibatalkan';
          final isClientCancel = b.additionalDetails?['cancelled_by'] == 'client' ||
                                 b.additionalDetails?['payout_status'] == 'forfeited';

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1920),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDateTime(b.bookingDate ?? b.createdAt),
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isClientCancel ? "BATAL OLEH KLIEN" : "DIBATALKAN",
                        style: GoogleFonts.inter(
                          color: Colors.redAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  clientName,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Alasan: $cancelReason",
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                ),
                if (isClientCancel) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          "Kompensasi Pembatalan 50% telah dikreditkan ke saldo Anda",
                          style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper: Empty State UI
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF22202C),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2F2C3D)),
              ),
              child: Icon(icon, size: 40, color: Colors.white38),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
