/// Immutable domain entity – decoupled from Drift generated types.
class TaskEntity {
  final String id;
  final String ownerId;
  final String? projectId;
  final String title;
  final String? notes;
  final DateTime? dueAt;
  final DateTime? reminderAt;
  final String recurrenceRule;
  final int priority;
  final List<String> labels;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? assigneeId;
  final String? completedByUserId;
  final String? deletedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final String deviceId;

  const TaskEntity({
    required this.id,
    required this.ownerId,
    this.projectId,
    required this.title,
    this.notes,
    this.dueAt,
    this.reminderAt,
    this.recurrenceRule = 'none',
    this.priority = 4,
    this.labels = const [],
    this.isCompleted = false,
    this.completedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.assigneeId,
    this.completedByUserId,
    this.deletedByUserId,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    required this.deviceId,
  });

  bool get isOverdue {
    if (dueAt == null || isCompleted || isDeleted) return false;
    return dueAt!.isBefore(DateTime.now());
  }

  bool get isDueToday {
    if (dueAt == null) return false;
    final now = DateTime.now();
    final d = dueAt!;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool get isDueTomorrow {
    if (dueAt == null) return false;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final d = dueAt!;
    return d.year == tomorrow.year &&
        d.month == tomorrow.month &&
        d.day == tomorrow.day;
  }

  TaskEntity copyWith({
    String? title,
    String? notes,
    DateTime? dueAt,
    bool clearDueAt = false,
    DateTime? reminderAt,
    bool clearReminderAt = false,
    String? recurrenceRule,
    int? priority,
    List<String>? labels,
    bool? isCompleted,
    DateTime? completedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? projectId,
    String? assigneeId,
    String? completedByUserId,
    String? deletedByUserId,
    bool clearCompletedBy = false,
    bool clearDeletedBy = false,
    DateTime? updatedAt,
    int? version,
  }) {
    return TaskEntity(
      id: id,
      ownerId: ownerId,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      reminderAt:
          clearReminderAt ? null : (reminderAt ?? this.reminderAt),
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      priority: priority ?? this.priority,
      labels: labels ?? this.labels,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      assigneeId: assigneeId ?? this.assigneeId,
      completedByUserId: clearCompletedBy
          ? null
          : (completedByUserId ?? this.completedByUserId),
      deletedByUserId: clearDeletedBy
          ? null
          : (deletedByUserId ?? this.deletedByUserId),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      version: version ?? (this.version + 1),
      deviceId: deviceId,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'ownerId': ownerId,
    'projectId': projectId,
    'title': title,
    'notes': notes,
    'dueAt': dueAt?.toIso8601String(),
    'reminderAt': reminderAt?.toIso8601String(),
    'recurrenceRule': recurrenceRule,
    'priority': priority,
    'labels': labels,
    'isCompleted': isCompleted,
    'completedAt': completedAt?.toIso8601String(),
    'isDeleted': isDeleted,
    'deletedAt': deletedAt?.toIso8601String(),
    'assigneeId': assigneeId,
    'completedByUserId': completedByUserId,
    'deletedByUserId': deletedByUserId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
    'deviceId': deviceId,
  };

  factory TaskEntity.fromFirestore(Map<String, dynamic> m) => TaskEntity(
    id: m['id'] as String,
    ownerId: m['ownerId'] as String,
    projectId: m['projectId'] as String?,
    title: m['title'] as String,
    notes: m['notes'] as String?,
    dueAt: m['dueAt'] != null ? DateTime.parse(m['dueAt'] as String) : null,
    reminderAt: m['reminderAt'] != null
        ? DateTime.parse(m['reminderAt'] as String)
        : null,
    recurrenceRule: (m['recurrenceRule'] as String?) ?? 'none',
    priority: (m['priority'] as int?) ?? 4,
    labels: (m['labels'] as List<dynamic>?)?.cast<String>() ?? [],
    isCompleted: (m['isCompleted'] as bool?) ?? false,
    completedAt: m['completedAt'] != null
        ? DateTime.parse(m['completedAt'] as String)
        : null,
    isDeleted: (m['isDeleted'] as bool?) ?? false,
    deletedAt: m['deletedAt'] != null
        ? DateTime.parse(m['deletedAt'] as String)
        : null,
    assigneeId: m['assigneeId'] as String?,
    completedByUserId: m['completedByUserId'] as String?,
    deletedByUserId: m['deletedByUserId'] as String?,
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: DateTime.parse(m['updatedAt'] as String),
    version: (m['version'] as int?) ?? 1,
    deviceId: (m['deviceId'] as String?) ?? '',
  );
}
