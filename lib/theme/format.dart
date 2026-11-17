/// Date/time formatting in English, iOS style ("Today at 14:30").
abstract final class AppFormat {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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

  static String time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static bool isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  static String day(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    final base = '${_days[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
    return d.year == now.year ? base : '$base, ${d.year}';
  }

  static String dateTime(DateTime d) => '${day(d)} at ${time(d)}';

  /// For the middle of a sentence: "today at 14:30", "on Mon, Nov 17 at 14:30".
  static String inSentence(DateTime d) {
    final dd = day(d);
    const relative = {'Today', 'Tomorrow', 'Yesterday'};
    return relative.contains(dd)
        ? '${dd.toLowerCase()} at ${time(d)}'
        : 'on ${dateTime(d)}';
  }

  /// "1 day", "5 days".
  static String count(int n, String one, String many) =>
      n == 1 ? '1 $one' : '$n $many';

  /// Short duration with at most two units: "2 days and 4 hours".
  static String duration(Duration d) {
    if (d.inMinutes < 1) return 'less than a minute';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    String join(String a, int n, String b) => n == 0 ? a : '$a and $b';
    if (days > 0) {
      return join(
        count(days, 'day', 'days'),
        hours,
        count(hours, 'hour', 'hours'),
      );
    }
    if (d.inHours > 0) {
      return join(
        count(hours, 'hour', 'hours'),
        minutes,
        count(minutes, 'minute', 'minutes'),
      );
    }
    return count(minutes, 'minute', 'minutes');
  }
}
