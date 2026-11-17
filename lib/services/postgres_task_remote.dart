import 'package:flutter/services.dart' show rootBundle;
import 'package:postgres/postgres.dart';

import '../config/db_config.dart';
import '../models/task.dart';
import 'task_remote.dart';

/// Salvează sarcinile în tabelul `tasks` din PostgreSQL.
class PostgresTaskRemote implements TaskRemote {
  Connection? _conn;
  bool _schemaReady = false;

  Future<Connection> _open() async {
    final existing = _conn;
    if (existing != null && existing.isOpen) return existing;

    final conn = await Connection.open(
      Endpoint(
        host: DbConfig.host,
        port: DbConfig.port,
        database: DbConfig.database,
        username: DbConfig.username,
        password: DbConfig.password,
      ),
      settings: const ConnectionSettings(
        sslMode: SslMode.disable, // conexiune locală
        connectTimeout: Duration(seconds: 4),
        queryTimeout: Duration(seconds: 10),
      ),
    );
    _conn = conn;

    if (!_schemaReady) {
      // Creează tabelul/funcțiile dacă lipsesc (fișierul e idempotent).
      final schema = await rootBundle.loadString('database/schema.sql');
      await conn.execute(schema, queryMode: QueryMode.simple);
      _schemaReady = true;
    }
    return conn;
  }

  /// Rulează [fn]; dacă legătura a căzut, o închide ca să fie redeschisă
  /// data viitoare.
  Future<T> _run<T>(Future<T> Function(Connection conn) fn) async {
    try {
      return await fn(await _open());
    } catch (_) {
      await close();
      rethrow;
    }
  }

  @override
  Future<List<Task>> fetchAll() => _run((conn) async {
    await conn.execute('SELECT purge_expired_tasks()');
    final rows = await conn.execute(
      'SELECT id, title, notes, category, due_at, remind, done, '
      'completed_at, created_at, updated_at, deleted_at FROM tasks',
    );
    return [for (final row in rows) _fromRow(row.toColumnMap())];
  });

  @override
  Future<void> upsertAll(Iterable<Task> tasks) async {
    final list = tasks.toList();
    if (list.isEmpty) return;
    await _run(
      (conn) => conn.runTx((tx) async {
        for (final t in list) {
          await tx.execute(_upsert, parameters: _params(t));
        }
      }),
    );
  }

  @override
  Future<void> close() async {
    final conn = _conn;
    _conn = null;
    try {
      await conn?.close();
    } catch (_) {}
  }

  static final _upsert = Sql.named('''
    INSERT INTO tasks (id, title, notes, category, due_at, remind, done,
                       completed_at, created_at, updated_at, deleted_at)
    VALUES (@id, @title, @notes, @category, @due_at, @remind, @done,
            @completed_at, @created_at, @updated_at, @deleted_at)
    ON CONFLICT (id) DO UPDATE SET
      title = EXCLUDED.title,
      notes = EXCLUDED.notes,
      category = EXCLUDED.category,
      due_at = EXCLUDED.due_at,
      remind = EXCLUDED.remind,
      done = EXCLUDED.done,
      completed_at = EXCLUDED.completed_at,
      updated_at = EXCLUDED.updated_at,
      deleted_at = EXCLUDED.deleted_at
    WHERE tasks.updated_at < EXCLUDED.updated_at
  ''');

  static Map<String, TypedValue> _params(Task t) {
    TypedValue ts(DateTime? d) => TypedValue(Type.timestampTz, d?.toUtc());
    return {
      'id': TypedValue(Type.bigInteger, t.id),
      'title': TypedValue(Type.text, t.title),
      'notes': TypedValue(Type.text, t.notes),
      'category': TypedValue(Type.text, t.category.name),
      'due_at': ts(t.dueAt),
      'remind': TypedValue(Type.boolean, t.remind),
      'done': TypedValue(Type.boolean, t.done),
      'completed_at': ts(t.completedAt),
      'created_at': ts(t.createdAt),
      'updated_at': ts(t.updatedAt),
      'deleted_at': ts(t.deletedAt),
    };
  }

  static Task _fromRow(Map<String, dynamic> r) {
    DateTime? local(Object? v) => (v as DateTime?)?.toLocal();
    return Task(
      id: r['id'] as int,
      title: r['title'] as String,
      notes: r['notes'] as String,
      category: Task.categoryFromName(r['category'] as String),
      dueAt: local(r['due_at'])!,
      remind: r['remind'] as bool,
      done: r['done'] as bool,
      completedAt: local(r['completed_at']),
      createdAt: local(r['created_at']),
      updatedAt: local(r['updated_at']),
      deletedAt: local(r['deleted_at']),
    );
  }
}
