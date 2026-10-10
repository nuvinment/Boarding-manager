class UtilityDateHelper {
  /// Format a DateTime as DD/MM/YYYY (e.g. 15/08/2026)
  static String formatDisplayDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}';
  }

  /// Parse DD/MM/YYYY into a DateTime if valid
  static DateTime? parseDisplayDate(String dateStr) {
    try {
      final parts = dateStr.trim().split('/');
      if (parts.length != 3) return null;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// Electricity default pattern: 01/MM/YYYY to lastDay/MM/YYYY
  /// e.g. for '2026-09' -> 01/09/2026 to 30/09/2026
  static Map<String, String> defaultElectricityPeriod(String monthStr) {
    try {
      final parts = monthStr.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0); // Last day of month
      return {
        'start': formatDisplayDate(start),
        'end': formatDisplayDate(end),
      };
    } catch (_) {
      return {'start': '01/09/2026', 'end': '30/09/2026'};
    }
  }

  /// Water default pattern: 15/(MM-1)/YYYY to 15/MM/YYYY
  /// e.g. for '2026-09' -> 15/08/2026 to 15/09/2026
  static Map<String, String> defaultWaterPeriod(String monthStr) {
    try {
      final parts = monthStr.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final prevYear = (month == 1) ? year - 1 : year;
      final prevMonth = (month == 1) ? 12 : month - 1;
      final start = DateTime(prevYear, prevMonth, 15);
      final end = DateTime(year, month, 15);
      return {
        'start': formatDisplayDate(start),
        'end': formatDisplayDate(end),
      };
    } catch (_) {
      return {'start': '15/08/2026', 'end': '15/09/2026'};
    }
  }

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// Current month as YYYY-MM (e.g. 2026-10)
  static String currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Month list from Aug 2026 up to 12 months ahead of today, as YYYY-MM keys.
  static List<String> monthOptions() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month + 12, 1);
    final result = <String>[];
    var d = DateTime(2026, 8, 1);
    while (!d.isAfter(end)) {
      result.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
      d = DateTime(d.year, d.month + 1, 1);
    }
    return result;
  }

  /// '2026-10' -> 'October 2026'
  static String monthLabel(String key) {
    try {
      final parts = key.split('-');
      return '${_monthNames[int.parse(parts[1]) - 1]} ${parts[0]}';
    } catch (_) {
      return key;
    }
  }
}
