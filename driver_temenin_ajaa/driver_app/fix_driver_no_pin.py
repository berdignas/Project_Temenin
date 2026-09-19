import re

with open('c:/temenin_ajaa/driver_temenin_ajaa/driver_app/lib/modules/driver/screens/driver_waiting_countdown_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _showPinVerificationDialog with simple YES/NO confirmation dialog
old_dialog = r'''  Future<void> _showPinVerificationDialog() async {
    final pinController = TextEditingController();
    String? expectedPin = _extractPin(_currentBooking.additionalDetails) ?? _extractPin(_currentBooking);

    // Fetch fresh from Supabase
    try {
      final String strId = _currentBooking.id.toString();
      final dynamic numId = int.tryParse(strId);
      var freshData = await Supabase.instance.client
          .from('bookings')
          .select('additional_details')
          .eq('id', strId)
          .maybeSingle();
      if (freshData == null && numId != null) {
        freshData = await Supabase.instance.client
            .from('bookings')
            .select('additional_details')
            .eq('id', numId)
            .maybeSingle();
      }
      if (freshData != null) {
        final fPin = _extractPin(freshData['additional_details']) ?? _extractPin(freshData);
        if (fPin != null && fPin.isNotEmpty) {
          expectedPin = fPin;
        }
      }
    } catch (e) {
      debugPrint("Error fetching pin from db: $e");
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: AppTheme.primaryPink, width: 1.5),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.key_rounded, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Verifikasi PIN Klien",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textHighContrast,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Untuk mengakhiri waktu tunggu lebih cepat dan langsung berangkat OTW, masukkan 4-digit PIN keamanan dari klien:",
                    style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textHighContrast,
                      fontSize: 24,
                      letterSpacing: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: "••••",
                      hintStyle: const TextStyle(color: AppTheme.textMuted, letterSpacing: 10),
                      filled: true,
                      fillColor: AppTheme.cardDeep,
                      counterText: "",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.primaryPink, width: 2),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: GoogleFonts.inter(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    "BATAL",
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final entered = pinController.text.trim();
                    if (entered.length != 4) {
                      setDialogState(() {
                        errorMessage = "Masukkan 4 digit PIN dengan lengkap.";
                      });
                      return;
                    }

                    // Compare PIN across all valid booking candidates
                    final Set<String> validPins = {};
                    if (expectedPin != null && expectedPin.isNotEmpty) validPins.add(expectedPin);
                    validPins.addAll(_collectAllPins(_currentBooking));
                    validPins.addAll(_collectAllPins(_currentBooking.additionalDetails));

                    try {
                      final String strId = _currentBooking.id.toString();
                      final dynamic numId = int.tryParse(strId);
                      var freshData = await Supabase.instance.client
                          .from('bookings')
                          .select('additional_details')
                          .eq('id', strId)
                          .maybeSingle();
                      if (freshData == null && numId != null) {
                        freshData = await Supabase.instance.client
                            .from('bookings')
                            .select('additional_details')
                            .eq('id', numId)
                            .maybeSingle();
                      }
                      if (freshData != null) {
                        validPins.addAll(_collectAllPins(freshData));
                        validPins.addAll(_collectAllPins(freshData['additional_details']));
                      }
                    } catch (e) {
                      debugPrint("Error live fetching PIN in countdown: $e");
                    }

                    debugPrint("Verifying Countdown PIN: input='$entered', validPins=$validPins");
                    final isMatch = entered.length == 4 && (validPins.isEmpty || validPins.contains(entered));

                    if (isMatch) {
                      Navigator.pop(dialogCtx);
                      _countdownTimer?.cancel();
                      _bookingSub?.cancel();
                      setState(() {
                        _remainingSeconds = 0;
                        _isCountdownFinished = true;
                      });

                      NotificationSoundService().playOrderAlert();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("? PIN Berhasil Diverifikasi! Memulai perjalanan (OTW) menuju klien..."),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }

                      // Langsung berangkat OTW ke langkah selanjutnya
                      await _startTripOtw();
                    } else {
                      setDialogState(() {
                        errorMessage = "PIN tidak cocok! Tanyakan 4-digit PIN yang tampil di aplikasi Klien.";
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "VERIFIKASI PIN",
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }'''

new_dialog = r'''  Future<void> _showPinVerificationDialog() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppTheme.primaryPink, width: 1.5),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: AppTheme.primaryPink, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Konfirmasi Berangkat OTW",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textHighContrast,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            "Apakah Anda ingin mengakhiri waktu tunggu persiapan dan langsung berangkat (OTW) menuju lokasi klien sekarang?",
            style: GoogleFonts.inter(color: AppTheme.textMediumContrast, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                "BATAL",
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                _countdownTimer?.cancel();
                _bookingSub?.cancel();
                setState(() {
                  _remainingSeconds = 0;
                  _isCountdownFinished = true;
                });

                try {
                  NotificationSoundService().playOrderAlert();
                } catch (_) {}

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("?? Memulai perjalanan (OTW) menuju lokasi klien..."),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

                await _startTripOtw();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "YA, BERANGKAT OTW",
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }'''

content = content.replace(old_dialog, new_dialog)

# Update button text to remove PIN mention
content = content.replace(
    '"? Mulai Lebih Awal (Verifikasi PIN Klien)"',
    '"? Mulai Lebih Awal (Berangkat OTW)"'
)

with open('c:/temenin_ajaa/driver_temenin_ajaa/driver_app/lib/modules/driver/screens/driver_waiting_countdown_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
