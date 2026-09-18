// lib/modules/clients/booking/widgets/multi_service_section.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import 'package:temenin_ajaa/core/services/distance_service.dart';

/// Model for a dynamically added service box
class AdditionalServiceItem {
  final String id;
  final String serviceType; // 'hangout', 'antar_jemput', 'freedom', 'sleep', 'virtual', 'gaming'

  // Hangout specific fields
  String hangoutActivity;
  final TextEditingController customActivityController;
  final TextEditingController hangoutLocationController;
  int hangoutDurationHours;
  final TextEditingController hangoutNotesController;

  // Antar Jemput specific fields
  final TextEditingController pickupController;
  final TextEditingController destinationController;
  bool pulangPergi;
  final TextEditingController returnTimeController;
  bool useCar;
  final TextEditingController antarJemputNotesController;

  // Freedom Request specific fields
  final TextEditingController freedomTitleController;
  final TextEditingController freedomDescriptionController;
  final TextEditingController freedomLocationController;
  final TextEditingController freedomBudgetController;

  // Sleep Call specific fields
  String sleepPackage;
  final TextEditingController sleepWakeTimeController;
  final TextEditingController sleepNotesController;

  // Virtual Call specific fields
  String virtualTopic;
  int virtualDurationMinutes;
  final TextEditingController virtualNotesController;

  // Gaming Buddy specific fields
  String gameTitle;
  final TextEditingController gameIdController;
  int gameMatches;
  final TextEditingController gameNotesController;

  AdditionalServiceItem({
    required this.id,
    required this.serviceType,
    String? defaultPickup,
    String? defaultDestination,
  })  : hangoutActivity = 'Ngopi',
        customActivityController = TextEditingController(),
        hangoutLocationController = TextEditingController(text: defaultDestination ?? ''),
        hangoutDurationHours = 3,
        hangoutNotesController = TextEditingController(),
        pickupController = TextEditingController(text: defaultPickup ?? ''),
        destinationController = TextEditingController(text: defaultDestination ?? ''),
        pulangPergi = false,
        returnTimeController = TextEditingController(),
        useCar = false,
        antarJemputNotesController = TextEditingController(),
        freedomTitleController = TextEditingController(),
        freedomDescriptionController = TextEditingController(),
        freedomLocationController = TextEditingController(text: defaultPickup ?? ''),
        freedomBudgetController = TextEditingController(text: '100000'),
        sleepPackage = 'Paket Malam Nyaman (Hingga Pagi)',
        sleepWakeTimeController = TextEditingController(text: '06:00 WIB'),
        sleepNotesController = TextEditingController(),
        virtualTopic = 'Curhat Asmara & Kehidupan',
        virtualDurationMinutes = 60,
        virtualNotesController = TextEditingController(),
        gameTitle = 'Mobile Legends: Bang Bang',
        gameIdController = TextEditingController(),
        gameMatches = 3,
        gameNotesController = TextEditingController();

  void dispose() {
    customActivityController.dispose();
    hangoutLocationController.dispose();
    hangoutNotesController.dispose();
    pickupController.dispose();
    destinationController.dispose();
    returnTimeController.dispose();
    antarJemputNotesController.dispose();
    freedomTitleController.dispose();
    freedomDescriptionController.dispose();
    freedomLocationController.dispose();
    freedomBudgetController.dispose();
    sleepWakeTimeController.dispose();
    sleepNotesController.dispose();
    virtualNotesController.dispose();
    gameIdController.dispose();
    gameNotesController.dispose();
  }

  int calculateFee() {
    switch (serviceType) {
      case 'hangout':
        return hangoutDurationHours * 50000;
      case 'antar_jemput':
        final base = pulangPergi ? 140000 : 70000;
        final car = useCar ? 50000 : 0;
        return base + car;
      case 'freedom':
        final cleanBudget = freedomBudgetController.text.replaceAll(RegExp(r'[^0-9]'), '');
        final parsed = int.tryParse(cleanBudget);
        return (parsed != null && parsed > 0) ? parsed : 100000;
      case 'sleep':
        if (sleepPackage.contains('Santai')) return 30000;
        if (sleepPackage.contains('Deep Sleep')) return 60000;
        return 45000;
      case 'virtual':
        return ((virtualDurationMinutes / 60) * 35000).round();
      case 'gaming':
        return gameMatches * 15000;
      default:
        return 50000;
    }
  }

  String get displayName {
    switch (serviceType) {
      case 'hangout':
        return "Hangout Partner";
      case 'antar_jemput':
        return "Antar Jemput";
      case 'freedom':
        return "Freedom Request";
      case 'sleep':
        return "Sleep Call Companion";
      case 'virtual':
        return "Virtual Curhat & Konseling";
      case 'gaming':
        return "Gaming Buddy (Mabar)";
      default:
        return "Layanan Tambahan";
    }
  }

  IconData get icon {
    switch (serviceType) {
      case 'hangout':
        return Icons.celebration_rounded;
      case 'antar_jemput':
        return Icons.directions_car_filled_rounded;
      case 'freedom':
        return Icons.explore_rounded;
      case 'sleep':
        return Icons.bedtime_rounded;
      case 'virtual':
        return Icons.phone_in_talk_rounded;
      case 'gaming':
        return Icons.sports_esports_rounded;
      default:
        return Icons.layers_rounded;
    }
  }

  Color get color {
    switch (serviceType) {
      case 'hangout':
        return const Color(0xFFBE185D);
      case 'antar_jemput':
        return AppTheme.primaryPink;
      case 'freedom':
        return const Color(0xFFEA580C);
      case 'sleep':
        return const Color(0xFF312E81);
      case 'virtual':
        return const Color(0xFF7C3AED);
      case 'gaming':
        return const Color(0xFF059669);
      default:
        return AppTheme.primaryPink;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serviceType': serviceType,
      'displayName': displayName,
      'fee': calculateFee(),
      'hangoutActivity': hangoutActivity == 'Lainnya' ? customActivityController.text : hangoutActivity,
      'hangoutLocation': hangoutLocationController.text,
      'hangoutDurationHours': hangoutDurationHours,
      'hangoutNotes': hangoutNotesController.text,
      'pickup': pickupController.text,
      'destination': destinationController.text,
      'pulangPergi': pulangPergi,
      'returnTime': returnTimeController.text,
      'useCar': useCar,
      'antarJemputNotes': antarJemputNotesController.text,
      'freedomTitle': freedomTitleController.text,
      'freedomDescription': freedomDescriptionController.text,
      'freedomLocation': freedomLocationController.text,
      'freedomBudget': calculateFee(),
      'sleepPackage': sleepPackage,
      'sleepWakeTime': sleepWakeTimeController.text,
      'sleepNotes': sleepNotesController.text,
      'virtualTopic': virtualTopic,
      'virtualDurationMinutes': virtualDurationMinutes,
      'virtualNotes': virtualNotesController.text,
      'gameTitle': gameTitle,
      'gameId': gameIdController.text,
      'gameMatches': gameMatches,
      'gameNotes': gameNotesController.text,
    };
  }
}

/// Dynamic multi-service section widget
class MultiServiceSection extends StatefulWidget {
  final List<AdditionalServiceItem> services;
  final VoidCallback onServicesChanged;
  final String currentPrimaryService; // e.g. 'antar_jemput', 'hangout', 'freedom'
  final String? defaultPickup;
  final String? defaultDestination;

  const MultiServiceSection({
    super.key,
    required this.services,
    required this.onServicesChanged,
    required this.currentPrimaryService,
    this.defaultPickup,
    this.defaultDestination,
  });

  @override
  State<MultiServiceSection> createState() => _MultiServiceSectionState();
}

class _MultiServiceSectionState extends State<MultiServiceSection> {
  void _openAddServiceSheet() {
    final availableTypes = [
      {
        'type': 'hangout',
        'title': 'Hangout & Event Partner',
        'subtitle': 'Teman ngopi, makan, nonton, pesta & kondangan',
        'icon': Icons.celebration_rounded,
        'color': const Color(0xFFBE185D),
        'priceHint': 'Rp 50.000 / jam',
      },
      {
        'type': 'antar_jemput',
        'title': 'Antar Jemput Nyaman',
        'subtitle': 'Perjalanan aman langsung diantar ke lokasi tujuan',
        'icon': Icons.directions_car_filled_rounded,
        'color': AppTheme.primaryPink,
        'priceHint': 'Mulai Rp 70.000',
      },
      {
        'type': 'freedom',
        'title': 'Freedom Request (Bebas)',
        'subtitle': 'Request bantuan apa saja & tawar penawaran budget Anda',
        'icon': Icons.explore_rounded,
        'color': const Color(0xFFEA580C),
        'priceHint': 'Sesuai tawaran Anda',
      },
      {
        'type': 'sleep',
        'title': 'Sleep Call Companion',
        'subtitle': 'Teman tidur malam hari & alarm bangun pagi tepat waktu',
        'icon': Icons.bedtime_rounded,
        'color': const Color(0xFF312E81),
        'priceHint': 'Mulai Rp 45.000 / malam',
      },
      {
        'type': 'virtual',
        'title': 'Telepon Curhat & Virtual',
        'subtitle': 'Panggilan suara santai, ruang aman berkeluh kesah',
        'icon': Icons.phone_in_talk_rounded,
        'color': const Color(0xFF7C3AED),
        'priceHint': 'Mulai Rp 35.000 / jam',
      },
      {
        'type': 'gaming',
        'title': 'Gaming Buddy (Mabar)',
        'subtitle': 'Partner push rank seru (MLBB, PUBG, Valorant, dll)',
        'icon': Icons.sports_esports_rounded,
        'color': const Color(0xFF059669),
        'priceHint': 'Rp 15.000 / match',
      },
    ];

    // Filter out the primary service from additional options to avoid redundancy
    final filtered = availableTypes
        .where((item) => item['type'] != widget.currentPrimaryService)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.fuchsiaLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_box_rounded, color: AppTheme.primaryPink, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Tambah Layanan ke Pesanan",
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textHighContrast,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "Pilih layanan ekstra yang ingin digabungkan",
                            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final color = item['color'] as Color;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _addNewService(item['type'] as String);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(item['icon'] as IconData, color: color, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['title'] as String,
                                            style: GoogleFonts.inter(
                                              color: AppTheme.textHighContrast,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['subtitle'] as String,
                                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['priceHint'] as String,
                                      style: GoogleFonts.inter(
                                        color: color,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryPink, size: 22),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addNewService(String type) {
    final newItem = AdditionalServiceItem(
      id: "srv_${DateTime.now().millisecondsSinceEpoch}",
      serviceType: type,
      defaultPickup: widget.defaultPickup,
      defaultDestination: widget.defaultDestination,
    );

    setState(() {
      widget.services.add(newItem);
    });
    widget.onServicesChanged();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Kotak layanan ${newItem.displayName} berhasil ditambahkan!"),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.primaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeService(int index) {
    final item = widget.services[index];
    setState(() {
      widget.services.removeAt(index);
    });
    widget.onServicesChanged();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Layanan ${item.displayName} dihapus."),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatNumber(int val) {
    return val.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    final totalAdditionalFee = widget.services.fold<int>(0, (sum, item) => sum + item.calculateFee());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "Multi-Layanan",
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textHighContrast,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.services.isNotEmpty
                              ? AppTheme.primaryPink.withOpacity(0.15)
                              : AppTheme.border.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.services.isNotEmpty
                                ? AppTheme.primaryPink.withOpacity(0.4)
                                : AppTheme.border,
                          ),
                        ),
                        child: Text(
                          "${widget.services.length} Layanan Ekstra",
                          style: GoogleFonts.inter(
                            color: widget.services.isNotEmpty ? AppTheme.primaryPink : AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Tambah hingga 3 atau 4 layanan berbeda dalam satu pesanan",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // List of Active Service Boxes
        if (widget.services.isEmpty)
          _buildEmptyServicesPlaceholder()
        else
          ...widget.services.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildServiceBox(item, index);
          }),

        const SizedBox(height: 14),

        // Add Service Action Bar & Summary
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openAddServiceSheet,
                icon: const Icon(Icons.add_rounded, color: AppTheme.primaryPink, size: 20),
                label: Text(
                  widget.services.isEmpty ? "+ Tambah Layanan Ekstra" : "+ Tambah Layanan Lain",
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryPink,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primaryPink, width: 1.4),
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: AppTheme.primaryPink.withOpacity(0.04),
                ),
              ),
            ),
            if (widget.services.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Subtotal Ekstra",
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Rp ${_formatNumber(totalAdditionalFee)}",
                      style: GoogleFonts.inter(
                        color: AppTheme.primaryPink,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyServicesPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryPink.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.dashboard_customize_rounded, color: AppTheme.primaryPink, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Butuh Layanan Tambahan Sekaligus?",
                  style: GoogleFonts.inter(
                    color: AppTheme.textHighContrast,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Gabungkan Hangout, Antar Jemput, Freedom Request, atau Sleep Call dengan mudah.",
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11.5, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceBox(AdditionalServiceItem item, int index) {
    final fee = item.calculateFee();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: item.color.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Box Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              border: Border(bottom: BorderSide(color: item.color.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.displayName,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textHighContrast,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "#${index + 1}",
                              style: GoogleFonts.inter(
                                color: item.color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        "Rp ${_formatNumber(fee)}",
                        style: GoogleFonts.inter(
                          color: item.color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Remove Button
                GestureDetector(
                  onTap: () => _removeService(index),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Box Body: Form Fields based on service type
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildServiceFields(item),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceFields(AdditionalServiceItem item) {
    switch (item.serviceType) {
      case 'hangout':
        return _buildHangoutFields(item);
      case 'antar_jemput':
        return _buildAntarJemputFields(item);
      case 'freedom':
        return _buildFreedomFields(item);
      case 'sleep':
        return _buildSleepFields(item);
      case 'virtual':
        return _buildVirtualFields(item);
      case 'gaming':
        return _buildGamingFields(item);
      default:
        return const SizedBox.shrink();
    }
  }

  // 1. HANGOUT FORM FIELDS
  Widget _buildHangoutFields(AdditionalServiceItem item) {
    final activities = ['Ngopi', 'Makan', 'Nonton', 'Jalan-jalan', 'Shopping', 'Event', 'Kondangan', 'Lainnya'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel("Pilih Aktivitas Hangout"),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: activities.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final act = activities[idx];
              final isSel = item.hangoutActivity == act;
              return GestureDetector(
                onTap: () {
                  setState(() => item.hangoutActivity = act);
                  widget.onServicesChanged();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? item.color : AppTheme.cardDeep,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSel ? item.color : AppTheme.border),
                  ),
                  child: Center(
                    child: Text(
                      act,
                      style: GoogleFonts.inter(
                        color: isSel ? Colors.white : AppTheme.textHighContrast,
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (item.hangoutActivity == 'Lainnya') ...[
          const SizedBox(height: 10),
          _buildInputBox(
            controller: item.customActivityController,
            hint: "Ketik aktivitas kustom...",
            icon: Icons.edit_note_rounded,
          ),
        ],
        const SizedBox(height: 14),

        _buildFieldLabel("Lokasi Tempat Hangout"),
        const SizedBox(height: 6),
        _buildInputBox(
          controller: item.hangoutLocationController,
          hint: "Contoh: Senayan City Mall / Coffee Shop Jaksel",
          icon: Icons.location_on_rounded,
          onMapPick: () {
            DistanceService.showLocationPickerModal(
              context,
              title: "Pilih Lokasi Hangout",
              initialValue: item.hangoutLocationController.text,
              onSelected: (addr, lat, lng) {
                setState(() => item.hangoutLocationController.text = addr);
                widget.onServicesChanged();
              },
            );
          },
        ),
        const SizedBox(height: 14),

        _buildFieldLabel("Pilih Durasi Hangout (Rp 50.000/jam)"),
        const SizedBox(height: 8),
        Row(
          children: [2, 3, 4, 6].map((hrs) {
            final isSel = item.hangoutDurationHours == hrs;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => item.hangoutDurationHours = hrs);
                  widget.onServicesChanged();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSel ? item.color : AppTheme.cardDeep,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSel ? item.color : AppTheme.border),
                  ),
                  child: Text(
                    "$hrs Jam",
                    style: GoogleFonts.inter(
                      color: isSel ? Colors.white : AppTheme.textHighContrast,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        _buildFieldLabel("Catatan Hangout (Opsional)"),
        const SizedBox(height: 6),
        _buildInputBox(
          controller: item.hangoutNotesController,
          hint: "Contoh: Mohon pakai pakaian semi-formal...",
          icon: Icons.note_rounded,
          maxLines: 2,
        ),
      ],
    );
  }

  // 2. ANTAR JEMPUT FORM FIELDS
  Widget _buildAntarJemputFields(AdditionalServiceItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel("Lokasi Penjemputan"),
        const SizedBox(height: 6),
        _buildInputBox(
          controller: item.pickupController,
          hint: "Titik penjemputan rute",
          icon: Icons.my_location_rounded,
          onMapPick: () {
            DistanceService.showLocationPickerModal(
              context,
              title: "Pilih Titik Penjemputan",
              initialValue: item.pickupController.text,
              onSelected: (addr, lat, lng) {
                setState(() => item.pickupController.text = addr);
                widget.onServicesChanged();
              },
            );
          },
        ),
        const SizedBox(height: 12),

        _buildFieldLabel("Lokasi Tujuan Antar"),
        const SizedBox(height: 6),
        _buildInputBox(
          controller: item.destinationController,
          hint: "Titik pengantaran rute",
          icon: Icons.flag_rounded,
          onMapPick: () {
            DistanceService.showLocationPickerModal(
              context,
              title: "Pilih Titik Pengantaran",
              initialValue: item.destinationController.text,
              onSelected: (addr, lat, lng) {
                setState(() => item.destinationController.text = addr);
                widget.onServicesChanged();
              },
            );
          },
        ),
        const SizedBox(height: 12),

        // Pulang Pergi Option (Fixed right-overflow)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardDeep,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Checkbox(
                value: item.pulangPergi,
                onChanged: (val) {
                  setState(() => item.pulangPergi = val ?? false);
                  widget.onServicesChanged();
                },
                activeColor: item.color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => item.pulangPergi = !item.pulangPergi);
                    widget.onServicesChanged();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pulang Pergi (PP)",
                        style: GoogleFonts.inter(
                          color: AppTheme.textHighContrast,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Rute perjalanan ganda (jemput & antar balik)",
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                "+Rp 70.000",
                style: GoogleFonts.inter(
                  color: item.color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Use Car Option
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardDeep,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Checkbox(
                value: item.useCar,
                onChanged: (val) {
                  setState(() => item.useCar = val ?? false);
                  widget.onServicesChanged();
                },
                activeColor: item.color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => item.useCar = !item.useCar);
                    widget.onServicesChanged();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Gunakan Mobil Ber-AC",
                        style: GoogleFonts.inter(
                          color: AppTheme.textHighContrast,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Perjalanan nyaman dengan kendaraan roda 4",
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                "+Rp 50.000",
                style: GoogleFonts.inter(
                  color: item.color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildFieldLabel("Catatan Perjalanan"),
        const SizedBox(height: 6),
        _buildInputBox(
          controller: item.antarJemputNotesController,
          hint: "Contoh: Tunggu di lobi timur, bawa payung...",
          icon: Icons.note_rounded,
        ),
      ],
    );
  }

  // 3. FREEDOM REQUEST FORM FIELDS
  Widget _buildFreedomFields(AdditionalServiceItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel("Judul Request Tambahan"),
        const SizedBox(height: 6),
        _buildInputBox(
          controller: item.freedomTitleController,
          hint: "Contoh: Titip Beli Kado / Antre Tiket",
          icon: Icons.label_important_outline_rounded,
        ),
        const SizedBox(height: 12),

        _buildFieldLabel("Deskripsi Bantuan (Terbuka)"),
        const SizedBox(height: 6),
        _buildInputBox(
          controller: item.freedomDescriptionController,
          hint: "Tuliskan rincian bantuan yang Anda perlukan secara spesifik...",
          icon: Icons.edit_note_rounded,
          maxLines: 2,
        ),
        const SizedBox(height: 12),

        _buildFieldLabel("Lokasi Pelaksanaan Request"),
        const SizedBox(height: 6),
        _buildInputBox(
          controller: item.freedomLocationController,
          hint: "Lokasi toko / titik tugas dilaksanakan",
          icon: Icons.place_rounded,
          onMapPick: () {
            DistanceService.showLocationPickerModal(
              context,
              title: "Pilih Lokasi Freedom Request",
              initialValue: item.freedomLocationController.text,
              onSelected: (addr, lat, lng) {
                setState(() => item.freedomLocationController.text = addr);
                widget.onServicesChanged();
              },
            );
          },
        ),
        const SizedBox(height: 12),

        _buildFieldLabel("Tawaran Biaya untuk Layanan Ini (Rp)"),
        const SizedBox(height: 6),
        _buildInputBox(
          controller: item.freedomBudgetController,
          hint: "Masukkan tawaran budget Anda",
          icon: Icons.payments_rounded,
          keyboardType: TextInputType.number,
          onChanged: (_) => widget.onServicesChanged(),
        ),
      ],
    );
  }

  // 4. SLEEP CALL FORM FIELDS
  Widget _buildSleepFields(AdditionalServiceItem item) {
    final packages = [
      'Paket Santai (1 Jam)',
      'Paket Malam Nyaman (Hingga Pagi)',
      'Paket Deep Sleep + Alarm Pagi',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel("Pilih Paket Sleep Call"),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppTheme.cardDeep,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: item.sleepPackage,
              isExpanded: true,
              dropdownColor: AppTheme.surface,
              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
              items: packages.map((pkg) => DropdownMenuItem(value: pkg, child: Text(pkg, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => item.sleepPackage = val);
                  widget.onServicesChanged();
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        _buildFieldLabel("Jam Bangun & Pengingat Alarm"),
        const SizedBox(height: 6),
        _buildInputBox(
          controller: item.sleepWakeTimeController,
          hint: "Contoh: 05:30 WIB",
          icon: Icons.alarm_rounded,
        ),
        const SizedBox(height: 12),

        _buildFieldLabel("Catatan Khusus (Suara lembut, dll)"),
        const SizedBox(height: 6),
        _buildInputBox(
          controller: item.sleepNotesController,
          hint: "Instruksi sebelum tidur...",
          icon: Icons.note_rounded,
        ),
      ],
    );
  }

  // 5. VIRTUAL CALL FORM FIELDS
  Widget _buildVirtualFields(AdditionalServiceItem item) {
    final topics = [
      'Curhat Asmara & Kehidupan',
      'Diskusi Karir & Studi',
      'Teman Ngobrol Santai',
      'Konseling Ringan',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel("Topik Panggilan Suara"),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppTheme.cardDeep,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: item.virtualTopic,
              isExpanded: true,
              dropdownColor: AppTheme.surface,
              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
              items: topics.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => item.virtualTopic = val);
                  widget.onServicesChanged();
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        _buildFieldLabel("Durasi Panggilan"),
        const SizedBox(height: 8),
        Row(
          children: [30, 60, 90, 120].map((mins) {
            final isSel = item.virtualDurationMinutes == mins;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => item.virtualDurationMinutes = mins);
                  widget.onServicesChanged();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSel ? item.color : AppTheme.cardDeep,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSel ? item.color : AppTheme.border),
                  ),
                  child: Text(
                    "$mins Mnt",
                    style: GoogleFonts.inter(
                      color: isSel ? Colors.white : AppTheme.textHighContrast,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        _buildFieldLabel("Catatan Preferensi Teman Curhat"),
        const SizedBox(height: 6),
        _buildInputBox(
          controller: item.virtualNotesController,
          hint: "Contoh: Pendengar yang baik & tanpa menghakimi...",
          icon: Icons.note_rounded,
        ),
      ],
    );
  }

  // 6. GAMING BUDDY FORM FIELDS
  Widget _buildGamingFields(AdditionalServiceItem item) {
    final games = [
      'Mobile Legends: Bang Bang',
      'PUBG Mobile',
      'Free Fire',
      'Valorant',
      'Honor of Kings',
      'Lainnya',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel("Pilih Game yang Dimainkan"),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppTheme.cardDeep,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: item.gameTitle,
              isExpanded: true,
              dropdownColor: AppTheme.surface,
              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
              items: games.map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => item.gameTitle = val);
                  widget.onServicesChanged();
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        _buildFieldLabel("ID Game / Nickname Akun"),
        const SizedBox(height: 6),
        _buildInputBox(
          controller: item.gameIdController,
          hint: "Masukkan ID atau Nickname in-game...",
          icon: Icons.sports_esports_rounded,
        ),
        const SizedBox(height: 12),

        _buildFieldLabel("Jumlah Match (Rp 15.000/match)"),
        const SizedBox(height: 8),
        Row(
          children: [1, 3, 5, 8].map((matches) {
            final isSel = item.gameMatches == matches;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => item.gameMatches = matches);
                  widget.onServicesChanged();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSel ? item.color : AppTheme.cardDeep,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSel ? item.color : AppTheme.border),
                  ),
                  child: Text(
                    "$matches Match",
                    style: GoogleFonts.inter(
                      color: isSel ? Colors.white : AppTheme.textHighContrast,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        color: AppTheme.textMediumContrast,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildInputBox({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
    VoidCallback? onMapPick,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
          prefixIcon: Icon(icon, color: AppTheme.primaryPink, size: 18),
          suffixIcon: onMapPick != null
              ? IconButton(
                  icon: const Icon(Icons.map_rounded, color: AppTheme.primaryPink, size: 18),
                  tooltip: "Pilih di Peta",
                  onPressed: onMapPick,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
