import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarcini/main.dart';
import 'package:sarcini/models/task.dart';
import 'package:sarcini/services/task_remote.dart';
import 'package:sarcini/services/task_store.dart';
import 'package:sarcini/theme/format.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_test.dart' show FakeNotifier, loadFonts;

/// Bază de date în memorie, cu aceeași regulă ca `ON CONFLICT ... WHERE`.
class FakeRemote implements TaskRemote {
  final Map<int, Task> rows = {};
  bool down = false;

  @override
  Future<List<Task>> fetchAll() async {
    if (down) throw StateError('offline');
    rows.removeWhere((_, t) => t.isExpired());
    return rows.values.toList();
  }

  @override
  Future<void> upsertAll(Iterable<Task> tasks) async {
    if (down) throw StateError('offline');
    for (final t in tasks) {
      final old = rows[t.id];
      if (old == null || old.updatedAt.isBefore(t.updatedAt)) rows[t.id] = t;
    }
  }

  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(loadFonts);

  final now = DateTime.now();
  Task task(int id, {required Duration due, Duration? deletedAgo}) => Task(
    id: id,
    title: 'Sarcina $id',
    dueAt: now.add(due),
    createdAt: now.subtract(const Duration(days: 10)),
    deletedAt: deletedAgo == null ? null : now.subtract(deletedAgo),
  );

  void seed(List<Task> tasks) => SharedPreferences.setMockInitialValues({
    'tasks_v1': jsonEncode(tasks.map((t) => t.toJson()).toList()),
  });

  test('sarcinile dispar la 3 zile după ștergere sau după ora lor', () async {
    seed([
      task(1, due: const Duration(days: 5)), // activă
      task(
        2,
        due: const Duration(days: 5),
        deletedAgo: const Duration(days: 2),
      ),
      task(
        3,
        due: const Duration(days: 5),
        deletedAgo: const Duration(hours: 73),
      ),
      task(4, due: -const Duration(days: 2)), // ora a trecut acum 2 zile
      task(5, due: -const Duration(hours: 73)), // ora a trecut acum >3 zile
      // ștearsă ieri, dar ora i-a trecut acum 4 zile: contează prima
      task(
        6,
        due: -const Duration(days: 4),
        deletedAgo: const Duration(days: 1),
      ),
    ]);
    final store = TaskStore(notifier: FakeNotifier());
    await store.load();

    expect(store.pending.map((t) => t.id), [4, 1]);
    expect(store.history.map((t) => t.id), unorderedEquals([2, 4]));

    // ce s-a șters a fost scos și din memoria telefonului
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('tasks_v1')!) as List;
    expect(saved.map((j) => j['id']), unorderedEquals([1, 2, 4]));
  });

  test('ștergerea mută în istoric, restaurarea o readuce', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = FakeNotifier();
    final store = TaskStore(notifier: notifier);
    await store.load();
    await store.add(task(1, due: const Duration(hours: 2)));
    expect(notifier.scheduled.containsKey(1), isTrue);

    await store.remove(store.pending.single);
    expect(store.pending, isEmpty);
    expect(store.history.single.isDeleted, isTrue);
    expect(notifier.scheduled.containsKey(1), isFalse);

    await store.restore(store.history.single);
    expect(store.pending.single.id, 1);
    expect(store.history, isEmpty);
    expect(notifier.scheduled.containsKey(1), isTrue);
  });

  test('sincronizarea combină telefonul cu baza de date', () async {
    final remote = FakeRemote();
    final older = now.subtract(const Duration(hours: 1));
    // în bază: o sarcină pe care telefonul nu o are și una mai veche
    remote.rows[10] = Task(
      id: 10,
      title: 'Doar în bază',
      dueAt: now.add(const Duration(days: 1)),
    );
    remote.rows[11] = Task(
      id: 11,
      title: 'Titlu vechi',
      dueAt: now.add(const Duration(days: 1)),
      updatedAt: older,
    );
    seed([
      Task(id: 11, title: 'Titlu nou', dueAt: now.add(const Duration(days: 1))),
      Task(
        id: 12,
        title: 'Doar pe telefon',
        dueAt: now.add(const Duration(days: 1)),
      ),
    ]);

    final store = TaskStore(notifier: FakeNotifier(), remote: remote);
    await store.load();

    expect(store.syncStatus, SyncStatus.online);
    expect(
      store.pending.map((t) => t.title),
      unorderedEquals(['Doar în bază', 'Titlu nou', 'Doar pe telefon']),
    );
    expect(remote.rows.keys, unorderedEquals([10, 11, 12]));
    expect(remote.rows[11]!.title, 'Titlu nou');

    // ștergerea ajunge și în bază (ca ștergere, pentru istoric)
    await store.remove(store.pending.firstWhere((t) => t.id == 12));
    await store.sync();
    expect(remote.rows[12]!.isDeleted, isTrue);
  });

  test('fără bază de date, aplicația merge mai departe', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = FakeRemote()..down = true;
    final store = TaskStore(notifier: FakeNotifier(), remote: remote);
    await store.load();
    await store.add(task(1, due: const Duration(hours: 1)));
    await store.sync();
    expect(store.syncStatus, SyncStatus.offline);
    expect(store.pending, hasLength(1));

    remote.down = false; // revine legătura
    await store.refresh();
    expect(store.syncStatus, SyncStatus.online);
    expect(remote.rows.keys, [1]);
  });

  test('duratele se scriu corect în română', () {
    expect(RoFormat.duration(const Duration(hours: 72)), '3 zile');
    expect(
      RoFormat.duration(const Duration(days: 2, hours: 1)),
      '2 zile și 1 oră',
    );
    expect(
      RoFormat.duration(const Duration(hours: 21, minutes: 5)),
      '21 de ore și 5 minute',
    );
    expect(RoFormat.duration(const Duration(minutes: 1)), '1 minut');
    expect(
      RoFormat.duration(const Duration(seconds: 20)),
      'mai puțin de un minut',
    );
  });

  testWidgets('butonul de istoric arată sarcinile șterse și le restaurează', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    seed([
      Task(
        id: 1,
        title: 'Vitamina D',
        category: TaskCategory.medication,
        dueAt: now.add(const Duration(hours: 3)),
      ),
    ]);
    final store = TaskStore(notifier: FakeNotifier());
    await tester.pumpWidget(SarciniApp(store: store, showSplash: false));
    await tester.runAsync(store.load);
    await tester.pumpAndSettle();

    await tester.runAsync(() => store.remove(store.pending.single));
    await tester.pumpAndSettle();
    expect(find.text('Vitamina D'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Istoric'));
    await tester.pumpAndSettle();
    expect(find.text('Vitamina D'), findsOneWidget);
    expect(find.text('Ștearsă'), findsOneWidget);
    expect(find.textContaining('Dispare în'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Restaurează'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('Istoricul e gol'), findsOneWidget);

    await tester.tap(find.text('Sarcini'));
    await tester.pumpAndSettle();
    expect(find.text('Vitamina D'), findsOneWidget);
  });
}
