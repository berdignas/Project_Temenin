import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _reportController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  
  String _selectedProblemType = 'Booking Issue';
  final List<String> _problemTypes = [
    'Booking Issue',
    'Payment Problem',
    'Driver Issue',
    'Account Problem',
    'App Bug',
    'Other',
  ];

  final List<Map<String, dynamic>> _faqList = [
    {
      'question': 'Bagaimana cara memesan perjalanan?',
      'answer': 'Buka aplikasi, masukkan lokasi penjemputan dan tujuan Anda, pilih tipe layanan yang diinginkan, dan tekan "Pesan Sekarang". Anda akan segera dipasangkan dengan partner driver terdekat.',
      'category': 'Booking',
    },
    {
      'question': 'Bagaimana cara membatalkan pesanan?',
      'answer': 'Buka pesanan aktif Anda, tekan tombol "Batalkan". Pembatalan gratis berlaku dalam 5 menit pertama setelah pemesanan.',
      'category': 'Booking',
    },
    {
      'question': 'Bagaimana cara menambah metode pembayaran?',
      'answer': 'Buka menu Profil → Metode Pembayaran → Tambah Metode Pembayaran. Anda dapat menambahkan transfer bank, e-wallet (GoPay, OVO, Dana), kartu debit/kredit, atau pembayaran tunai.',
      'category': 'Payment',
    },
    {
      'question': 'Bagaimana cara top up saldo?',
      'answer': 'Buka Profil → Top Up / Saldo, pilih nominal yang diinginkan, pilih metode pembayaran, dan ikuti instruksi pembayaran.',
      'category': 'Payment',
    },
    {
      'question': 'Bagaimana cara melacak posisi driver?',
      'answer': 'Setelah pesanan dikonfirmasi, Anda dapat melihat posisi driver secara real-time pada peta aplikasi dan dapat menghubungi driver via chat.',
      'category': 'Ride',
    },
    {
      'question': 'Apa yang harus dilakukan jika driver tidak kunjung datang?',
      'answer': 'Hubungi driver melalui in-app chat atau telepon. Jika tidak merespons, Anda dapat membatalkan pesanan dan melaporkan melalui pusat bantuan.',
      'category': 'Driver',
    },
    {
      'question': 'Bagaimana cara mengubah profil?',
      'answer': 'Buka Profil → Edit Profil. Anda dapat mengubah nama, nomor telepon, dan foto profil.',
      'category': 'Account',
    },
    {
      'question': 'Bagaimana sistem poin Temenin Ajaa?',
      'answer': 'Anda mendapatkan poin reward setiap menyelesaikan perjalanan. Poin dapat ditukarkan dengan voucher diskon di menu Rewards.',
      'category': 'Rewards',
    },
    {
      'question': 'Bagaimana kebijakan pembatalan?',
      'answer': 'Pembatalan dalam waktu 5 menit pertama adalah gratis. Setelahnya dapat dikenakan biaya kompensasi partner sebesar Rp 5.000.',
      'category': 'Policy',
    },
    {
      'question': 'Bagaimana menghubungi customer support?',
      'answer': 'Anda dapat menghubungi kami via WhatsApp di +62 812-3456-7890, email ke support@temeninajaa.com, atau mengisi formulir laporan.',
      'category': 'Support',
    },
  ];

  final List<Map<String, String>> _guides = [
    {
      'title': 'Panduan Memesan Layanan',
      'icon': '🚗',
      'steps': '1. Buka aplikasi Temenin Ajaa\n2. Tentukan lokasi penjemputan & tujuan\n3. Pilih partner / tipe layanan\n4. Konfirmasi metode pembayaran & tekan "Pesan Sekarang"\n5. Tunggu partner driver menjemput Anda',
    },
    {
      'title': 'Panduan Menggunakan Voucher Promo',
      'icon': '🎫',
      'steps': '1. Buka menu Profil → Rewards & Voucher\n2. Temukan voucher yang tersedia\n3. Tekan "Klaim" atau salin kode voucher\n4. Masukkan kode promo saat konfirmasi pembayaran\n5. Potongan harga otomatis terpasang',
    },
    {
      'title': 'Panduan Mengumpulkan Poin Reward',
      'icon': '⭐',
      'steps': '1. Selesaikan perjalanan secara rutin\n2. Berikan rating & ulasan bintang untuk partner\n3. Ikuti event promo mingguan\n4. Kumpulkan dan tukarkan poin dengan hadiah menarik',
    },
    {
      'title': 'Tips Keamanan Perjalanan',
      'icon': '🛡️',
      'steps': '1. Pastikan nomor plat dan foto partner sesuai aplikasi\n2. Bagikan status perjalanan ke teman/keluarga terdekat\n3. Gunakan fitur tombol darurat (SOS) jika dibutuhkan\n4. Simpan barang bawaan Anda dengan aman',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reportController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  void _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@temeninajaa.com',
      query: 'subject=Temenin Ajaa Support Request',
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  void _launchWhatsApp() async {
    final Uri waUri = Uri.parse('https://wa.me/6281234567890?text=Halo%20Temenin%20Ajaa%20Support');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    }
  }

  void _launchPhone() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '02112345678');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  void _submitReport() {
    if (_emailController.text.isEmpty || _subjectController.text.isEmpty || _reportController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua bidang laporan')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Laporan berhasil dikirim! Tim kami akan merespons melalui email.'),
        backgroundColor: AppTheme.success,
      ),
    );
    _emailController.clear();
    _subjectController.clear();
    _reportController.clear();
  }

  void _showGuideDialog(Map<String, String> guide) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(guide['icon']!, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                guide['title']!,
                style: GoogleFonts.inter(
                  color: AppTheme.textHighContrast,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          guide['steps']!,
          style: GoogleFonts.inter(
            color: AppTheme.textMuted,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup', style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
          'Pusat Bantuan',
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
            Tab(text: 'FAQ'),
            Tab(text: 'Panduan'),
            Tab(text: 'Kontak'),
            Tab(text: 'Lapor'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFaqTab(),
          _buildGuidesTab(),
          _buildContactTab(),
          _buildReportTab(),
        ],
      ),
    );
  }

  Widget _buildFaqTab() {
    final categories = _faqList.map((f) => f['category'] as String).toSet().toList();
    
    return DefaultTabController(
      length: categories.length,
      child: Column(
        children: [
          Container(
            height: 45,
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: TabBar(
              isScrollable: true,
              indicatorColor: AppTheme.primaryPink,
              labelColor: AppTheme.primaryPink,
              unselectedLabelColor: AppTheme.textMuted,
              tabs: categories.map((category) => Tab(text: category)).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: categories.map((category) {
                final faqs = _faqList.where((f) => f['category'] == category).toList();
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: faqs.length,
                  itemBuilder: (context, index) {
                    return _buildFaqItem(faqs[index]);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(Map<String, dynamic> faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            faq['question'],
            style: GoogleFonts.inter(
              color: AppTheme.textHighContrast,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                faq['answer'],
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _guides.length,
      itemBuilder: (context, index) {
        final guide = _guides[index];
        return GestureDetector(
          onTap: () => _showGuideDialog(guide),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Text(
                  guide['icon']!,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    guide['title']!,
                    style: GoogleFonts.inter(
                      color: AppTheme.textHighContrast,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.primaryPink,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Email Support
          _buildContactCard(
            icon: Icons.email_outlined,
            title: 'Email Support',
            description: 'Kirimkan pertanyaan Anda dan kami akan merespons dalam 24 jam',
            actionText: 'support@temeninajaa.com',
            onTap: _launchEmail,
            color: const Color(0xFF10B981),
          ),
          
          const SizedBox(height: 16),
          
          // WhatsApp Support
          _buildContactCard(
            icon: Icons.chat_outlined,
            title: 'WhatsApp Support',
            description: 'Chat langsung dengan tim Customer Care kami',
            actionText: '+62 812-3456-7890',
            onTap: _launchWhatsApp,
            color: const Color(0xFF25D366),
          ),
          
          const SizedBox(height: 16),
          
          // Phone Support
          _buildContactCard(
            icon: Icons.phone_outlined,
            title: 'Telepon Call Center',
            description: 'Layanan panggilan hotline (Senin - Jumat, 09.00 - 18.00 WIB)',
            actionText: '021-12345678',
            onTap: _launchPhone,
            color: AppTheme.primaryPink,
          ),
          
          const SizedBox(height: 16),
          
          // Office Address
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: AppTheme.primaryPink,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alamat Kantor',
                        style: GoogleFonts.inter(
                          color: AppTheme.textHighContrast,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Jl. Sudirman No. 123\nJakarta Selatan, 12190\nIndonesia',
                        style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Business Hours
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: AppTheme.primaryPink,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jam Operasional Bantuan',
                        style: GoogleFonts.inter(
                          color: AppTheme.textHighContrast,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Senin - Jumat: 09:00 - 18:00 WIB\nSabtu: 09:00 - 14:00 WIB\nMinggu & Hari Libur Nasional: Tutup',
                        style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                          height: 1.5,
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
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppTheme.textHighContrast,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                actionText,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laporkan Masalah',
                  style: GoogleFonts.inter(
                    color: AppTheme.textHighContrast,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mengalami kendala pada aplikasi atau perjalanan? Beritahu kami dan tim kami akan segera membantu.',
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Problem Type Dropdown
          Text(
            'Kategori Masalah',
            style: GoogleFonts.inter(
              color: AppTheme.textHighContrast,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedProblemType,
                dropdownColor: AppTheme.surface,
                style: GoogleFonts.inter(color: AppTheme.textHighContrast),
                isExpanded: true,
                items: _problemTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProblemType = value!;
                  });
                },
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Email Field
          Text(
            'Email Anda',
            style: GoogleFonts.inter(
              color: AppTheme.textHighContrast,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            style: GoogleFonts.inter(color: AppTheme.textHighContrast),
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Masukkan alamat email terdaftar',
              hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Subject Field
          Text(
            'Subjek Laporan',
            style: GoogleFonts.inter(
              color: AppTheme.textHighContrast,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _subjectController,
            style: GoogleFonts.inter(color: AppTheme.textHighContrast),
            decoration: InputDecoration(
              hintText: 'Ringkasan singkat kendala Anda',
              hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Message Field
          Text(
            'Detail Masalah',
            style: GoogleFonts.inter(
              color: AppTheme.textHighContrast,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reportController,
            style: GoogleFonts.inter(color: AppTheme.textHighContrast),
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Ceritakan kendala yang Anda alami secara detail...',
              hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Kirim Laporan',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}