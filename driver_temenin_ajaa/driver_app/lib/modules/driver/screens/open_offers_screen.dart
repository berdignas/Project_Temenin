import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/driver_notification_model.dart';
import '../../../providers/booking_provider.dart';
import 'driver_negotiation_screen.dart';

class OpenOffersScreen extends StatefulWidget {
  const OpenOffersScreen({super.key});

  @override
  State<OpenOffersScreen> createState() => _OpenOffersScreenState();
}

class _OpenOffersScreenState extends State<OpenOffersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatPrice(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m yang lalu';
    if (diff.inHours < 24) return '${diff.inHours}j yang lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = context.watch<BookingProvider>();
    final openOffers = bookingProvider.pendingOffers;
    final notifications = bookingProvider.notifications;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textHighContrast, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Pusat Notifikasi & Tawaran",
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        centerTitle: false,
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                bookingProvider.markAllNotificationsAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Semua notifikasi ditandai telah dibaca"),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: Text(
                "Baca Semua",
                style: GoogleFonts.inter(
                  color: AppTheme.primaryPink,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryPink,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryPink,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              text: "Notifikasi (${notifications.length})",
              icon: const Icon(Icons.notifications_active_rounded, size: 18),
            ),
            Tab(
              text: "Pesanan Masuk (${openOffers.length})",
              icon: const Icon(Icons.local_offer_rounded, size: 18),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: NOTIFICATIONS LIST
          _buildNotificationsTab(bookingProvider, notifications),

          // TAB 2: ACTIVE OPEN OFFERS
          _buildOffersTab(openOffers),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab(BookingProvider provider, List<DriverNotificationModel> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.cardDeep,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_off_rounded, color: AppTheme.textMuted, size: 54),
            ),
            const SizedBox(height: 16),
            Text(
              "Belum Ada Notifikasi",
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              "Pemberitahuan pesanan & sistem akan tersimpan di sini.",
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notif = notifications[index];
        return GestureDetector(
          onTap: () {
            provider.markNotificationAsRead(notif.id);
            if (notif.booking != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverNegotiationScreen(bookingData: notif.booking!),
                ),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: notif.isRead ? AppTheme.surface : AppTheme.fuchsiaLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: notif.isRead ? AppTheme.border : AppTheme.primaryPink.withOpacity(0.4),
                width: notif.isRead ? 1 : 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPink.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt_rounded, color: AppTheme.primaryPink, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textHighContrast,
                                fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(notif.timestamp),
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.message,
                        style: GoogleFonts.inter(
                          color: AppTheme.textMediumContrast,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      if (notif.booking != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              "Ketuk untuk lihat & terima tawaran",
                              style: GoogleFonts.inter(
                                color: AppTheme.primaryPink,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryPink, size: 10),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOffersTab(List<BookingModel> openOffers) {
    if (openOffers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.cardDeep,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_rounded, color: AppTheme.textMuted, size: 54),
            ),
            const SizedBox(height: 16),
            Text(
              "Belum ada tawaran terbuka saat ini.",
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              "Permintaan pendampingan kustom akan muncul di sini.",
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: openOffers.length,
      itemBuilder: (context, index) {
        final offer = openOffers[index];
        return _buildOfferCard(offer);
      },
    );
  }

  Widget _buildOfferCard(BookingModel offer) {
    final clientName = offer.client?.fullName ?? 'Client';
    final desc = offer.additionalDetails?['description'] ?? 'Deskripsi tidak tersedia';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: offer.client?.avatarUrl != null ? NetworkImage(offer.client!.avatarUrl!) : null,
                backgroundColor: AppTheme.cardDeep,
                child: offer.client?.avatarUrl == null ? const Icon(Icons.person, color: AppTheme.textMuted) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, color: AppTheme.textMuted, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "Membutuhkan ${offer.duration} Jam",
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "CUSTOM",
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              )
            ],
          ),
          const SizedBox(height: 14),
          Text(
            desc,
            style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 12, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(color: AppTheme.border, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Penawaran Harga:", style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
                  Text(
                    "Rp ${_formatPrice(offer.totalPrice)}",
                    style: GoogleFonts.plusJakartaSans(color: AppTheme.primaryPink, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DriverNegotiationScreen(bookingData: offer),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: Text("Beli / Tawar", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          )
        ],
      ),
    );
  }
}
