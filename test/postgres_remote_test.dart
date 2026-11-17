
import 'package:flutter_test/flutter_test.dart';
import 'package:postgres/postgres.dart';
import 'package:sarcini/config/db_config.dart';
import 'package:sarcini/models/task.dart';
import 'package:sarcini/services/postgres_task_remote.dart';

/// Test pe baza de date reală. Se sare automat dacă PostgreSQL nu rulează.
/// Folosește ID-uri negative, pe care aplicația nu le generează niciodată.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Connection admin;
  var available = true;

  setUpAll(() async {
    try {
      admin = await Connection.open(
        Endpoint(
          host: DbConfig.host,
          database: DbConfig.database,
          username: DbConfig.username,
          password: DbConfig.password,
        ),
        settings: ConnectionSettings(
          sslMode: DbConfig.ssl ? SslMode.require : SslMode.disable,
        ),
      );
    } catch (_) {
      available = false;
    }
  });

  tearDownAll(() async {
    if (!available) return;
    await admin.execute('DELETE FROM tasks WHERE id < 0');
    await admin.close();
  });

  test('salvează, actualizează și șterge expiratele în PostgreSQL', () async {
    if (!available) {
      markTestSkipped('PostgreSQL nu rulează');
      return;
    }
    final remote = PostgresTaskRemote();
    final now = DateTime.now();
    final active = Task(
      id: -1,
      title: 'Control cardiolog',
      notes: 'Adu analizele',
      category: TaskCategory.appointment,
      dueAt: now.add(const Duration(days: 2)),
    );
    final expired = Task(
      id: -2,
      title: 'Expirată',
      dueAt: now.subtract(const Duration(days: 4)),
    );
    await remote.upsertAll([active, expired]);

    var rows = {for (final t in await remote.fetchAll()) t.id: t};
    expect(rows.containsKey(-2), isFalse, reason: 'purge_expired_tasks()');
    final saved = rows[-1]!;
    expect(saved.title, 'Control cardiolog');
    expect(saved.notes, 'Adu analizele');
    expect(saved.category, TaskCategory.appointment);
    expect(saved.dueAt, active.dueAt);
    expect(saved.updatedAt, active.updatedAt);

    // o versiune mai veche nu suprascrie una mai nouă
    final deleted = active.withDeleted(true);
    await remote.upsertAll([deleted]);
    await remote.upsertAll([active]);
    rows = {for (final t in await remote.fetchAll()) t.id: t};
    expect(rows[-1]!.isDeleted, isTrue);

    final history = await admin.execute(
      "SELECT motiv FROM task_history WHERE id = -1",
    );
    expect(history.single.single, 'stearsa');
    await remote.close();
  });
}
