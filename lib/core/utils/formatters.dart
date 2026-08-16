/// Human-readable formatting for trip figures shown across the dashboard.
abstract final class Format {
  static String distance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  static String duration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) {
      final rest = seconds % 60;
      return rest == 0 ? '${minutes}m' : '${minutes}m ${rest}s';
    }
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  static String tripStamp(DateTime date) {
    final now = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;

    final time =
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';

    if (diff == 0) return 'Today · $time';
    if (diff == 1) return 'Yesterday · $time';
    return '${_months[date.month - 1]} ${date.day} · $time';
  }

  static String monthYear(DateTime date) =>
      '${_months[date.month - 1]} ${date.year}';

  /// Weekday initials for the last 7 days, oldest first.
  static List<String> lastSevenDayLabels() {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return _weekdays[day.weekday - 1];
    });
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
}
