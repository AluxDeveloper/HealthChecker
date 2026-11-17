/// Formatare de dată/oră în română, în stilul iOS.
abstract final class RoFormat {
  static const _days = ['Lun', 'Mar', 'Mie', 'Joi', 'Vin', 'Sâm', 'Dum'];
  static const _months = [
    'ian.',
    'feb.',
    'mar.',
    'apr.',
    'mai',
    'iun.',
    'iul.',
    'aug.',
    'sept.',
    'oct.',
    'nov.',
    'dec.',
  ];

  static String time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String day(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return 'Azi';
    if (diff == 1) return 'Mâine';
    if (diff == -1) return 'Ieri';
    final base = '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
    return d.year == now.year ? base : '$base ${d.year}';
  }

  static String dateTime(DateTime d) => '${day(d)}, ${time(d)}';

  /// „1 zi”, „5 zile”, „20 de zile” (cu „de” de la 20 în sus).
  static String count(int n, String one, String many) {
    if (n == 1) return '1 $one';
    final r = n % 100;
    return (r == 0 && n != 0) || r >= 20 ? '$n de $many' : '$n $many';
  }

  /// Durată scurtă, cu cel mult două unități: „2 zile și 4 ore”.
  static String duration(Duration d) {
    if (d.inMinutes < 1) return 'mai puțin de un minut';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    String join(String a, int n, String b) => n == 0 ? a : '$a și $b';
    if (days > 0) {
      return join(count(days, 'zi', 'zile'), hours, count(hours, 'oră', 'ore'));
    }
    if (d.inHours > 0) {
      return join(
        count(hours, 'oră', 'ore'),
        minutes,
        count(minutes, 'minut', 'minute'),
      );
    }
    return count(minutes, 'minut', 'minute');
  }
}
