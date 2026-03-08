import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/subtask_entity.dart';
import 'db_client.dart';

String _subtasksKey(String taskId) => 'subtasks_$taskId';

Future<List<SubtaskEntity>> loadSubtasks(String taskId) async {
  try {
    final dbList = await DbClient.getList('subtasks');
    final db = dbList
        .where((m) => m['taskId'] == taskId)
        .map(SubtaskEntity.fromJson)
        .toList();
    if (db.isNotEmpty) {
      db.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return db;
    }
  } catch (_) {}
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_subtasksKey(taskId));
  if (raw == null) return [];
  try {
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(SubtaskEntity.fromJson)
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveSubtasks(String taskId, List<SubtaskEntity> list) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _subtasksKey(taskId),
    jsonEncode(list.map((s) => s.toJson()).toList()),
  );
  try {
    final all = await DbClient.getList('subtasks');
    final filtered = all.where((m) => m['taskId'] != taskId).toList();
    final updated = [...filtered, ...list.map((s) => s.toJson()).toList()];
    await DbClient.putList('subtasks', updated);
  } catch (_) {}
}
