import '../models/task.dart';

/// Locul în care [TaskStore] păstrează o copie a sarcinilor (baza de date).
/// Interfața permite rularea testelor fără PostgreSQL.
abstract interface class TaskRemote {
  /// Șterge definitiv sarcinile expirate și le întoarce pe toate celelalte.
  Future<List<Task>> fetchAll();

  /// Salvează sarcinile; un rând existent e înlocuit doar dacă versiunea
  /// trimisă e mai nouă (`updatedAt`).
  Future<void> upsertAll(Iterable<Task> tasks);

  Future<void> close();
}
