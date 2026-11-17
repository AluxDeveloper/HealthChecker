/// Categoriile de sănătate în care poate fi încadrată o sarcină.
enum TaskCategory {
  medication,
  hydration,
  activity,
  sleep,
  appointment,
  general,
}

/// O sarcină care trebuie îndeplinită la o anumită dată și oră.
class Task {
  Task({
    required this.id,
    required this.title,
    required this.dueAt,
    this.notes = '',
    this.category = TaskCategory.general,
    this.remind = true,
    this.done = false,
    this.completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  /// Cât timp rămâne o sarcină în istoric după ce a fost ștearsă sau după
  /// ce i-a trecut ora. Aceeași valoare e folosită în `database/schema.sql`.
  static const retention = Duration(hours: 72);

  /// Identificator unic; este folosit și ca ID al notificării.
  final int id;
  final String title;
  final String notes;
  final TaskCategory category;
  final DateTime dueAt;
  final bool remind;
  final bool done;

  /// Când a fost bifată ca finalizată (null dacă nu e).
  final DateTime? completedAt;
  final DateTime createdAt;

  /// Ultima modificare; decide care versiune câștigă la sincronizare.
  final DateTime updatedAt;

  /// Când a fost ștearsă (null dacă nu e). O sarcină ștearsă stă în istoric.
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  bool get isOverdue => !done && dueAt.isBefore(DateTime.now());

  /// În istoric ajung sarcinile șterse și cele a căror oră a trecut.
  bool get inHistory => isDeleted || !dueAt.isAfter(DateTime.now());

  /// Momentul la care sarcina dispare definitiv: la [retention] după ștergere
  /// sau după ora programată, oricare vine prima.
  DateTime get expiresAt {
    final d = deletedAt;
    final start = d != null && d.isBefore(dueAt) ? d : dueAt;
    return start.add(retention);
  }

  bool isExpired([DateTime? now]) => !expiresAt.isAfter(now ?? DateTime.now());

  /// Notificarea se programează doar pentru sarcini active, din viitor.
  bool get needsNotification =>
      remind && !done && !isDeleted && dueAt.isAfter(DateTime.now());

  /// Copie modificată; `updatedAt` devine automat momentul de acum.
  Task copyWith({
    String? title,
    String? notes,
    TaskCategory? category,
    DateTime? dueAt,
    bool? remind,
    bool? done,
  }) {
    final isDone = done ?? this.done;
    return Task(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      dueAt: dueAt ?? this.dueAt,
      remind: remind ?? this.remind,
      done: isDone,
      completedAt: isDone ? (completedAt ?? DateTime.now()) : null,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      deletedAt: deletedAt,
    );
  }

  /// Marchează sarcina ca ștearsă (rămâne în istoric) sau o restaurează.
  Task withDeleted(bool deleted) => Task(
    id: id,
    title: title,
    notes: notes,
    category: category,
    dueAt: dueAt,
    remind: remind,
    done: done,
    completedAt: completedAt,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    deletedAt: deleted ? DateTime.now() : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'category': category.name,
    'dueAt': dueAt.toIso8601String(),
    'remind': remind,
    'done': done,
    'completedAt': completedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) {
      final v = json[key];
      return v is String ? DateTime.parse(v) : null;
    }

    final dueAt = date('dueAt')!;
    // Sarcinile salvate înainte de istoric nu au aceste câmpuri.
    final createdAt = date('createdAt') ?? dueAt;
    return Task(
      id: json['id'] as int,
      title: json['title'] as String,
      notes: (json['notes'] as String?) ?? '',
      category: categoryFromName(json['category'] as String?),
      dueAt: dueAt,
      remind: (json['remind'] as bool?) ?? true,
      done: (json['done'] as bool?) ?? false,
      completedAt: date('completedAt'),
      createdAt: createdAt,
      updatedAt: date('updatedAt') ?? createdAt,
      deletedAt: date('deletedAt'),
    );
  }

  static TaskCategory categoryFromName(String? name) =>
      TaskCategory.values.asNameMap()[name] ?? TaskCategory.general;

  /// ID pozitiv pe 31 de biți (limita pentru ID-urile de notificare Android).
  static int newId() =>
      DateTime.now().microsecondsSinceEpoch.remainder(0x7fffffff);
}
