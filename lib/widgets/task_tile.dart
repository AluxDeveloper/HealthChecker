import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../theme/format.dart';
import '../theme/health.dart';

/// Card de sarcină în stilul aplicației Sănătate: eticheta colorată a
/// categoriei sus, ora în dreapta, titlul mare dedesubt.
class TaskTile extends StatefulWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final cat = task.category;
    final catColor = cat.color.resolveFrom(context);
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final timeColor = task.isOverdue
        ? CupertinoColors.systemRed.resolveFrom(context)
        : secondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Dismissible(
          key: ValueKey(task.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => widget.onDelete(),
          background: Container(
            color: CupertinoColors.systemRed.resolveFrom(context),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 26),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.trash_fill,
                  color: CupertinoColors.white,
                  size: 22,
                ),
                SizedBox(height: 3),
                Text(
                  'Șterge',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _pressed ? 0.98 : 1,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: task.done ? 0.65 : 1,
                child: Container(
                  color: CupertinoColors.secondarySystemGroupedBackground
                      .resolveFrom(context),
                  padding: const EdgeInsets.fromLTRB(16, 13, 14, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CategoryIcon(cat, size: 15, color: catColor),
                          const SizedBox(width: 6),
                          Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: catColor,
                            ),
                          ),
                          const Spacer(),
                          if (task.remind && !task.done) ...[
                            Icon(
                              CupertinoIcons.bell_fill,
                              size: 12,
                              color: timeColor,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            RoFormat.dateTime(task.dueAt),
                            style: TextStyle(fontSize: 14, color: timeColor),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 13,
                            color: CupertinoColors.tertiaryLabel.resolveFrom(
                              context,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CheckCircle(
                            checked: task.done,
                            color: catColor,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              widget.onToggle();
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: CupertinoTheme.of(context)
                                      .textTheme
                                      .textStyle
                                      .copyWith(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.3,
                                        color: task.done ? secondary : label,
                                        decoration: task.done
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                        decorationColor: secondary,
                                      ),
                                  child: Text(
                                    task.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (task.notes.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    task.notes,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: secondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cerc de bifat în culoarea categoriei; la bifare „bate” ca o inimă.
class _CheckCircle extends StatelessWidget {
  const _CheckCircle({
    required this.checked,
    required this.color,
    required this.onTap,
  });

  final bool checked;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 1),
        child: TweenAnimationBuilder<double>(
          key: ValueKey(checked),
          tween: Tween(begin: checked ? 0.6 : 1, end: 1),
          duration: const Duration(milliseconds: 380),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: checked ? color : color.withValues(alpha: 0.12),
              border: Border.all(color: color, width: 2),
            ),
            child: AnimatedScale(
              scale: checked ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: const Icon(
                CupertinoIcons.checkmark_alt,
                size: 17,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
