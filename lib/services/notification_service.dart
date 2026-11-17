import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';
import '../theme/health.dart';

/// Contractul folosit de [TaskStore]; permite înlocuirea în teste.
abstract interface class TaskNotifier {
  Future<void> schedule(Task task);
  Future<void> cancel(int id);
  Future<void> resync(Iterable<Task> tasks);
}

/// Programează și anulează notificările locale pentru sarcini.
class NotificationService implements TaskNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'task_reminders';
  static const _channelName = 'Mementouri sarcini';

  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Dacă fusul orar nu poate fi determinat, rămâne UTC.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    if (Platform.isAndroid) {
      await _android?.requestNotificationsPermission();
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> schedule(Task task) async {
    await cancel(task.id);
    if (!task.needsNotification) return;

    var mode = AndroidScheduleMode.exactAllowWhileIdle;
    if (Platform.isAndroid &&
        (await _android?.canScheduleExactNotifications()) == false) {
      mode = AndroidScheduleMode.inexactAllowWhileIdle;
    }

    await _plugin.zonedSchedule(
      id: task.id,
      title: task.title,
      body: task.notes.isEmpty ? task.category.reminderBody : task.notes,
      scheduledDate: tz.TZDateTime.from(task.dueAt, tz.local),
      androidScheduleMode: mode,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Notificări la ora stabilită pentru sarcini',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  /// Reface toate programările (ex. la pornirea aplicației).
  @override
  Future<void> resync(Iterable<Task> tasks) async {
    await _plugin.cancelAll();
    for (final task in tasks) {
      await schedule(task);
    }
  }
}
