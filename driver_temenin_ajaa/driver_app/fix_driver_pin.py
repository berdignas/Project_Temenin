import re

with open('c:/temenin_ajaa/driver_temenin_ajaa/driver_app/lib/modules/driver/screens/active_booking_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add _collectAllPins helper method
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

  String? _extractOtp(dynamic data) {'''

content = content.replace("  String? _extractOtp(dynamic data) {", collect_helper)

# Replace validPins logic in _showPinVerificationDialog
old_verification = r'''                                final Set<String> validPins = {};
                                if (expectedPin.isNotEmpty) validPins.add(expectedPin);

                                final active = provider.activeBooking;
                                if (active != null) {
                                  final p1 = _extractOtp(active.additionalDetails);
                                  if (p1 != null && p1.isNotEmpty) validPins.add(p1);
                                  final p2 = _extractCompletionOtp(active.additionalDetails);
                                  if (p2 != null && p2.isNotEmpty) validPins.add(p2);

                                  try {
                                    final dynamic queryId = int.tryParse(active.id) ?? active.id;
                                    final freshData = await Supabase.instance.client
                                        .from('bookings')
                                        .select('additional_details')
                                        .eq('id', queryId)
                                        .maybeSingle();

                                    if (freshData != null) {
                                      final liveOtp = _extractOtp(freshData['additional_details']) ?? _extractOtp(freshData);
                                      if (liveOtp != null && liveOtp.isNotEmpty) validPins.add(liveOtp);
                                      final liveComp = _extractCompletionOtp(freshData['additional_details']) ?? _extractCompletionOtp(freshData);
                                      if (liveComp != null && liveComp.isNotEmpty) validPins.add(liveComp);
                                    }
                                  } catch (e) {
                                    debugPrint("Error live fetching PIN in verification: $e");
                                  }
                                }

                                debugPrint("Verifying PIN: input='$inputPin', validPins=$validPins");
                                final isMatch = validPins.isEmpty || validPins.contains(inputPin);'''

new_verification = r'''                                final Set<String> validPins = {};
                                if (expectedPin.isNotEmpty) validPins.add(expectedPin);

                                final active = provider.activeBooking;
                                if (active != null) {
                                  validPins.addAll(_collectAllPins(active));
                                  validPins.addAll(_collectAllPins(active.additionalDetails));

                                  try {
                                    final String strId = active.id.toString();
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
                                    debugPrint("Error live fetching PIN in verification: $e");
                                  }
                                }

                                debugPrint("Verifying PIN: input='$inputPin', validPins=$validPins");
                                final isMatch = inputPin.length == 4 && (validPins.isEmpty || validPins.contains(inputPin));'''

content = content.replace(old_verification, new_verification)

with open('c:/temenin_ajaa/driver_temenin_ajaa/driver_app/lib/modules/driver/screens/active_booking_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
