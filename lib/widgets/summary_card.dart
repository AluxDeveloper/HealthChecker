import 'package:cupertino_ui/cupertino_ui.dart';

import '../models/task.dart';
import '../theme/format.dart';
import '../theme/health.dart';
import 'heartbeat.dart';

/// Cardul „Azi”: inel de progres cu inima care bate în centru,
/// câte sarcini de azi sunt gata și care urmează.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.today, required this.next});

  /// Toate sarcinile programate azi (finalizate sau nu).
  final List<Task> today;

  /// Următoarea sarcină nefinalizată din viitor, dacă există.
  final Task? next;

  static String _when(DateTime d) => RoFormat.day(d) == 'Azi'
      ? RoFormat.time(d)
      : RoFormat.dateTime(d).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final done = today.where((t) => t.done).length;
    final total = today.length;
    final progress = total == 0 ? 0.0 : done / total;

    final String headline;
    if (total == 0) {
      headline = 'Nimic programat azi';
    } else if (done == total) {
      headline = 'Totul e gata azi!';
    } else {
      headline = '$done din $total finalizate';
    }

    const white = CupertinoColors.white;
    final soft = white.withValues(alpha: 0.85);

    return Container(
      decoration: BoxDecoration(
        gradient: HealthColors.navyGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: HealthColors.navy.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CustomPaint(
                painter: ProgressRingPainter(
                  progress: value,
                  color: const Color(0xFFE5484D),
                ),
                child: const Center(child: BeatingHeart(size: 30)),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AZI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: soft,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: white,
                  ),
                ),
                const SizedBox(height: 8),
                if (next != null)
                  Row(
                    children: [
                      CategoryIcon(next!.category, size: 14, color: soft),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Urmează: ${next!.title} · ${_when(next!.dueAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, color: soft),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Adaugă un obicei sănătos.',
                    style: TextStyle(fontSize: 15, color: soft),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
