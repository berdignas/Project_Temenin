import re

with open('c:/temenin_ajaa/temenin_ajaa/lib/modules/clients/booking/screens/tracking_driver_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _ensureRealOtpExists implementation
old_ensure = r'''  Future<void> _ensureRealOtpExists() async {
    try {
      final bookingId = _currentBookingId ?? widget.bookingId;
      if (bookingId == null || bookingId.startsWith('mock')) return;

      final dynamic queryId = int.tryParse(bookingId) ?? bookingId;
      Map<String, dynamic> dbDetails = {};

      final currentRec = await Supabase.instance.client
          .from('bookings')
          .select('additional_details')
          .eq('id', queryId)
          .maybeSingle();

      if (currentRec != null && currentRec['additional_details'] != null) {
        if (currentRec['additional_details'] is Map) {
          dbDetails = Map<String, dynamic>.from(currentRec['additional_details'] as Map);
        } else if (currentRec['additional_details'] is String) {
          try {
            final decoded = jsonDecode(currentRec['additional_details'] as String);
            if (decoded is Map) dbDetails = Map<String, dynamic>.from(decoded);
          } catch (_) {}
        }
      }'''

new_ensure = r'''  Future<void> _ensureRealOtpExists() async {
    try {
      final bookingId = _currentBookingId ?? widget.bookingId;
      if (bookingId == null || bookingId.startsWith('mock')) return;

      final String strId = bookingId.toString();
      final dynamic numId = int.tryParse(strId);
      Map<String, dynamic> dbDetails = {};

      var currentRec = await Supabase.instance.client
          .from('bookings')
          .select('additional_details')
          .eq('id', strId)
          .maybeSingle();

      if (currentRec == null && numId != null) {
        currentRec = await Supabase.instance.client
            .from('bookings')
            .select('additional_details')
            .eq('id', numId)
            .maybeSingle();
      }

      if (currentRec != null && currentRec['additional_details'] != null) {
        if (currentRec['additional_details'] is Map) {
          dbDetails = Map<String, dynamic>.from(currentRec['additional_details'] as Map);
        } else if (currentRec['additional_details'] is String) {
          try {
            final decoded = jsonDecode(currentRec['additional_details'] as String);
            if (decoded is Map) dbDetails = Map<String, dynamic>.from(decoded);
          } catch (_) {}
        }
      }'''

content = content.replace(old_ensure, new_ensure)

# Replace update part in _ensureRealOtpExists
old_update = r'''      if (needsUpdate || dbDetails['otp'] == null || dbDetails['security_pin'] == null) {
        await Supabase.instance.client
            .from('bookings')
            .update({'additional_details': updatedDetails})
            .eq('id', queryId);
        debugPrint("? Saved FRESH Start PIN $startOtp & Completion PIN $compOtp for booking $bookingId to Supabase");
      }'''

new_update = r'''      if (needsUpdate || dbDetails['otp'] == null || dbDetails['security_pin'] == null) {
        try {
          await Supabase.instance.client
              .from('bookings')
              .update({'additional_details': updatedDetails})
              .eq('id', strId);
        } catch (_) {}
        if (numId != null) {
          try {
            await Supabase.instance.client
                .from('bookings')
                .update({'additional_details': updatedDetails})
                .eq('id', numId);
          } catch (_) {}
        }
        debugPrint("? Saved FRESH Start PIN $startOtp & Completion PIN $compOtp for booking $bookingId to Supabase");
      }'''

content = content.replace(old_update, new_update)

with open('c:/temenin_ajaa/temenin_ajaa/lib/modules/clients/booking/screens/tracking_driver_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
