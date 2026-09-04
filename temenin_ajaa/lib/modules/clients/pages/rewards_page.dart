import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/services/reward_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> with SingleTickerProviderStateMixin {
  final RewardService _rewardService = RewardService();
  late TabController _tabController;
  
  List<Reward> _rewards = [];
  List<Voucher> _vouchers = [];
  List<Transaction> _transactions = [];
  
  bool _isLoading = true;
  String? _errorMessage;
  
  int _totalPoints = 0;
  int _pointsToNextLevel = 500;
  String _currentTier = 'Bronze';
  
  final Map<String, dynamic> _tierInfo = {
    'Bronze': {'minPoints': 0, 'color': const Color(0xFFCD7F32), 'benefits': ['Layanan standar', 'Poin reguler']},
    'Silver': {'minPoints': 1000, 'color': const Color(0xFF94A3B8), 'benefits': ['Prioritas CS', 'Diskon 5%', 'Bebas biaya cancel']},
    'Gold': {'minPoints': 5000, 'color': const Color(0xFFEAB308), 'benefits': ['VIP Support', 'Diskon 10%', 'Bebas biaya cancel', 'Partner Prioritas']},
    'Platinum': {'minPoints': 15000, 'color': const Color(0xFF0284C7), 'benefits': ['24/7 VIP Concierge', 'Diskon 15%', 'Bebas biaya cancel', 'Voucher Spesial']},
    'Diamond': {'minPoints': 30000, 'color': const Color(0xFF9333EA), 'benefits': ['Personal Assistant', 'Diskon 20%', 'Bebas biaya cancel', 'Kado Ulang Tahun']},
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user!.id;
      
      final rewardsResult = await _rewardService.getRewards(userId);
      final vouchersResult = await _rewardService.getVouchers(userId);
      final pointsResult = await _rewardService.getUserPoints(userId);
      
      if (rewardsResult['success'] == true) {
        _rewards = rewardsResult['rewards'];
        _transactions = rewardsResult['transactions'] ?? [];
      }
      
      if (vouchersResult['success'] == true) {
        _vouchers = vouchersResult['vouchers'];
      }
      
      if (pointsResult['success'] == true) {
        _totalPoints = pointsResult['points'];
        _updateTier();
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _updateTier() {
    if (_totalPoints >= 30000) {
      _currentTier = 'Diamond';
      _pointsToNextLevel = 0;
    } else if (_totalPoints >= 15000) {
      _currentTier = 'Platinum';
      _pointsToNextLevel = 30000 - _totalPoints;
    } else if (_totalPoints >= 5000) {
      _currentTier = 'Gold';
      _pointsToNextLevel = 15000 - _totalPoints;
    } else if (_totalPoints >= 1000) {
      _currentTier = 'Silver';
      _pointsToNextLevel = 5000 - _totalPoints;
    } else {
      _currentTier = 'Bronze';
      _pointsToNextLevel = 1000 - _totalPoints;
    }
  }

  Future<void> _redeemReward(Reward reward) async {
    final canRedeem = _totalPoints >= reward.pointsCost;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Tukar Reward',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.fuchsiaLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(reward.icon, color: AppTheme.primaryPink, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward.name,
                        style: GoogleFonts.inter(
                          color: AppTheme.textHighContrast,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${reward.pointsCost} Poin',
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryPink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              reward.description,
              style: GoogleFonts.inter(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: canRedeem ? AppTheme.success.withOpacity(0.1) : AppTheme.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    canRedeem ? Icons.check_circle : Icons.error_outline,
                    color: canRedeem ? AppTheme.success : AppTheme.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      canRedeem
                          ? 'Poin Anda cukup untuk ditukarkan.'
                          : 'Poin Anda belum mencukupi (Butuh ${reward.pointsCost - _totalPoints} poin lagi).',
                      style: GoogleFonts.inter(
                        color: canRedeem ? AppTheme.success : AppTheme.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: canRedeem
                ? () async {
                    Navigator.pop(context);
                    final result = await _rewardService.redeemReward(
                      reward.id,
                      reward.pointsCost,
                    );
                    
                    if (context.mounted) {
                      if (result['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reward berhasil ditukarkan!'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                        _loadData();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Gagal menukarkan reward'),
                            backgroundColor: AppTheme.danger,
                          ),
                        );
                      }
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tukar Sekarang'),
          ),
        ],
      ),
    );
  }

  Future<void> _claimVoucher(Voucher voucher) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Klaim Voucher Promo',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.heroGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    voucher.code,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    voucher.discount == voucher.maxDiscount
                        ? 'Diskon ${voucher.discount}%'
                        : 'Diskon hingga ${voucher.discount}%',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Min. transaksi Rp ${_formatPrice(voucher.minSpend)}',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              voucher.description,
              style: GoogleFonts.inter(color: AppTheme.textHighContrast),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Berlaku hingga: ${_formatDate(voucher.expiryDate)}',
              style: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryPink),
                ),
              );
              
              final result = await _rewardService.claimVoucher(voucher.id);
              
              if (context.mounted) {
                Navigator.pop(context);
                
                if (result['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voucher berhasil diklaim! Gunakan saat checkout.'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Gagal mengklaim voucher'),
                      backgroundColor: AppTheme.danger,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Klaim Sekarang'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatPrice(int? price) {
    if (price == null) return '0';
    return price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Rewards & Voucher',
          style: GoogleFonts.inter(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryPink,
          labelColor: AppTheme.primaryPink,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(text: 'Katalog Reward'),
            Tab(text: 'Voucher Promo'),
            Tab(text: 'Riwayat Poin'),
          ],
        ),
      ),
      body: _isLoading
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
                        color: AppTheme.textMuted.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPink,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRewardsTab(),
                    _buildVouchersTab(),
                    _buildHistoryTab(),
                  ],
                ),
    );
  }

  Widget _buildRewardsTab() {
    return Column(
      children: [
        // Points Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.heroGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPink.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Poin Anda',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_totalPoints',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.stars_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tier Member',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _currentTier,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_pointsToNextLevel > 0)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Tier Berikutnya: ${_getNextTier()}',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Kurang $_pointsToNextLevel poin',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: _getProgressValue(),
                backgroundColor: Colors.white.withOpacity(0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                borderRadius: BorderRadius.circular(10),
                minHeight: 6,
              ),
            ],
          ),
        ),
        
        // Rewards List
        Expanded(
          child: _rewards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.card_giftcard,
                        size: 64,
                        color: AppTheme.textMuted.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada reward yang tersedia',
                        style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _rewards.length,
                  itemBuilder: (context, index) {
                    final reward = _rewards[index];
                    return _buildRewardCard(reward);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRewardCard(Reward reward) {
    final canRedeem = _totalPoints >= reward.pointsCost;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.fuchsiaLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                reward.icon,
                color: AppTheme.primaryPink,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.name,
                    style: GoogleFonts.inter(
                      color: AppTheme.textHighContrast,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reward.description,
                    style: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: AppTheme.primaryPink),
                      const SizedBox(width: 4),
                      Text(
                        '${reward.pointsCost} poin',
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryPink,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (reward.stock > 0) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.inventory_2_outlined, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Sisa ${reward.stock}',
                          style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: canRedeem && reward.stock != 0 ? () => _redeemReward(reward) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canRedeem && reward.stock != 0
                    ? AppTheme.primaryPink
                    : AppTheme.border,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(canRedeem ? 'Tukar' : 'Terkunci', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVouchersTab() {
    return _vouchers.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  size: 64,
                  color: AppTheme.textMuted.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum ada voucher promo',
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _vouchers.length,
            itemBuilder: (context, index) {
              final voucher = _vouchers[index];
              return _buildVoucherCard(voucher);
            },
          );
  }

  Widget _buildVoucherCard(Voucher voucher) {
    final isExpired = voucher.expiryDate?.isBefore(DateTime.now()) ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.fuchsiaLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_offer,
                    color: AppTheme.primaryPink,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.discount == voucher.maxDiscount
                            ? 'Diskon ${voucher.discount}%'
                            : 'Diskon hingga ${voucher.discount}%',
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryPink,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        voucher.description,
                        style: GoogleFonts.inter(
                          color: AppTheme.textHighContrast,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.attach_money, size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Min. Rp ${_formatPrice(voucher.minSpend)}',
                            style: GoogleFonts.inter(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.calendar_today, size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            's/d ${_formatDate(voucher.expiryDate)}',
                            style: GoogleFonts.inter(
                              color: isExpired ? AppTheme.danger : AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isExpired && !voucher.isClaimed)
                  ElevatedButton(
                    onPressed: () => _claimVoucher(voucher),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Klaim'),
                  ),
                if (voucher.isClaimed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Terklaim',
                      style: GoogleFonts.inter(
                        color: AppTheme.success,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Kadaluarsa',
                      style: GoogleFonts.inter(
                        color: AppTheme.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (voucher.isClaimed)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppTheme.success,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: Text(
                  'TERKLAIM',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return _transactions.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: AppTheme.textMuted.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum ada riwayat transaksi poin',
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _transactions.length,
            itemBuilder: (context, index) {
              final transaction = _transactions[index];
              return _buildTransactionCard(transaction);
            },
          );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: transaction.type == 'earn'
                  ? AppTheme.success.withOpacity(0.12)
                  : AppTheme.primaryPink.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              transaction.type == 'earn' ? Icons.add_circle : Icons.card_giftcard,
              color: transaction.type == 'earn' ? AppTheme.success : AppTheme.primaryPink,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: GoogleFonts.inter(
                    color: AppTheme.textHighContrast,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(transaction.createdAt),
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            transaction.type == 'earn' ? '+${transaction.points}' : '-${transaction.points}',
            style: GoogleFonts.inter(
              color: transaction.type == 'earn' ? AppTheme.success : AppTheme.primaryPink,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  double _getProgressValue() {
    if (_currentTier == 'Diamond') return 1.0;
    
    final tiers = ['Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond'];
    final currentIndex = tiers.indexOf(_currentTier);
    final nextTierPoints = _getTierMinPoints(tiers[currentIndex + 1]);
    final prevTierPoints = _getTierMinPoints(_currentTier);
    
    final pointsInCurrentTier = _totalPoints - prevTierPoints;
    final pointsNeeded = nextTierPoints - prevTierPoints;
    
    if (pointsNeeded <= 0) return 1.0;
    return (pointsInCurrentTier / pointsNeeded).clamp(0.0, 1.0);
  }

  int _getTierMinPoints(String tier) {
    switch (tier) {
      case 'Bronze': return 0;
      case 'Silver': return 1000;
      case 'Gold': return 5000;
      case 'Platinum': return 15000;
      case 'Diamond': return 30000;
      default: return 0;
    }
  }

  String _getNextTier() {
    final tiers = ['Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond'];
    final currentIndex = tiers.indexOf(_currentTier);
    if (currentIndex < tiers.length - 1) {
      return tiers[currentIndex + 1];
    }
    return 'Maksimum';
  }
}

// Models
class Reward {
  final String id;
  final String name;
  final String description;
  final int pointsCost;
  final IconData icon;
  final int stock;

  Reward({
    required this.id,
    required this.name,
    required this.description,
    required this.pointsCost,
    required this.icon,
    required this.stock,
  });
}

class Voucher {
  final String id;
  final String code;
  final String description;
  final int discount;
  final int maxDiscount;
  final int minSpend;
  final DateTime? expiryDate;
  final bool isClaimed;

  Voucher({
    required this.id,
    required this.code,
    required this.description,
    required this.discount,
    required this.maxDiscount,
    required this.minSpend,
    this.expiryDate,
    this.isClaimed = false,
  });
}

class Transaction {
  final String id;
  final String description;
  final int points;
  final String type; // 'earn' or 'redeem'
  final DateTime? createdAt;

  Transaction({
    required this.id,
    required this.description,
    required this.points,
    required this.type,
    this.createdAt,
  });
}