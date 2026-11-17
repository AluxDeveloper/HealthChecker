import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../services/task_store.dart';
import '../theme/format.dart';
import '../theme/health.dart';

/// Istoricul: sarcinile șterse și cele a căror oră a trecut. Fiecare dispare
/// definitiv (și din baza de date) la 3 zile după ștergere sau după ora ei.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: bg,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Istoric'),
        previousPageTitle: 'Sarcini',
        backgroundColor: bg.withValues(alpha: 0.85),
        border: null,
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final items = store.history;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                  child: Text(
                    'Sarcinile șterse sau a căror oră a trecut rămân aici '
                    '${RoFormat.duration(Task.retention)}, apoi dispar '
                    'definitiv, și din aplicație, și din baza de date.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: secondary,
                    ),
                  ),
                ),
                if (items.isEmpty)
                  const _Empty()
                else
                  for (final task in items)
                    _HistoryTile(
                      key: ValueKey(task.id),
                      task: task,
                      onRestore: task.isDeleted
                          ? () {
                              HapticFeedback.lightImpact();
                              store.restore(task);
                            }
                          : null,
                    ),
                const SizedBox(height: 8),
                _SyncFooter(store: store),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({super.key, required this.task, this.onRestore});

  final Task task;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final cat = task.category;
    final catColor = cat.color.resolveFrom(context);
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final red = CupertinoColors.systemRed.resolveFrom(context);
    final blue = HealthColors.medicalBlue.resolveFrom(context);

    final (String status, Color statusColor) = task.isDeleted
        ? ('Ștearsă', red)
        : task.done
        ? ('Finalizată', blue)
        : ('Ora a trecut', secondary);

    final left = task.expiresAt.difference(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 13, 14, 12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: label,
            ),
          ),
          if (task.notes.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              task.notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: secondary),
            ),
          ],
          const SizedBox(height: 8),
          _line(
            context,
            CupertinoIcons.calendar,
            'Programată: ${RoFormat.dateTime(task.dueAt)}',
          ),
          if (task.deletedAt case final deleted?)
            _line(
              context,
              CupertinoIcons.trash,
              'Ștearsă: ${RoFormat.dateTime(deleted)}',
            ),
          Row(
            children: [
              Expanded(
                child: _line(
                  context,
                  CupertinoIcons.timer,
                  'Dispare în ${RoFormat.duration(left)}',
                ),
              ),
              if (onRestore != null)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 30),
                  onPressed: onRestore,
                  child: const Text(
                    'Restaurează',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, String text) {
    final color = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, style: TextStyle(fontSize: 14, color: color)),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(CupertinoIcons.clock, size: 44, color: secondary),
          const SizedBox(height: 12),
          Text(
            'Istoricul e gol',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Starea legăturii cu Supabase, ca să vezi că datele ajung în cloud.
class _SyncFooter extends StatelessWidget {
  const _SyncFooter({required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final last = store.lastSync;

    final (
      IconData? icon,
      Color color,
      String text,
    ) = switch (store.syncStatus) {
      SyncStatus.disabled => (null, secondary, ''),
      SyncStatus.syncing => (
        CupertinoIcons.arrow_2_circlepath,
        secondary,
        'Se sincronizează cu baza de date…',
      ),
      SyncStatus.online => (
        CupertinoIcons.checkmark_circle_fill,
        CupertinoColors.systemGreen.resolveFrom(context),
        'Salvat în cloud (Supabase)'
            '${last == null ? '' : ' · ${RoFormat.time(last)}'}',
      ),
      SyncStatus.offline => (
        CupertinoIcons.exclamationmark_triangle_fill,
        CupertinoColors.systemOrange.resolveFrom(context),
        'Fără legătură cu serverul. Datele se salvează pe telefon și '
            'se trimit când revine legătura.',
      ),
    };
    if (icon == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, height: 1.3, color: secondary),
            ),
          ),
        ],
      ),
    );
  }
}
