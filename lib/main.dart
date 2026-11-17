import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'config/supabase_config.dart';

import 'screens/splash_screen.dart';
import 'screens/tasks_screen.dart';
import 'services/notification_service.dart';
import 'services/supabase_task_remote.dart';
import 'services/task_store.dart';
import 'theme/health.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Citește doar sesiunea salvată pe dispozitiv; nu așteaptă internetul.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // Interfața apare imediat; cererea de permisiune pentru notificări
  // (care așteaptă răspunsul utilizatorului) vine abia după.
  final store = TaskStore(remote: SupabaseTaskRemote());
  runApp(SarciniApp(store: store));
  await NotificationService.instance.init();
  await store.load();
}

class SarciniApp extends StatelessWidget {
  const SarciniApp({super.key, required this.store, this.showSplash = true});

  final TaskStore store;

  /// Animația de intrare cu inima care bate (dezactivată în teste).
  final bool showSplash;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Tasks',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: const CupertinoThemeData(primaryColor: HealthColors.crimson),
      home: showSplash
          ? SplashScreen(next: (_) => TasksScreen(store: store))
          : TasksScreen(store: store),
    );
  }
}
