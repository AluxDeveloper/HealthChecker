import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import 'notification_service.dart';
import 'task_remote.dart';

/// Starea legăturii cu baza de date.
enum SyncStatus {
  /// Aplicația nu folosește bază de date (ex. în teste).
  disabled,
  syncing,
  online,
  offline,
}

/// Ține lista de sarcini, o salvează pe dispozitiv, o sincronizează cu baza
/// de date și programează notificările.
///
/// Sarcinile șterse nu dispar imediat: primesc `deletedAt` și stau în istoric.
/// Orice sarcină dispare definitiv (din aplicație și din baza de date) la
/// [Task.retention] după ștergere sau după ora programată.
class TaskStore extends ChangeNotifier {
  TaskStore({TaskNotifier? notifier, TaskRemote? remote})
    : _notifier = notifier ?? NotificationService.instance,
      _remote = remote,
      _syncStatus = remote == null ? SyncStatus.disabled : SyncStatus.syncing;

  static const _key = 'tasks_v1';
  final TaskNotifier _notifier;
  final TaskRemote? _remote;

  final List<Task> _tasks = [];
  bool _loaded = false;

  SyncStatus _syncStatus;
  String? _syncError;
  DateTime? _lastSync;
  bool _syncing = false;
  bool _syncAgain = false;

  bool get loaded => _loaded;
  SyncStatus get syncStatus => _syncStatus;
  String? get syncError => _syncError;
  DateTime? get lastSync => _lastSync;

  Iterable<Task> get _visible => _tasks.where((t) => !t.isDeleted);

  List<Task> get pending =>
      _visible.where((t) => !t.done).toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

  List<Task> get completed =>
      _visible.where((t) => t.done).toList()
        ..sort((a, b) => b.dueAt.compareTo(a.dueAt));

  /// Sarcinile șterse sau a căror oră a trecut, cele mai recente primele.
  List<Task> get history {
    DateTime when(Task t) => t.deletedAt ?? t.dueAt;
    return _tasks.where((t) => t.inHistory).toList()
      ..sort((a, b) => when(b).compareTo(when(a)));
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _tasks
          ..clear()
          ..addAll(list.map(Task.fromJson));
      } catch (_) {
        // Date corupte: pornim cu listă goală, fără să blocăm aplicația.
      }
    }
    _loaded = true;
    _purgeExpired();
    notifyListeners();
    await _notifier.resync(_tasks);
    await _save();
    await sync();
  }

  Future<void> add(Task task) async {
    _tasks.add(task);
    await _commit();
    await _notifier.schedule(task);
  }

  Future<void> update(Task task) async {
    final i = _tasks.indexWhere((t) => t.id == task.id);
    if (i == -1) return;
    _tasks[i] = task;
    await _commit();
    await _notifier.schedule(task);
  }

  Future<void> toggleDone(Task task) => update(task.copyWith(done: !task.done));

  /// Mută sarcina în istoric; dispare definitiv după [Task.retention].
  Future<void> remove(Task task) => update(task.withDeleted(true));

  /// Readuce în listă o sarcină ștearsă.
  Future<void> restore(Task task) => update(task.withDeleted(false));

  /// Scoate sarcinile expirate și sincronizează (apelat periodic și la
  /// revenirea în aplicație).
  Future<void> refresh() async {
    if (!_loaded) return;
    if (_purgeExpired()) {
      notifyListeners();
      await _save();
    } else {
      notifyListeners(); // actualizează textele „dispare în …”
    }
    await sync();
  }

  /// Aduce sarcinile din baza de date, le combină cu cele locale (câștigă
  /// versiunea modificată cel mai recent) și trimite înapoi ce lipsește.
  Future<void> sync() async {
    final remote = _remote;
    if (remote == null || !_loaded) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        final remoteTasks = {for (final t in await remote.fetchAll()) t.id: t};

        // Fără `await` până la final: lista locală nu se schimbă între timp.
        var changedLocally = false;
        final localIds = <int>{};
        for (var i = 0; i < _tasks.length; i++) {
          localIds.add(_tasks[i].id);
          final r = remoteTasks[_tasks[i].id];
          if (r != null && r.updatedAt.isAfter(_tasks[i].updatedAt)) {
            _tasks[i] = r;
            changedLocally = true;
          }
        }
        for (final r in remoteTasks.values) {
          if (!localIds.contains(r.id) && !r.isExpired()) {
            _tasks.add(r);
            changedLocally = true;
          }
        }
        final toPush = [
          for (final t in _tasks)
            if (remoteTasks[t.id] == null ||
                t.updatedAt.isAfter(remoteTasks[t.id]!.updatedAt))
              t,
        ];

        if (changedLocally) {
          notifyListeners();
          await _save();
          await _notifier.resync(_tasks);
        }
        await remote.upsertAll(toPush);
      } while (_syncAgain);
      _syncStatus = SyncStatus.online;
      _syncError = null;
      _lastSync = DateTime.now();
    } catch (e) {
      _syncStatus = SyncStatus.offline;
      _syncError = e.toString();
      debugPrint('Sincronizarea cu Supabase a eșuat: $e');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _remote?.close();
    super.dispose();
  }

  /// Întoarce `true` dacă a scos ceva.
  bool _purgeExpired() {
    final now = DateTime.now();
    final before = _tasks.length;
    _tasks.removeWhere((t) => t.isExpired(now));
    return _tasks.length != before;
  }

  Future<void> _commit() async {
    _purgeExpired();
    notifyListeners();
    await _save();
    // Nu așteptăm baza de date: interfața rămâne rapidă și offline.
    unawaited(sync());
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_tasks.map((t) => t.toJson()).toList()),
    );
  }
}
