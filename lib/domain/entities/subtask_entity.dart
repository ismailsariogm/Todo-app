class SubtaskEntity {
  final String id;
  final String taskId;
  final String title;
  final bool isCompleted;
  final int sortOrder;
  final DateTime createdAt;
  final String? completedByUserId;
  final DateTime? completedAt;

  const SubtaskEntity({
    required this.id,
    required this.taskId,
    required this.title,
    this.isCompleted = false,
    this.sortOrder = 0,
    required this.createdAt,
    this.completedByUserId,
    this.completedAt,
  });

  SubtaskEntity copyWith({
    String? title,
    bool? isCompleted,
    int? sortOrder,
    String? completedByUserId,
    DateTime? completedAt,
    bool clearCompletedBy = false,
  }) =>
      SubtaskEntity(
        id: id,
        taskId: taskId,
        title: title ?? this.title,
        isCompleted: isCompleted ?? this.isCompleted,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
        completedByUserId: clearCompletedBy
            ? null
            : (completedByUserId ?? this.completedByUserId),
        completedAt: clearCompletedBy ? null : (completedAt ?? this.completedAt),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'title': title,
    'isCompleted': isCompleted,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toIso8601String(),
    if (completedByUserId != null) 'completedByUserId': completedByUserId,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
  };

  factory SubtaskEntity.fromJson(Map<String, dynamic> m) => SubtaskEntity(
    id: m['id'] as String,
    taskId: m['taskId'] as String,
    title: m['title'] as String,
    isCompleted: (m['isCompleted'] as bool?) ?? false,
    sortOrder: (m['sortOrder'] as int?) ?? 0,
    createdAt: DateTime.parse(m['createdAt'] as String),
    completedByUserId: m['completedByUserId'] as String?,
    completedAt: m['completedAt'] != null
        ? DateTime.parse(m['completedAt'] as String)
        : null,
  );
}

class CommentEntity {
  final String id;
  final String taskId;
  final String userId;
  final String userDisplayName;
  final String body;
  final DateTime createdAt;

  const CommentEntity({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.userDisplayName,
    required this.body,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'userId': userId,
    'userDisplayName': userDisplayName,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CommentEntity.fromJson(Map<String, dynamic> m) => CommentEntity(
    id: m['id'] as String,
    taskId: m['taskId'] as String,
    userId: m['userId'] as String,
    userDisplayName: m['userDisplayName'] as String,
    body: m['body'] as String,
    createdAt: DateTime.parse(m['createdAt'] as String),
  );
}
