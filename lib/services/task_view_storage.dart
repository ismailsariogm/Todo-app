import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'db_client.dart';

/// Görev görüntüleme kaydı — kim hangi görevi ne zaman görüntüledi
class TaskViewRecord {
  final String taskId;
  final String userId;
  final String userDisplayName;
  final String userRole;
  final DateTime viewedAt;

  const TaskViewRecord({
    required this.taskId,
    required this.userId,
    required this.userDisplayName,
    required this.userRole,
    required this.viewedAt,
  });

  String get id => '${taskId}_${userId}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'userId': userId,
    'userDisplayName': userDisplayName,
    'userRole': userRole,
    'viewedAt': viewedAt.toIso8601String(),
  };

  factory TaskViewRecord.fromJson(Map<String, dynamic> m) => TaskViewRecord(
    taskId: m['taskId'] as String,
    userId: m['userId'] as String,
    userDisplayName: (m['userDisplayName'] as String?) ?? '',
    userRole: (m['userRole'] as String?) ?? '',
    viewedAt: DateTime.parse(m['viewedAt'] as String),
  );
}

const _key = 'task_views_v1';

Future<List<TaskViewRecord>> loadTaskViews(String taskId) async {
  final prefs = await SharedPreferences.getInstance();
  List<TaskViewRecord> local = [];
  final raw = prefs.getString(_key);
  if (raw != null) {
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      local = list
          .map(TaskViewRecord.fromJson)
          .where((v) => v.taskId == taskId)
          .toList();
    } catch (_) {}
  }
  try {
    final dbList = await DbClient.getList('task_views');
    final db = dbList
        .where((m) => m['taskId'] == taskId)
        .map(TaskViewRecord.fromJson)
        .toList();
    final merged = <String, TaskViewRecord>{};
    for (final v in [...local, ...db]) {
      final existing = merged[v.userId];
      if (existing == null || v.viewedAt.isAfter(existing.viewedAt)) {
        merged[v.userId] = v;
      }
    }
    final result = merged.values.toList()
      ..sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
    return result;
  } catch (_) {
    local.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
    return local;
  }
}

Future<void> recordTaskView(TaskViewRecord record) async {
  final prefs = await SharedPreferences.getInstance();
  List<Map<String, dynamic>> list = [];
  final raw = prefs.getString(_key);
  if (raw != null) {
    try {
      list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {}
  }
  list.removeWhere((m) =>
      m['taskId'] == record.taskId && m['userId'] == record.userId);
  list.insert(0, record.toJson());
  list = list.take(500).toList();
  await prefs.setString(_key, jsonEncode(list));
  try {
    await DbClient.upsertItem('task_views', record.toJson());
  } catch (_) {}
}
