import re

with open('c:/temenin_ajaa/temenin_ajaa/lib/modules/clients/booking/screens/client_waiting_countdown_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old_save = r'''  Future<void> _savePinToDatabase(String pin) async {
    final bId = widget.bookingId ?? _currentDetails['id']?.toString();
    if (bId == null || bId.isEmpty) return;

    try {
      final dynamic queryId = int.tryParse(bId) ?? bId;
      final existingAdd = _currentDetails['additional_details'] is Map
          ? Map<String, dynamic>.from(_currentDetails['additional_details'])
          : (_currentDetails['additionalDetails'] is Map
              ? Map<String, dynamic>.from(_currentDetails['additionalDetails'])
              : <String, dynamic>{});
      existingAdd['otp'] = pin;

      await Supabase.instance.client
          .from('bookings')
          .update({'additional_details': existingAdd})
          .eq('id', queryId);
    } catch (e) {
      debugPrint("Error saving PIN to Supabase: $e");
    }
  }'''

new_save = r'''  Future<void> _savePinToDatabase(String pin) async {
    final bId = widget.bookingId ?? _currentDetails['id']?.toString();
    if (bId == null || bId.isEmpty) return;

    try {
      final String strId = bId.toString();
      final dynamic numId = int.tryParse(strId);
      final existingAdd = _currentDetails['additional_details'] is Map
          ? Map<String, dynamic>.from(_currentDetails['additional_details'])
          : (_currentDetails['additionalDetails'] is Map
              ? Map<String, dynamic>.from(_currentDetails['additionalDetails'])
              : <String, dynamic>{});
      existingAdd['otp'] = pin;
      existingAdd['security_pin'] = pin;

      try {
        await Supabase.instance.client
            .from('bookings')
            .update({'additional_details': existingAdd})
            .eq('id', strId);
      } catch (_) {}

      if (numId != null) {
        try {
          await Supabase.instance.client
              .from('bookings')
              .update({'additional_details': existingAdd})
              .eq('id', numId);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("Error saving PIN to Supabase: $e");
    }
  }'''

content = content.replace(old_save, new_save)

with open('c:/temenin_ajaa/temenin_ajaa/lib/modules/clients/booking/screens/client_waiting_countdown_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
