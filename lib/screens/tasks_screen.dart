import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../services/task_store.dart';
import '../theme/health.dart';
import '../widgets/heartbeat.dart';
import '../widgets/summary_card.dart';
import '../widgets/task_tile.dart';
import 'history_screen.dart';
import 'task_editor_sheet.dart';

/// Singurul ecran al aplicației: rezumatul zilei, lista de sarcini și adăugarea.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.store});

  final TaskStore store;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _showCompleted = true;
  late final Timer _ticker;
  late final AppLifecycleListener _lifecycle;

  TaskStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    // Scoate sarcinile expirate (3 zile) și sincronizează cu baza de date.
    _ticker = Timer.periodic(
      const Duration(minutes: 1),
      (_) => store.refresh(),
    );
    _lifecycle = AppLifecycleListener(onResume: store.refresh);
  }

  @override
  void dispose() {
    _ticker.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _openHistory() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => HistoryScreen(store: store)),
    );
  }

  Future<void> _openEditor([Task? task]) async {
    final result = await showTaskEditor(context, task: task);
    switch (result) {
      case EditorSaved(task: final saved):
        task == null ? await store.add(saved) : await store.update(saved);
      case EditorDeleted():
        if (task == null) return;
        HapticFeedback.mediumImpact();
        await store.remove(task);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: bg,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final pending = store.pending;
          final completed = store.completed;
          final empty = pending.isEmpty && completed.isEmpty;

          final now = DateTime.now();
          bool isToday(Task t) =>
              t.dueAt.year == now.year &&
              t.dueAt.month == now.month &&
              t.dueAt.day == now.day;
          final today = [...pending, ...completed].where(isToday).toList();
          final upcoming = pending.where((t) => t.dueAt.isAfter(now));
          final next = upcoming.isEmpty ? null : upcoming.first;

          var index = 0; // pentru apariția decalată a cardurilor

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  CupertinoSliverNavigationBar(
                    largeTitle: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Sarcini'),
                        SizedBox(width: 10),
                        BeatingHeart(size: 26),
                      ],
                    ),
                    middle: const Text('Sarcini'),
                    alwaysShowMiddle: false,
                    backgroundColor: bg.withValues(alpha: 0.85),
                    border: null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (completed.isNotEmpty)
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => setState(
                              () => _showCompleted = !_showCompleted,
                            ),
                            child: Text(
                              _showCompleted
                                  ? 'Ascunde finalizate'
                                  : 'Arată finalizate',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        _HistoryButton(onPressed: _openHistory),
                      ],
                    ),
                  ),
                  if (!store.loaded)
                    const SliverFillRemaining(
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      sliver: SliverToBoxAdapter(
                        child: FadeSlideIn(
                          index: index++,
                          child: SummaryCard(today: today, next: next),
                        ),
                      ),
                    ),
                    if (empty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      )
                    else ...[
                      if (pending.isNotEmpty) ...[
                        _header(context, 'De făcut', pending.length),
                        _cards(pending, () => index++),
                      ] else
                        const SliverToBoxAdapter(child: _AllDone()),
                      if (completed.isNotEmpty && _showCompleted) ...[
                        _header(context, 'Finalizate', completed.length),
                        _cards(completed, () => index++),
                      ],
                    ],
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomBar(onAdd: () => _openEditor()),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, String title, int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.35,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const Spacer(),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 17,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cards(List<Task> tasks, int Function() nextIndex) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.list(
        children: [
          for (final task in tasks)
            FadeSlideIn(
              key: ValueKey(task.id),
              index: nextIndex(),
              child: TaskTile(
                task: task,
                onTap: () => _openEditor(task),
                onToggle: () => store.toggleDone(task),
                onDelete: () {
                  HapticFeedback.mediumImpact();
                  store.remove(task);
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Butonul mic cu ceas care deschide istoricul.
class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Istoric',
      button: true,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: const EdgeInsets.only(left: 12),
        minimumSize: const Size(34, 34),
        onPressed: onPressed,
        child: const Icon(CupertinoIcons.clock, size: 22),
      ),
    );
  }
}

/// Bară inferioară translucidă, cu butonul „Sarcină nouă”.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.8),
            border: Border(
              top: BorderSide(
                color: CupertinoColors.separator.resolveFrom(context),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onAdd();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.plus_circle_fill,
                        size: 26,
                        color: accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sarcină nouă',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final pink = HealthColors.crimson.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 24, 40, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pink.withValues(alpha: 0.12),
            ),
            child: const Center(child: BeatingHeart(size: 46)),
          ),
          const SizedBox(height: 20),
          Text(
            'Nicio sarcină',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.35,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adaugă un medicament, un pahar cu apă sau o plimbare. '
            'Îți trimitem o notificare exact la ora aleasă.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.35, color: secondary),
          ),
        ],
      ),
    );
  }
}

class _AllDone extends StatelessWidget {
  const _AllDone();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.checkmark_seal_fill,
            size: 20,
            color: HealthColors.medicalBlue.resolveFrom(context),
          ),
          const SizedBox(width: 6),
          Text(
            'Totul este făcut. Bravo!',
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
