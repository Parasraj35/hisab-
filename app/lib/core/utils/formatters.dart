import 'package:intl/intl.dart';

class Fmt {
  Fmt._();

  static final _money = NumberFormat('#,##0.00', 'en_US');
  static final _compact = NumberFormat('#,##0', 'en_US');

  /// "PKR 120,000.00"
  static String currency(num value,
          {String code = 'PKR', bool decimals = true}) =>
      '$code ${decimals ? _money.format(value) : _compact.format(value)}';

  /// "+50,000.00" / "-2,500.00"
  static String signed(num value, {bool decimals = true}) {
    final sign = value < 0 ? '-' : '+';
    final abs = value.abs();
    return '$sign${decimals ? _money.format(abs) : _compact.format(abs)}';
  }

  static String plain(num value) => _money.format(value);

  static String date(DateTime d, {String pattern = 'MMM dd, yyyy'}) =>
      DateFormat(pattern).format(d);

  static String time(DateTime d) => DateFormat('hh:mm a').format(d);

  static String dayHeader(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM dd, yyyy').format(d);
  }

  static String initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static String countdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
