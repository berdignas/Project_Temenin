
/// Helper to parse Indonesian dates and times into DateTime and format countdowns.
class BookingDateHelper {
  static const Map<String, int> indonesianMonths = {
    'jan': 1, 'januari': 1, 'january': 1,
    'feb': 2, 'februari': 2, 'february': 2,
    'mar': 3, 'maret': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'mei': 5, 'may': 5,
    'jun': 6, 'juni': 6, 'june': 6,
    'jul': 7, 'juli': 7, 'july': 7,
    'agu': 8, 'ags': 8, 'agustus': 8, 'aug': 8, 'august': 8,
    'sep': 9, 'september': 9,
    'okt': 10, 'oktober': 10, 'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'des': 12, 'desember': 12, 'dec': 12, 'december': 12,
  };

  /// Parses human Indonesian date and time strings into a [DateTime].
  static DateTime? parseIndonesianDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final now = DateTime.now();
    int year = now.year;
    int month = now.month;
    int day = now.day;
    int hour = 8;
    int minute = 0;

    // Time parsing
    if (timeStr != null && timeStr.trim().isNotEmpty) {
      final tLower = timeStr.toLowerCase();
      if (tLower.contains('sekarang') || tLower.contains('otw')) {
        return now.add(const Duration(minutes: 5));
      }
      final timeMatch = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(timeStr);
      if (timeMatch != null) {
        hour = int.tryParse(timeMatch.group(1)!) ?? hour;
        minute = int.tryParse(timeMatch.group(2)!) ?? minute;
        if (tLower.contains('pm') && hour < 12) hour += 12;
        if (tLower.contains('am') && hour == 12) hour = 0;
      }
    }

    final cleanDate = dateStr.trim();
    // Direct ISO check
    final directIso = DateTime.tryParse(cleanDate);
    if (directIso != null) {
      if (timeStr != null && timeStr.trim().isNotEmpty && !timeStr.toLowerCase().contains('sekarang')) {
        return DateTime(directIso.year, directIso.month, directIso.day, hour, minute);
      }
      return directIso;
    }

    // Slash/dash format: DD/MM/YYYY or DD-MM-YYYY
    final slashMatch = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})').firstMatch(cleanDate);
    if (slashMatch != null) {
      day = int.tryParse(slashMatch.group(1)!) ?? day;
      month = int.tryParse(slashMatch.group(2)!) ?? month;
      int y = int.tryParse(slashMatch.group(3)!) ?? year;
      if (y < 100) y += 2000;
      return DateTime(y, month, day, hour, minute);
    }

    // Strip leading day names, e.g. "Selasa, ", "Hari ini, "
    final cleanWithoutDay = cleanDate.replaceAll(RegExp(r'^[a-zA-Z\s]+,\s*'), '');
    final words = cleanWithoutDay.split(RegExp(r'[\s,-]+')).where((w) => w.isNotEmpty).toList();

    for (int i = 0; i < words.length; i++) {
      final w = words[i].toLowerCase();
      if (indonesianMonths.containsKey(w)) {
        month = indonesianMonths[w]!;
        if (i > 0) {
          day = int.tryParse(words[i - 1]) ?? day;
        }
        if (i < words.length - 1) {
          final possibleYear = int.tryParse(words[i + 1]);
          if (possibleYear != null) {
            year = possibleYear < 100 ? possibleYear + 2000 : possibleYear;
          }
        }
        break;
      }
    }

    return DateTime(year, month, day, hour, minute);
  }

  /// Extracts scheduled DateTime from a booking map or details structure.
  static DateTime? extractScheduledDateTime(dynamic data) {
    if (data == null) return null;

    Map<String, dynamic>? map;
    if (data is Map<String, dynamic>) {
      map = data;
    } else if (data is Map) {
      map = Map<String, dynamic>.from(data);
    }

    final add = map?['additional_details'] is Map
        ? map!['additional_details'] as Map
        : (map?['additionalDetails'] is Map ? map!['additionalDetails'] as Map : null);

    // 1. Try human date and time strings
    String? rawDate = map?['date']?.toString() ??
                      map?['pickupDate']?.toString() ??
                      map?['selectedDate']?.toString() ??
                      add?['date']?.toString() ??
                      add?['pickupDate']?.toString() ??
                      add?['selectedDate']?.toString();

    String? rawTime = map?['time']?.toString() ??
                      map?['pickupTime']?.toString() ??
                      map?['selectedTime']?.toString() ??
                      add?['time']?.toString() ??
                      add?['pickupTime']?.toString() ??
                      add?['selectedTime']?.toString();

    if (rawDate != null && rawDate.trim().isNotEmpty) {
      final parsed = parseIndonesianDateTime(rawDate, rawTime);
      if (parsed != null) return parsed;
    }

    // 2. Try bookingDate / booking_date
    final rawBookingDate = map?['bookingDate'] ??
                           map?['booking_date'] ??
                           add?['bookingDate'] ??
                           add?['booking_date'];

    if (rawBookingDate != null) {
      if (rawBookingDate is DateTime) return rawBookingDate;
      final dt = DateTime.tryParse(rawBookingDate.toString());
      if (dt != null) return dt;
    }

    return null;
  }

  /// Formats remaining seconds into readable countdown string.
  /// Supports days + hours + minutes + seconds (e.g. "1 Hari 13 Jam 45 Mnt 30 Dtk").
  static String formatCountdownTime(int totalSeconds) {
    if (totalSeconds <= 0) return "00:00:00";
    final int days = totalSeconds ~/ 86400;
    final int hours = (totalSeconds % 86400) ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    if (days > 0) {
      return "$days Hari $hours Jam $minutes Mnt $seconds Dtk";
    }
    if (hours > 0) {
      return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  /// Returns user-friendly schedule string, e.g. "15 Sep 2026, 08:00 WIB".
  static String getScheduleDisplay(dynamic data) {
    if (data == null) return "-";
    Map<String, dynamic>? map;
    if (data is Map<String, dynamic>) {
      map = data;
    } else if (data is Map) {
      map = Map<String, dynamic>.from(data);
    }
    final add = map?['additional_details'] is Map
        ? map!['additional_details'] as Map
        : (map?['additionalDetails'] is Map ? map!['additionalDetails'] as Map : null);

    final d = map?['date'] ?? add?['date'] ?? map?['selectedDate'] ?? add?['selectedDate'];
    final t = map?['time'] ?? add?['time'] ?? map?['selectedTime'] ?? add?['selectedTime'];
    if (d != null && t != null) {
      return "$d, $t";
    }
    if (d != null) return "$d";

    final dt = extractScheduledDateTime(data);
    if (dt != null) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      final datePart = "${dt.day} ${months[dt.month - 1]} ${dt.year}";
      final timePart = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB";
      return "$datePart, $timePart";
    }

    return "-";
  }
}
