import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/booking_provider.dart';
import '../../../providers/auth_provider.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  String _selectedPeriod = 'daily'; // 'daily', 'weekly', 'monthly'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    Provider.of<BookingProvider>(context, listen: false).loadEarnings(_selectedPeriod);
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = context.watch<BookingProvider>();
    final authProvider = context.watch<AuthProvider>();
    final double currentBalance = authProvider.user?.balance ?? 0.0;

    String formatCurrency(double amount) {
      return "Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
    }

    return RefreshIndicator(
      color: AppTheme.primaryPink,
      backgroundColor: AppTheme.surface,
      onRefresh: () async {
        await authProvider.refreshProfile();
        await bookingProvider.loadEarnings(_selectedPeriod);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // ======================================================
          // 1. TOP HERO SECTION (Vibrant Pink Fuchsia Curved Container)
          // ======================================================
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppTheme.heroGradient,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(36),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x40FF2E93),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                )
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Row: Activity 🕒
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Aktivitas Driver",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF171420),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.access_time_rounded, color: Colors.white, size: 14),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF171420),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            "${bookingProvider.totalRides} Trips",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Pantau rekapitulasi performa & ringkasan komisi",
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Period Filter Chips (Dark Contrast Pills)
                    Row(
                      children: [
                        _buildPeriodPill('daily', 'Hari Ini'),
                        const SizedBox(width: 8),
                        _buildPeriodPill('weekly', 'Minggu Ini'),
                        const SizedBox(width: 8),
                        _buildPeriodPill('monthly', 'Bulan Ini'),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // FEATURED TRIP / EARNINGS CARD (Screen 2 Map & Performance Style)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface, // Clean White Card
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mini Map / Route Snapshot Header
                          Container(
                            height: 80,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppTheme.cardDeep,
                              borderRadius: BorderRadius.circular(16),
                              image: const DecorationImage(
                                image: NetworkImage("https://images.unsplash.com/photo-1524661135-423995f22d0b?w=500"),
                                fit: BoxFit.cover,
                                opacity: 0.35,
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface.withOpacity(0.92),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "TERAKHIR DISELESAIKAN",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.primaryPink,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "LUNAS",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.success,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Total Clean Earnings Summary
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "TOTAL PENDAPATAN BERSIH",
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    formatCurrency(bookingProvider.totalEarnings),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.textHighContrast,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPink.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  "${bookingProvider.totalRides} Order",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.primaryPink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppTheme.border),
                          const SizedBox(height: 14),

                          // Withdrawable Active Wallet Balance & Withdraw Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "SALDO DOMPET AKTIF",
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    formatCurrency(currentBalance),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF10B981), // Emerald Green
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showWithdrawalModal(context, currentBalance),
                                icon: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Colors.white),
                                label: Text(
                                  "Tarik Saldo",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryPink,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppTheme.border),
                          const SizedBox(height: 14),

                          // Dana Tertahan (Escrow / DP Pending) Section
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bookingProvider.pendingEscrowBalance > 0
                                  ? const Color(0xFFFFFBEB) // Soft Amber background
                                  : AppTheme.cardDeep,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: bookingProvider.pendingEscrowBalance > 0
                                    ? const Color(0xFFFDE68A)
                                    : AppTheme.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: bookingProvider.pendingEscrowBalance > 0
                                        ? const Color(0xFFF59E0B).withOpacity(0.15)
                                        : Colors.grey.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.shield_outlined,
                                    color: bookingProvider.pendingEscrowBalance > 0
                                        ? const Color(0xFFD97706)
                                        : AppTheme.textMuted,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "DANA TERTAHAN (ESCROW / DP)",
                                            style: GoogleFonts.inter(
                                              color: bookingProvider.pendingEscrowBalance > 0
                                                  ? const Color(0xFF92400E)
                                                  : AppTheme.textMuted,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          Text(
                                            formatCurrency(bookingProvider.pendingEscrowBalance),
                                            style: GoogleFonts.plusJakartaSans(
                                              color: bookingProvider.pendingEscrowBalance > 0
                                                  ? const Color(0xFFD97706)
                                                  : AppTheme.textMuted,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        bookingProvider.pendingEscrowBalance > 0
                                            ? "Uang DP klien tersimpan aman di rekening penampung. Otomatis cair ke Saldo Dompet saat perjalanan selesai."
                                            : "Tidak ada dana yang sedang tertahan di sistem escrow.",
                                        style: GoogleFonts.inter(
                                          color: bookingProvider.pendingEscrowBalance > 0
                                              ? const Color(0xFFB45309)
                                              : AppTheme.textMuted,
                                          fontSize: 10,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ======================================================
          // 2. BOTTOM SECTION: PAST TRIPS LIST (Screen 2 Reference)
          // ======================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Riwayat Perjalanan Selesai",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textHighContrast,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      "Filter ▾",
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Trips List
                if (bookingProvider.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPink),
                      ),
                    ),
                  )
                else if (bookingProvider.earningsBookings.isEmpty)
                  _buildEmptyState()
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: bookingProvider.earningsBookings.length,
                    itemBuilder: (context, index) {
                      final booking = bookingProvider.earningsBookings[index];
                      final price = (booking['total_price'] ?? 0.0).toDouble();
                      String dateStr = 'Baru saja';
                      if (booking['created_at'] != null) {
                        try {
                          final dt = DateTime.parse(booking['created_at']).toLocal();
                          const dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
                          const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
                          final dayName = dayNames[(dt.weekday - 1) % 7];
                          final monthName = monthNames[(dt.month - 1) % 12];
                          final hour = dt.hour.toString().padLeft(2, '0');
                          final minute = dt.minute.toString().padLeft(2, '0');
                          dateStr = '$dayName, ${dt.day} $monthName • $hour:$minute WIB';
                        } catch (_) {
                          dateStr = booking['created_at'].toString().split('T')[0];
                        }
                      }

                      return _buildTripHistoryCard(
                        icon: Icons.directions_car_rounded,
                        title: booking['pickup_location'] ?? "Layanan Temenin",
                        subtitle: "Selesai • $dateStr",
                        price: formatCurrency(price),
                      );
                    },
                  ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  // ============================================================
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPink.withOpacity(0.18),
                  const Color(0xFF8B5CF6).withOpacity(0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3)),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryPink, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            "Belum Ada Riwayat Pendapatan",
            style: GoogleFonts.plusJakartaSans(color: AppTheme.textHighContrast, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            "Setiap pesanan yang diselesaikan akan otomatis tercatat bersama detail komisi dan tanggal transaksi.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TRIP HISTORY CARD (Screen 2 Item Style)
  // ============================================================
  Widget _buildTripHistoryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String price,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cardDeep,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.textHighContrast, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textHighContrast,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.primaryPink,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.cardDeep,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMuted,
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PERIOD PILL CHIP (Screen 2 Tab Filter Style)
  // ============================================================
  Widget _buildPeriodPill(String period, String label) {
    final bool isSelected = _selectedPeriod == period;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? AppTheme.primaryPink : Colors.white,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WITHDRAWAL MODAL BOTTOM SHEET
  // ============================================================
  void _showWithdrawalModal(BuildContext context, double currentBalance) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final amountController = TextEditingController();
    final accountNumberController = TextEditingController();
    final accountNameController = TextEditingController(text: authProvider.user?.fullName ?? '');
    String selectedBank = 'Bank BCA';

    final bankOptions = [
      'Bank BCA',
      'Bank Mandiri',
      'Bank BRI',
      'Bank BNI',
      'DANA',
      'GoPay',
      'OVO',
      'ShopeePay'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double enteredAmount = double.tryParse(amountController.text.replaceAll(RegExp(r'\D'), '')) ?? 0.0;
            final bool isExceeding = enteredAmount > currentBalance;
            final bool isBelowMin = enteredAmount > 0 && enteredAmount < 10000;
            final bool canSubmit = enteredAmount >= 10000 && !isExceeding && accountNumberController.text.trim().isNotEmpty && accountNameController.text.trim().isNotEmpty;

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Tarik Saldo Dompet",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textHighContrast,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "Maks: Rp ${currentBalance.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Nominal Field
                    Text(
                      "Nominal Penarikan (Rp)",
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textHighContrast),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: "Contoh: 50000",
                        prefixText: "Rp ",
                        filled: true,
                        fillColor: AppTheme.cardDeep,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    if (isExceeding) ...[
                      const SizedBox(height: 4),
                      Text(
                        "⚠️ Nominal tidak boleh melebihi saldo aktif Anda!",
                        style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ] else if (isBelowMin) ...[
                      const SizedBox(height: 4),
                      Text(
                        "⚠️ Minimal penarikan adalah Rp 10.000",
                        style: GoogleFonts.inter(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 10),

                    // Quick Nominal Chips
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildQuickChip(50000, "50rb", amountController, setModalState),
                        _buildQuickChip(100000, "100rb", amountController, setModalState),
                        _buildQuickChip(250000, "250rb", amountController, setModalState),
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              amountController.text = currentBalance.toInt().toString();
                            });
                          },
                          child: Chip(
                            label: Text("Tarik Semua", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPink)),
                            backgroundColor: AppTheme.primaryPink.withOpacity(0.12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: BorderSide.none,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Bank Selection
                    Text(
                      "Bank / E-Wallet Tujuan",
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textHighContrast),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDeep,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedBank,
                          isExpanded: true,
                          items: bankOptions.map((b) => DropdownMenuItem(value: b, child: Text(b, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textHighContrast)))).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedBank = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Account Number
                    Text(
                      "Nomor Rekening / No. E-Wallet",
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textHighContrast),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: accountNumberController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: "Masukkan no. rekening penerima",
                        filled: true,
                        fillColor: AppTheme.cardDeep,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Account Name
                    Text(
                      "Nama Pemilik Rekening",
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textHighContrast),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: accountNameController,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: "Sesuai nama di buku tabungan / e-wallet",
                        filled: true,
                        fillColor: AppTheme.cardDeep,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: canSubmit
                            ? () async {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => const Center(
                                    child: CircularProgressIndicator(color: AppTheme.primaryPink),
                                  ),
                                );

                                final res = await authProvider.requestWithdrawal(
                                  amount: enteredAmount,
                                  bankName: selectedBank,
                                  accountNumber: accountNumberController.text.trim(),
                                  accountName: accountNameController.text.trim(),
                                );

                                if (context.mounted) {
                                  Navigator.pop(context); // close loading
                                }

                                if (res['success'] == true) {
                                  if (context.mounted) {
                                    Navigator.pop(context); // close modal
                                    showDialog(
                                      context: context,
                                      builder: (dCtx) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        title: Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                                            const SizedBox(width: 8),
                                            Text("Penarikan Diajukan", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
                                          ],
                                        ),
                                        content: Text(
                                          "Permintaan penarikan sebesar Rp ${enteredAmount.toStringAsFixed(0)} berhasil dikirim ke Admin. Saldo dompet Anda telah dipotong dan akan segera ditransfer setelah diverifikasi.",
                                          style: GoogleFonts.inter(fontSize: 13, height: 1.4),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dCtx),
                                            child: Text("Mengerti", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primaryPink)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['message'] ?? 'Gagal mengajukan penarikan dana'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPink,
                          disabledBackgroundColor: AppTheme.border,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          "Ajukan Penarikan Dana",
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickChip(int amount, String label, TextEditingController controller, StateSetter setModalState) {
    return GestureDetector(
      onTap: () {
        setModalState(() {
          controller.text = amount.toString();
        });
      },
      child: Chip(
        label: Text("Rp $label", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.cardDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
    );
  }
}

