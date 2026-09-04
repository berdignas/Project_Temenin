import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/services/payment_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  final PaymentService _paymentService = PaymentService();
  List<PaymentMethod> _paymentMethods = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedMethodIndex = 0;

  // Daftar metode pembayaran yang tersedia
  final List<Map<String, dynamic>> _availableMethods = [
    {
      'name': 'Transfer Bank',
      'icon': Icons.account_balance,
      'color': const Color(0xFF10B981),
      'types': ['BCA', 'Mandiri', 'BNI', 'BRI']
    },
    {
      'name': 'E-Wallet',
      'icon': Icons.account_balance_wallet,
      'color': AppTheme.primaryPink,
      'types': ['GoPay', 'OVO', 'Dana', 'LinkAja', 'ShopeePay']
    },
    {
      'name': 'Kartu Debit / Kredit',
      'icon': Icons.credit_card,
      'color': const Color(0xFF2563EB),
      'types': ['Visa', 'Mastercard', 'JCB', 'GPN']
    },
    {
      'name': 'QRIS',
      'icon': Icons.qr_code_scanner,
      'color': const Color(0xFF8B5CF6),
      'types': ['QRIS Semua Bank/E-Wallet']
    },
    {
      'name': 'Tunai (Cash)',
      'icon': Icons.money,
      'color': const Color(0xFFF59E0B),
      'types': ['Bayar Tunai ke Driver']
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await _paymentService.getPaymentMethods(authProvider.user!.id);
      
      if (result['success'] == true) {
        setState(() {
          _paymentMethods = result['methods'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Gagal memuat metode pembayaran';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addPaymentMethod(Map<String, dynamic> method, String type) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryPink),
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await _paymentService.addPaymentMethod(
        userId: authProvider.user!.id,
        methodType: method['name'],
        provider: type,
      );

      Navigator.pop(context); // Close loading

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metode pembayaran berhasil ditambahkan!'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadPaymentMethods();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal menambahkan metode pembayaran'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _removePaymentMethod(String methodId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Metode Pembayaran',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus metode pembayaran ini?',
          style: GoogleFonts.inter(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hapus', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryPink),
      ),
    );

    try {
      final result = await _paymentService.removePaymentMethod(methodId);

      Navigator.pop(context); // Close loading

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metode pembayaran berhasil dihapus'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadPaymentMethods();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal menghapus metode pembayaran'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  void _showAddPaymentMethodDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Tambah Metode Pembayaran',
                    style: GoogleFonts.inter(
                      color: AppTheme.textHighContrast,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._availableMethods.asMap().entries.map((entry) {
                    final index = entry.key;
                    final method = entry.value;
                    final isSelected = _selectedMethodIndex == index;
                    
                    return Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMethodIndex = index;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? AppTheme.fuchsiaLight
                                  : AppTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected 
                                    ? AppTheme.primaryPink
                                    : AppTheme.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (method['color'] as Color).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    method['icon'],
                                    color: method['color'],
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    method['name'],
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textHighContrast,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppTheme.primaryPink,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                  if (_selectedMethodIndex >= 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Tipe ${_availableMethods[_selectedMethodIndex]['name']}',
                            style: GoogleFonts.inter(
                              color: AppTheme.textHighContrast,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: (_availableMethods[_selectedMethodIndex]['types'] as List<String>).map((type) {
                              return ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _addPaymentMethod(_availableMethods[_selectedMethodIndex], type);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryPink,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(type),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Metode Pembayaran',
          style: GoogleFonts.inter(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _showAddPaymentMethodDialog,
            icon: const Icon(Icons.add, color: AppTheme.primaryPink),
            label: Text(
              'Tambah',
              style: GoogleFonts.inter(
                color: AppTheme.primaryPink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
                        onPressed: _loadPaymentMethods,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPink,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _paymentMethods.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.credit_card_off,
                            size: 64,
                            color: AppTheme.textMuted.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada metode pembayaran tersimpan',
                            style: GoogleFonts.inter(
                              color: AppTheme.textHighContrast,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _showAddPaymentMethodDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPink,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Tambah Metode Pembayaran'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _paymentMethods.length,
                      itemBuilder: (context, index) {
                        final method = _paymentMethods[index];
                        return _buildPaymentMethodCard(method);
                      },
                    ),
    );
  }

  Widget _buildPaymentMethodCard(PaymentMethod method) {
    final methodInfo = _availableMethods.firstWhere(
      (m) => m['name'] == method.methodType,
      orElse: () => _availableMethods[0],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                    color: (methodInfo['color'] as Color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    methodInfo['icon'],
                    color: methodInfo['color'],
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.methodType,
                        style: GoogleFonts.inter(
                          color: AppTheme.textHighContrast,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        method.provider,
                        style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      if (method.isDefault)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPink.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'UTAMA',
                            style: GoogleFonts.inter(
                              color: AppTheme.primaryPink,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _removePaymentMethod(method.id),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ],
            ),
          ),
          if (method.isDefault)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryPink,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: Text(
                  'Utama',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Model untuk Payment Method
class PaymentMethod {
  final String id;
  final String userId;
  final String methodType;
  final String provider;
  final String? lastFour;
  final bool isDefault;
  final DateTime? createdAt;

  PaymentMethod({
    required this.id,
    required this.userId,
    required this.methodType,
    required this.provider,
    this.lastFour,
    this.isDefault = false,
    this.createdAt,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      methodType: json['method_type'] ?? '',
      provider: json['provider'] ?? '',
      lastFour: json['last_four'],
      isDefault: json['is_default'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'method_type': methodType,
      'provider': provider,
      'last_four': lastFour,
      'is_default': isDefault,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}