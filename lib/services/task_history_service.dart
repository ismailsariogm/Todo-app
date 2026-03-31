import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'db_client.dart';

const _uuid = Uuid();

// ─── Event Types ─────────────────────────────────────────────────────────────
abstract class TaskEvent {
  static const created        = 'created';
  static const forwardedSingle = 'forwarded_single';
  static const forwardedDouble = 'forwarded_double';
  static const edited         = 'edited';
  static const completed      = 'completed';
  static const completedUndo  = 'completed_undo';
  static const deleted        = 'deleted';
  static const restored       = 'restored';
}

// ─── Model ───────────────────────────────────────────────────────────────────
class TaskHistoryRecord {
  final String id;
  final String taskId;
  final String userId;
  final String userDisplayName;
  final String eventType;
  final DateTime timestamp;
  /// event-specific data:
  /// 'edited'            → {'changes': [{'field': '...', 'from': '...', 'to': '...'}]}
  /// 'forwarded_single'  → {'targetUserId': '...', 'targetUserName': '...'}
  /// 'forwarded_double'  → {'targetUserId': '...', 'targetUserName': '...'}
  final Map<String, dynamic>? details;

  const TaskHistoryRecord({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.userDisplayName,
    required this.eventType,
    required this.timestamp,
    this.details,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'userId': userId,
    'userDisplayName': userDisplayName,
    'eventType': eventType,
    'timestamp': timestamp.toIso8601String(),
    if (details != null) 'details': details,
  };

  factory TaskHistoryRecord.fromJson(Map<String, dynamic> m) =>
      TaskHistoryRecord(
        id: (m['id'] as String?) ?? _uuid.v4(),
        taskId: m['taskId'] as String,
        userId: m['userId'] as String,
        userDisplayName: (m['userDisplayName'] as String?) ?? '',
        eventType: m['eventType'] as String,
        timestamp: DateTime.parse(m['timestamp'] as String),
        details: m['details'] as Map<String, dynamic>?,
      );
}

// ─── Storage ─────────────────────────────────────────────────────────────────
const _kKey = 'task_history_v1';

Future<List<TaskHistoryRecord>> loadTaskHistory(String taskId) async {
  final prefs = await SharedPreferences.getInstance();
  List<TaskHistoryRecord> local = [];
  final raw = prefs.getString(_kKey);
  if (raw != null) {
    try {
      local = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .where((m) => m['taskId'] == taskId)
          .map(TaskHistoryRecord.fromJson)
          .toList();
    } catch (_) {}
  }
  try {
    final dbList = await DbClient.getList('task_history');
    final db = dbList
        .where((m) => m['taskId'] == taskId)
        .map(TaskHistoryRecord.fromJson)
        .toList();
    final merged = <String, TaskHistoryRecord>{};
    for (final r in [...local, ...db]) {
      merged[r.id] = r;
    }
    final result = merged.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  } catch (_) {
    local.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return local;
  }
}

Future<void> recordTaskHistory(TaskHistoryRecord record) async {
  final prefs = await SharedPreferences.getInstance();
  List<Map<String, dynamic>> list = [];
  final raw = prefs.getString(_kKey);
  if (raw != null) {
    try {
      list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {}
  }
  // Remove old record with same id if exists
  list.removeWhere((m) => m['id'] == record.id);
  list.insert(0, record.toJson());
  // Keep at most 2000 records total
  list = list.take(2000).toList();
  await prefs.setString(_kKey, jsonEncode(list));
  try {
    await DbClient.upsertItem('task_history', record.toJson());
  } catch (_) {}
}

// ─── Convenience helpers ─────────────────────────────────────────────────────

Future<void> recordCreated({
  required String taskId,
  required String userId,
  required String userDisplayName,
}) async {
  await recordTaskHistory(TaskHistoryRecord(
    id: _uuid.v4(),
    taskId: taskId,
    userId: userId,
    userDisplayName: userDisplayName,
    eventType: TaskEvent.created,
    timestamp: DateTime.now(),
  ));
}

Future<void> recordEdited({
  required String taskId,
  required String userId,
  required String userDisplayName,
  required List<Map<String, String>> changes,
}) async {
  if (changes.isEmpty) return;
  await recordTaskHistory(TaskHistoryRecord(
    id: _uuid.v4(),
    taskId: taskId,
    userId: userId,
    userDisplayName: userDisplayName,
    eventType: TaskEvent.edited,
    timestamp: DateTime.now(),
    details: {'changes': changes},
  ));
}

Future<void> recordForwardedSingle({
  required String taskId,
  required String userId,
  required String userDisplayName,
  required String targetUserId,
  required String targetUserName,
}) async {
  await recordTaskHistory(TaskHistoryRecord(
    id: _uuid.v4(),
    taskId: taskId,
    userId: userId,
    userDisplayName: userDisplayName,
    eventType: TaskEvent.forwardedSingle,
    timestamp: DateTime.now(),
    details: {'targetUserId': targetUserId, 'targetUserName': targetUserName},
  ));
}

Future<void> recordForwardedDouble({
  required String taskId,
  required String userId,
  required String userDisplayName,
  required String targetUserId,
  required String targetUserName,
}) async {
  await recordTaskHistory(TaskHistoryRecord(
    id: _uuid.v4(),
    taskId: taskId,
    userId: userId,
    userDisplayName: userDisplayName,
    eventType: TaskEvent.forwardedDouble,
    timestamp: DateTime.now(),
    details: {'targetUserId': targetUserId, 'targetUserName': targetUserName},
  ));
}

Future<void> recordCompleted({
  required String taskId,
  required String userId,
  required String userDisplayName,
  bool undo = false,
}) async {
  await recordTaskHistory(TaskHistoryRecord(
    id: _uuid.v4(),
    taskId: taskId,
    userId: userId,
    userDisplayName: userDisplayName,
    eventType: undo ? TaskEvent.completedUndo : TaskEvent.completed,
    timestamp: DateTime.now(),
  ));
}

Future<void> recordDeleted({
  required String taskId,
  required String userId,
  required String userDisplayName,
}) async {
  await recordTaskHistory(TaskHistoryRecord(
    id: _uuid.v4(),
    taskId: taskId,
    userId: userId,
    userDisplayName: userDisplayName,
    eventType: TaskEvent.deleted,
    timestamp: DateTime.now(),
  ));
}

Future<void> recordRestored({
  required String taskId,
  required String userId,
  required String userDisplayName,
}) async {
  await recordTaskHistory(TaskHistoryRecord(
    id: _uuid.v4(),
    taskId: taskId,
    userId: userId,
    userDisplayName: userDisplayName,
    eventType: TaskEvent.restored,
    timestamp: DateTime.now(),
  ));
}
