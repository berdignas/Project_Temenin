import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

class DriverAddonsScreen extends StatefulWidget {
  const DriverAddonsScreen({super.key});

  @override
  State<DriverAddonsScreen> createState() => _DriverAddonsScreenState();
}

class _DriverAddonsScreenState extends State<DriverAddonsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _addons = [];

  @override
  void initState() {
    super.initState();
    _loadDriverAddons();
  }

  void _loadDriverAddons() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final driver = auth.driverProfileData;
    final String vehicleStnk = driver?['vehicle_stnk'] ?? '';

    List<Map<String, dynamic>> loaded = [];
    if (vehicleStnk.startsWith('{')) {
      try {
        final Map<String, dynamic> metadata = jsonDecode(vehicleStnk);
        if (metadata['addons'] != null && metadata['addons'] is List) {
          loaded = List<Map<String, dynamic>>.from(
            (metadata['addons'] as List).map((a) => Map<String, dynamic>.from(a)),
          );
        }
      } catch (e) {
        debugPrint('Error parsing addons from vehicle_stnk: $e');
      }
    }

    setState(() {
      _addons = loaded;
    });
  }

  Future<void> _saveAddonsToDatabase() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    if (user != null) {
      Map<String, dynamic> metadata = {};
      final rawStnk = auth.driverProfileData?['vehicle_stnk'] ?? '';
      if (rawStnk.toString().startsWith('{')) {
        try {
          metadata = Map<String, dynamic>.from(jsonDecode(rawStnk.toString()));
        } catch (_) {}
      }

      metadata['addons'] = _addons;
      final String jsonString = jsonEncode(metadata);

      try {
        final supabase = Supabase.instance.client;
        await supabase
            .from('drivers')
            .update({'vehicle_stnk': jsonString})
            .or('user_id.eq.${user.id},id.eq.${user.id}');

        await auth.refreshProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Daftar Add-on berhasil disimpan!',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error saving addons: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menyimpan: $e'),
              backgroundColor: AppTheme.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
    setState(() => _isLoading = false);
  }

  void _showAddCustomAddonDialog([Map<String, dynamic>? existing, int? index]) {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final priceCtrl = TextEditingController(text: (existing?['price'] ?? 20000).toString());
    String selectedCategory = existing?['category'] ?? 'Layanan';

    final categories = ['Dokumentasi', 'Transport', 'Style', 'Fasilitas', 'Aktivitas', 'Layanan'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                existing == null ? "Tambah Add-on Kustom" : "Edit Add-on",
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textHighContrast,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Buat add-on / fasilitas khusus yang Anda tawarkan ke klien saat pemesanan.",
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5),
                    ),
                    const SizedBox(height: 14),

                    _dialogFieldLabel("NAMA ADD-ON / FASILITAS"),
                    _dialogTextField(
                      controller: titleCtrl,
                      hint: "Contoh: Bawa Gitar & Nyanyi Akustik",
                      icon: Icons.label_important_outline_rounded,
                    ),
                    const SizedBox(height: 12),

                    _dialogFieldLabel("TARIF TAMBAHAN (RP)"),
                    _dialogTextField(
                      controller: priceCtrl,
                      hint: "25000",
                      icon: Icons.monetization_on_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),

                    _dialogFieldLabel("KATEGORI"),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDeep,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCategory,
                          dropdownColor: AppTheme.surface,
                          isExpanded: true,
                          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
                          items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedCategory = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _dialogFieldLabel("DESKRIPSI PENJELASAN"),
                    _dialogTextField(
                      controller: descCtrl,
                      hint: "Jelaskan fasilitas atau barang yang Anda sediakan...",
                      icon: Icons.description_outlined,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Batal", style: GoogleFonts.inter(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;
                    final price = int.tryParse(priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 20000;
                    final desc = descCtrl.text.trim();

                    setState(() {
                      if (existing != null && index != null) {
                        _addons[index] = {
                          ...existing,
                          'title': title,
                          'price': price,
                          'description': desc,
                          'category': selectedCategory,
                        };
                      } else {
                        _addons.add({
                          'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
                          'title': title,
                          'price': price,
                          'description': desc,
                          'category': selectedCategory,
                          'icon_name': 'custom',
                          'is_active': true,
                        });
                      }
                    });

                    Navigator.pop(ctx);
                    _saveAddonsToDatabase();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "Simpan",
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dialogFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: GoogleFonts.inter(color: AppTheme.primaryPink, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _dialogTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
          prefixIcon: Icon(icon, color: AppTheme.primaryPink, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  IconData _getAddonIcon(String? iconName, String? category) {
    switch (iconName) {
      case 'camera': return Icons.camera_alt_rounded;
      case 'car': return Icons.directions_car_rounded;
      case 'outfit': return Icons.checkroom_rounded;
      case 'coffee': return Icons.local_cafe_rounded;
      case 'sport': return Icons.sports_tennis_rounded;
      case 'guide': return Icons.map_rounded;
      case 'shopping': return Icons.shopping_bag_rounded;
      default:
        switch (category?.toLowerCase()) {
          case 'dokumentasi': return Icons.camera_alt_rounded;
          case 'transport': return Icons.directions_car_rounded;
          case 'style': return Icons.checkroom_rounded;
          case 'fasilitas': return Icons.room_service_rounded;
          case 'aktivitas': return Icons.sports_esports_rounded;
          default: return Icons.stars_rounded;
        }
    }
  }

  String _formatCurrency(int amount) {
    return "Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _addons.where((a) => a['is_active'] == true).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          "Kelola Add-ons & Fasilitas",
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textHighContrast,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textHighContrast, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded, color: AppTheme.primaryPink),
            tooltip: "Simpan Add-ons",
            onPressed: _isLoading ? null : _saveAddonsToDatabase,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPink))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryPink.withValues(alpha: 0.15),
                          AppTheme.fuchsiaLight.withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPink,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.extension_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Add-ons Mitra Terkustomisasi",
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textHighContrast,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$activeCount add-on aktif akan otomatis muncul sebagai opsi ekstra di form pesanan klien Anda.",
                                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section Title & Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "DAFTAR ADD-ON & FASILITAS ANDA",
                        style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      InkWell(
                        onTap: () => _showAddCustomAddonDialog(),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryPink, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                "Tambah Kustom",
                                style: GoogleFonts.inter(
                                  color: AppTheme.primaryPink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Addons List
                  if (_addons.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.cardDeep,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.extension_off_rounded, color: AppTheme.textMuted, size: 36),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            "Belum Ada Add-on Disediakan",
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textHighContrast,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Jika Anda memiliki fasilitas tambahan (seperti kamera pro, snack, perlengkapan olahraga, dll.), Anda bisa menambahkannya di sini.",
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () => _showAddCustomAddonDialog(),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              "Tambah Add-on Baru",
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPink,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _addons.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _addons[index];
                        final isActive = item['is_active'] == true;
                        final price = (item['price'] is int)
                            ? item['price'] as int
                            : (int.tryParse(item['price']?.toString() ?? '0') ?? 0);
                        final title = item['title'] ?? 'Add-on';
                        final desc = item['description'] ?? '';
                        final category = item['category'] ?? 'Layanan';
                        final icon = _getAddonIcon(item['icon_name'], category);

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isActive ? AppTheme.surface : AppTheme.surface.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive ? AppTheme.primaryPink.withValues(alpha: 0.35) : AppTheme.border,
                              width: isActive ? 1.2 : 1.0,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppTheme.primaryPink.withValues(alpha: 0.15)
                                      : AppTheme.cardDeep,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  icon,
                                  color: isActive ? AppTheme.primaryPink : AppTheme.textMuted,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.fuchsiaLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        category.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          color: AppTheme.primaryPink,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      title,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: isActive ? AppTheme.textHighContrast : AppTheme.textMuted,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    if (desc.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        desc,
                                        style: GoogleFonts.inter(
                                          color: AppTheme.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          _formatCurrency(price),
                                          style: GoogleFonts.inter(
                                            color: isActive ? AppTheme.primaryPink : AppTheme.textMuted,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        InkWell(
                                          onTap: () => _showAddCustomAddonDialog(item, index),
                                          child: Text(
                                            "Ubah Tarif",
                                            style: GoogleFonts.inter(
                                              color: AppTheme.primaryPink,
                                              fontSize: 11,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () {
                                            setState(() => _addons.removeAt(index));
                                            _saveAddonsToDatabase();
                                          },
                                          child: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 18),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isActive,
                                activeColor: AppTheme.primaryPink,
                                onChanged: (val) {
                                  setState(() {
                                    _addons[index]['is_active'] = val;
                                  });
                                  _saveAddonsToDatabase();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 28),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveAddonsToDatabase,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: Text(
                        "SIMPAN PERUBAHAN ADD-ON",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.8,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
