import re

with open('c:/temenin_ajaa/driver_temenin_ajaa/driver_app/lib/modules/driver/screens/driver_waiting_countdown_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add _collectAllPins helper
collect_helper = r'''  Set<String> _collectAllPins(dynamic data) {
    final Set<String> pins = {};
    if (data == null) return pins;

    if (data is String) {
      final trimmed = data.trim();
      if (RegExp(r'^\d{4}$').hasMatch(trimmed)) {
        pins.add(trimmed);
      }
      try {
        final decoded = jsonDecode(trimmed);
        pins.addAll(_collectAllPins(decoded));
      } catch (_) {}
    } else if (data is BookingModel) {
      pins.addAll(_collectAllPins(data.additionalDetails));
    } else if (data is Map) {
      for (final key in [
        'otp',
        'security_pin',
        'securityPin',
        'pin',
        'start_otp',
        'startOtp',
        'completion_otp',
        'completionOtp',
        'end_otp',
        'endOtp'
      ]) {
        final val = data[key]?.toString().trim();
        if (val != null && RegExp(r'^\d{4}$').hasMatch(val)) {
          pins.add(val);
        }
      }
      if (data['additional_details'] != null) {
        pins.addAll(_collectAllPins(data['additional_details']));
      }
      if (data['additionalDetails'] != null) {
        pins.addAll(_collectAllPins(data['additionalDetails']));
      }
    }
    return pins;
  }

  String _formatTime(int totalSeconds) {'''

content = content.replace("  String _formatTime(int totalSeconds) {", collect_helper)

# Update expectedPin fetch in _showPinVerificationDialog
old_expected_fetch = r'''    // Fetch fresh from Supabase if null
    if (expectedPin == null || expectedPin.isEmpty) {
      try {
        final dynamic queryId = int.tryParse(_currentBooking.id) ?? _currentBooking.id;
        final freshData = await Supabase.instance.client
            .from('bookings')
            .select('additional_details')
            .eq('id', queryId)
            .maybeSingle();
        if (freshData != null) {
          expectedPin = _extractPin(freshData['additional_details']);
        }
      } catch (e) {
        debugPrint("Error fetching pin from db: $e");
      }
    }'''

new_expected_fetch = r'''    // Fetch fresh from Supabase
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
    }'''

content = content.replace(old_expected_fetch, new_expected_fetch)

# Update verification logic in _showPinVerificationDialog
old_verification = r'''                    // Compare PIN across all valid booking candidates
                    final Set<String> validPins = {};
                    if (expectedPin != null && expectedPin.isNotEmpty) validPins.add(expectedPin);
                    final p1 = _extractPin(_currentBooking.additionalDetails);
                    if (p1 != null && p1.isNotEmpty) validPins.add(p1);

                    try {
                      final dynamic queryId = int.tryParse(_currentBooking.id) ?? _currentBooking.id;
                      final freshData = await Supabase.instance.client
                          .from('bookings')
                          .select('additional_details')
                          .eq('id', queryId)
                          .maybeSingle();
                      if (freshData != null) {
                        final liveOtp = _extractPin(freshData['additional_details']) ?? _extractPin(freshData);
                        if (liveOtp != null && liveOtp.isNotEmpty) validPins.add(liveOtp);
                      }
                    } catch (e) {
                      debugPrint("Error live fetching PIN in countdown: $e");
                    }

                    final isMatch = validPins.isEmpty || validPins.contains(entered);'''

new_verification = r'''                    // Compare PIN across all valid booking candidates
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
                    final isMatch = entered.length == 4 && (validPins.isEmpty || validPins.contains(entered));'''

content = content.replace(old_verification, new_verification)

with open('c:/temenin_ajaa/driver_temenin_ajaa/driver_app/lib/modules/driver/screens/driver_waiting_countdown_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
