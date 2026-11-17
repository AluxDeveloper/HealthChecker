import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarcini/main.dart';
import 'package:sarcini/models/task.dart';
import 'package:sarcini/services/notification_service.dart';
import 'package:sarcini/services/task_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Înregistrează programările în loc să le trimită sistemului.
class FakeNotifier implements TaskNotifier {
  final Map<int, DateTime> scheduled = {};

  @override
  Future<void> schedule(Task task) async {
    scheduled.remove(task.id);
    if (task.needsNotification) scheduled[task.id] = task.dueAt;
  }

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);

  @override
  Future<void> resync(Iterable<Task> tasks) async {
    scheduled.clear();
    for (final t in tasks) {
      await schedule(t);
    }
  }
}

Future<void> loadFonts() async {
  Future<void> load(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
  }

  const sf = '/System/Library/Fonts/SFNS.ttf';
  await load('CupertinoSystemText', sf);
  await load('CupertinoSystemDisplay', sf);
  final home = Platform.environment['HOME'];
  await load(
    'packages/cupertino_icons/CupertinoIcons',
    '$home/.pub-cache/hosted/pub.dev/cupertino_icons-1.0.9/assets/CupertinoIcons.ttf',
  );
}

void main() {
  late FakeNotifier notifier;
  late TaskStore store;

  setUpAll(loadFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    notifier = FakeNotifier();
    store = TaskStore(notifier: notifier);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556); // iPhone 15/16
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // ca setarea iOS „Reduce mișcarea”: fără animații continue
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(SarciniApp(store: store, showSplash: false));
    await tester.runAsync(store.load);
    await tester.pumpAndSettle();
  }

  testWidgets('adaugă, modifică, finalizează și șterge o sarcină', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('No tasks'), findsOneWidget);

    // Adăugare
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(CupertinoTextField).first,
      'Sună la medic',
    );
    await tester.pump();
    await tester.tap(find.text('In 1 hour'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Add'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.text('Sună la medic'), findsOneWidget);
    expect(store.pending, hasLength(1));
    final id = store.pending.single.id;
    expect(notifier.scheduled.containsKey(id), isTrue);

    // Modificare
    await tester.tap(find.text('Sună la medic'));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
    await tester.enterText(
      find.byType(CupertinoTextField).first,
      'Sună la dentist',
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Done'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('Sună la dentist'), findsOneWidget);
    expect(store.pending.single.title, 'Sună la dentist');

    // Dezactivare notificare
    await tester.tap(find.text('Sună la dentist'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Done'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(notifier.scheduled.containsKey(id), isFalse);

    // Ștergere prin glisare
    await tester.runAsync(() async {
      await tester.drag(find.text('Sună la dentist'), const Offset(-600, 0));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(store.pending, isEmpty);
    expect(find.text('No tasks'), findsOneWidget);
  });

  testWidgets('bifarea anulează notificarea, debifarea o reprogramează', (
    tester,
  ) async {
    await pumpApp(tester);
    final task = Task(
      id: 1,
      title: 'Plătește factura',
      dueAt: DateTime.now().add(const Duration(hours: 2)),
    );
    await tester.runAsync(() => store.add(task));
    await tester.pumpAndSettle();
    expect(notifier.scheduled.containsKey(1), isTrue);

    await tester.runAsync(() => store.toggleDone(store.pending.single));
    await tester.pumpAndSettle();
    expect(notifier.scheduled.containsKey(1), isFalse);
    expect(find.text('Completed'), findsOneWidget);

    await tester.runAsync(() => store.toggleDone(store.completed.single));
    expect(notifier.scheduled.containsKey(1), isTrue);
  });

  testWidgets('sarcinile persistă după repornire', (tester) async {
    await pumpApp(tester);
    await tester.runAsync(
      () => store.add(
        Task(
          id: 7,
          title: 'Cumpără lapte',
          dueAt: DateTime.now().add(const Duration(days: 1)),
        ),
      ),
    );
    final reloaded = TaskStore(notifier: FakeNotifier());
    await tester.runAsync(reloaded.load);
    expect(reloaded.pending.single.title, 'Cumpără lapte');
  });

  testWidgets('categoria aleasă se salvează', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medication'));
    await tester.pump();
    expect(find.text('e.g. Vitamin D, 1 capsule'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoTextField).first, 'Vitamina D');
    await tester.tap(find.text('In 1 hour'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Add'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(store.pending.single.category, TaskCategory.medication);
    expect(find.text('Medication'), findsOneWidget);
  });

  testWidgets('intro-ul cu inima duce la lista de sarcini', (tester) async {
    await tester.pumpWidget(SarciniApp(store: store));
    await tester.runAsync(store.load);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Take care of yourself, on time.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Take care of yourself, on time.'), findsNothing);
    expect(find.text('New task'), findsOneWidget);
    // oprește animațiile continue înainte de final
    await tester.pumpWidget(const SizedBox());
  });
}
