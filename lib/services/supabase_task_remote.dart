import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, SupabaseClient;

import '../models/task.dart';
import 'task_remote.dart';

/// Salvează sarcinile în Supabase, prin API-ul lui (HTTPS).
///
/// La prima folosire, aplicația creează automat un cont anonim. Contul e
/// ținut pe dispozitiv, iar baza de date îi arată doar sarcinile lui.
class SupabaseTaskRemote implements TaskRemote {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _ensureSignedIn() async {
    if (_client.auth.currentSession != null) return;
    await _client.auth.signInAnonymously();
  }

  @override
  Future<List<Task>> fetchAll() async {
    await _ensureSignedIn();
    // Rândurile expirate le șterge serverul o dată pe oră; până atunci
    // le filtrează aplicația (TaskStore).
    final rows = await _client.from('tasks').select();
    return [for (final row in rows) _fromRow(row)];
  }

  @override
  Future<void> upsertAll(Iterable<Task> tasks) async {
    final list = tasks.toList();
    if (list.isEmpty) return;
    await _ensureSignedIn();
    await _client.rpc(
      'upsert_tasks',
      params: {
        'items': [for (final t in list) _toRow(t)],
      },
    );
  }

  @override
  Future<void> close() async {}

  static Map<String, dynamic> _toRow(Task t) {
    String? ts(DateTime? d) => d?.toUtc().toIso8601String();
    return {
      'id': t.id,
      'title': t.title,
      'notes': t.notes,
      'category': t.category.name,
      'due_at': ts(t.dueAt),
      'remind': t.remind,
      'done': t.done,
      'completed_at': ts(t.completedAt),
      'created_at': ts(t.createdAt),
      'updated_at': ts(t.updatedAt),
      'deleted_at': ts(t.deletedAt),
    };
  }

  static Task _fromRow(Map<String, dynamic> r) {
    DateTime? date(String key) {
      final v = r[key];
      return v is String ? DateTime.parse(v).toLocal() : null;
    }

    return Task(
      id: (r['id'] as num).toInt(),
      title: r['title'] as String,
      notes: (r['notes'] as String?) ?? '',
      category: Task.categoryFromName(r['category'] as String?),
      dueAt: date('due_at')!,
      remind: r['remind'] as bool,
      done: r['done'] as bool,
      completedAt: date('completed_at'),
      createdAt: date('created_at'),
      updatedAt: date('updated_at'),
      deletedAt: date('deleted_at'),
    );
  }
}
