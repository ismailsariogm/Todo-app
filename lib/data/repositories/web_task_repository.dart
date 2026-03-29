import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/task_entity.dart';
import '../../domain/entities/filter_entity.dart';
import '../../services/db_client.dart';

// ─── Abstract base — allows both Drift and SharedPrefs implementations ────────
abstract class BaseTaskRepository {
  // Personal tasks (no projectId)
  Stream<List<TaskEntity>> watchActiveTasks(String ownerId);
  Stream<List<TaskEntity>> watchCompletedTasks(String ownerId);
  Stream<List<TaskEntity>> watchDeletedTasks(String ownerId);
  Stream<List<TaskEntity>> watchTodayTasks(String ownerId);
  /// Kişisel, silinmemiş görevler (grafik / analiz).
  Stream<List<TaskEntity>> watchPersonalTasksNonDeleted(String ownerId);
  Stream<List<TaskEntity>> watchFilteredTasks({
    required String ownerId,
    required TaskFilter filter,
  });
  // Group tasks (all members can see)
  Stream<List<TaskEntity>> watchGroupTasks(String groupId);
  Stream<List<TaskEntity>> watchGroupActiveTasks(String groupId);
  Stream<List<TaskEntity>> watchGroupCompletedTasks(String groupId);
  Stream<List<TaskEntity>> watchGroupDeletedTasks(String groupId);
  Stream<List<TaskEntity>> watchGroupTodayTasks(String groupId);
  Future<List<TaskEntity>> searchGroupTasks(String groupId, String query);
  Future<TaskEntity?> getTaskById(String id);
  Future<List<TaskEntity>> searchTasks(String ownerId, String query);
  Future<TaskEntity> createTask({
    required String ownerId,
    required String title,
    String? projectId,
    String? fileId,
    String? notes,
    DateTime? dueAt,
    DateTime? reminderAt,
    String recurrenceRule,
    int priority,
    List<String> labels,
    String? assigneeId,
    required String deviceId,
  });
  Future<void> updateTask(TaskEntity updated);
  Future<void> completeTask(String id, {bool undo, String? completedByUserId});
  Future<void> softDeleteTask(String id, {String? deletedByUserId});
  Future<void> restoreTask(String id);
  Future<void> hardDeleteTask(String id);
  Future<void> purgeOldDeletedTasks({int daysThreshold});

  /// Klasör silindiğinde bu kullanıcının görevlerinde [fileId] kaldırılır.
  Future<void> clearFileIdForOwnerTasks(String ownerId, String fileId);
}

const _kKey = 'web_tasks_v1';
const _uuid = Uuid();

/// Web-safe task repository: SharedPreferences + reactive StreamController.
/// Replaces Drift on Flutter web where SQLite WASM is unavailable.
class WebTaskRepository extends BaseTaskRepository {
  WebTaskRepository._();
  static final WebTaskRepository instance = WebTaskRepository._();

  List<TaskEntity> _tasks = [];
  final _ctrl = StreamController<List<TaskEntity>>.broadcast();

  // ── Bootstrap ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Kaynak 1: Disk DB sunucusu
    final serverItems = await DbClient.getList('tasks');

    // Kaynak 2: SharedPreferences
    List<Map<String, dynamic>> localItems = [];
    final raw = prefs.getString(_kKey);
    if (raw != null) {
      try {
        localItems = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      } catch (_) {}
    }

    // Birleştir (sunucu öncelikli)
    final merged = DbClient.merge(serverItems, localItems);
    _tasks = merged.map(TaskEntity.fromFirestore).toList();

    // Birleştirilmiş veriyi her iki kaynağa yaz (senkron)
    if (merged.isNotEmpty) {
      await prefs.setString(_kKey, jsonEncode(merged));
      await DbClient.putList('tasks', merged);
    }

    _push();
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  Future<void> _save() async {
    final encoded = _tasks.map((t) => t.toFirestore()).toList();
    // SharedPreferences'a yaz
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(encoded));
    // DB sunucusuna yaz
    await DbClient.putList('tasks', encoded);
    _push();
  }

  void _push() {
    if (!_ctrl.isClosed) _ctrl.add(List.unmodifiable(_tasks));
  }

  /// Mevcut görev listesini (bellekteki) döndürür — auto-sync için.
  List<Map<String, dynamic>> get currentTasksJson =>
      _tasks.map((t) => t.toFirestore()).toList();

  Stream<List<TaskEntity>> _filtered(
    bool Function(TaskEntity) test, {
    List<TaskEntity> Function(List<TaskEntity>)? sort,
  }) {
    List<TaskEntity> compute(List<TaskEntity> all) {
      final result = all.where(test).toList();
      return sort != null ? sort(result) : result;
    }

    return _ctrl.stream.map(compute).distinct();
  }

  List<TaskEntity> _sorted(List<TaskEntity> list) {
    list.sort((a, b) {
      if (a.dueAt != null && b.dueAt == null) return -1;
      if (a.dueAt == null && b.dueAt != null) return 1;
      if (a.dueAt != null && b.dueAt != null) {
        final c = a.dueAt!.compareTo(b.dueAt!);
        if (c != 0) return c;
      }
      return a.priority.compareTo(b.priority);
    });
    return list;
  }

  // ── Watch streams ─────────────────────────────────────────────────────────

  // Personal tasks only (projectId == null)
  Stream<List<TaskEntity>> watchActiveTasks(String ownerId) => _filtered(
    (t) => t.ownerId == ownerId && !t.isCompleted && !t.isDeleted
        && t.projectId == null,
    sort: _sorted,
  );

  Stream<List<TaskEntity>> watchCompletedTasks(String ownerId) => _filtered(
    (t) => t.ownerId == ownerId && t.isCompleted && !t.isDeleted
        && t.projectId == null,
    sort: (l) => l..sort(
      (a, b) => (b.completedAt ?? DateTime(0))
          .compareTo(a.completedAt ?? DateTime(0)),
    ),
  );

  Stream<List<TaskEntity>> watchDeletedTasks(String ownerId) => _filtered(
    (t) => t.ownerId == ownerId && t.isDeleted && t.projectId == null,
    sort: (l) => l..sort(
      (a, b) => (b.deletedAt ?? DateTime(0))
          .compareTo(a.deletedAt ?? DateTime(0)),
    ),
  );

  Stream<List<TaskEntity>> watchTodayTasks(String ownerId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    return _filtered(
      (t) =>
          t.ownerId == ownerId &&
          !t.isCompleted &&
          !t.isDeleted &&
          t.projectId == null &&
          t.dueAt != null &&
          !t.dueAt!.isBefore(todayStart) &&
          t.dueAt!.isBefore(todayEnd),
      sort: (l) => l..sort((a, b) => a.priority.compareTo(b.priority)),
    );
  }

  @override
  Stream<List<TaskEntity>> watchPersonalTasksNonDeleted(String ownerId) =>
      _filtered(
        (t) =>
            t.ownerId == ownerId &&
            !t.isDeleted &&
            t.projectId == null,
        sort: (l) => l..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  Stream<List<TaskEntity>> watchFilteredTasks({
    required String ownerId,
    required TaskFilter filter,
  }) {
    return _filtered((t) {
      if (t.ownerId != ownerId) return false;
      // Personal tasks only on main screen
      if (t.projectId != null) return false;
      if (filter.statusFilter == StatusFilter.active &&
          (t.isCompleted || t.isDeleted)) return false;
      if (filter.statusFilter == StatusFilter.completed && !t.isCompleted) {
        return false;
      }
      if (filter.statusFilter == StatusFilter.deleted && !t.isDeleted) {
        return false;
      }
      if (filter.statusFilter != StatusFilter.deleted && t.isDeleted) {
        return false;
      }
      if (filter.priority != null && t.priority > filter.priority!) {
        return false;
      }
      if (filter.labels.isNotEmpty &&
          !filter.labels.any((l) => t.labels.contains(l))) {
        return false;
      }
      if (filter.searchQuery.isNotEmpty) {
        final q = filter.searchQuery.toLowerCase();
        if (!t.title.toLowerCase().contains(q) &&
            !(t.notes?.toLowerCase().contains(q) ?? false)) {
          return false;
        }
      }
      if (filter.fileId != null && t.fileId != filter.fileId) return false;
      final now = DateTime.now();
      switch (filter.dateFilter) {
        case DateFilter.today:
          if (!t.isDueToday) return false;
        case DateFilter.tomorrow:
          if (!t.isDueTomorrow) return false;
        case DateFilter.overdue:
          if (!t.isOverdue) return false;
        case DateFilter.next7days:
          final limit = now.add(const Duration(days: 7));
          if (t.dueAt == null ||
              !t.dueAt!.isAfter(now) ||
              !t.dueAt!.isBefore(limit)) {
            return false;
          }
        case DateFilter.none:
          break;
      }
      return true;
    }, sort: _sorted);
  }

  // ── Group task streams (projectId == groupId, any ownerId) ─────────────────

  Stream<List<TaskEntity>> watchGroupTasks(String groupId) =>
      _filtered((t) => t.projectId == groupId, sort: _sorted);

  Stream<List<TaskEntity>> watchGroupActiveTasks(String groupId) =>
      _filtered(
        (t) => t.projectId == groupId && !t.isCompleted && !t.isDeleted,
        sort: _sorted,
      );

  Stream<List<TaskEntity>> watchGroupCompletedTasks(String groupId) =>
      _filtered(
        (t) => t.projectId == groupId && t.isCompleted && !t.isDeleted,
        sort: (l) => l..sort(
          (a, b) => (b.completedAt ?? DateTime(0))
              .compareTo(a.completedAt ?? DateTime(0)),
        ),
      );

  Stream<List<TaskEntity>> watchGroupDeletedTasks(String groupId) =>
      _filtered(
        (t) => t.projectId == groupId && t.isDeleted,
        sort: (l) => l..sort(
          (a, b) => (b.deletedAt ?? DateTime(0))
              .compareTo(a.deletedAt ?? DateTime(0)),
        ),
      );

  Stream<List<TaskEntity>> watchGroupTodayTasks(String groupId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    return _filtered(
      (t) =>
          t.projectId == groupId &&
          !t.isCompleted &&
          !t.isDeleted &&
          t.dueAt != null &&
          !t.dueAt!.isBefore(todayStart) &&
          t.dueAt!.isBefore(todayEnd),
      sort: _sorted,
    );
  }

  Future<List<TaskEntity>> searchGroupTasks(
      String groupId, String query) async {
    final q = query.toLowerCase();
    return _tasks
        .where((t) =>
            t.projectId == groupId &&
            !t.isDeleted &&
            (t.title.toLowerCase().contains(q) ||
                (t.notes?.toLowerCase().contains(q) ?? false)))
        .toList();
  }

  // ── Point queries ─────────────────────────────────────────────────────────

  Future<TaskEntity?> getTaskById(String id) async =>
      _tasks.where((t) => t.id == id).firstOrNull;

  Future<List<TaskEntity>> searchTasks(String ownerId, String query) async {
    final q = query.toLowerCase();
    return _tasks
        .where(
          (t) =>
              t.ownerId == ownerId &&
              !t.isDeleted &&
              (t.title.toLowerCase().contains(q) ||
                  (t.notes?.toLowerCase().contains(q) ?? false)),
        )
        .toList();
  }

  // ── Write operations ──────────────────────────────────────────────────────

  Future<TaskEntity> createTask({
    required String ownerId,
    required String title,
    String? projectId,
    String? fileId,
    String? notes,
    DateTime? dueAt,
    DateTime? reminderAt,
    String recurrenceRule = 'none',
    int priority = 4,
    List<String> labels = const [],
    String? assigneeId,
    required String deviceId,
  }) async {
    final now = DateTime.now();
    final task = TaskEntity(
      id: _uuid.v4(),
      ownerId: ownerId,
      projectId: projectId,
      fileId: fileId,
      title: title,
      notes: notes,
      dueAt: dueAt,
      reminderAt: reminderAt,
      recurrenceRule: recurrenceRule,
      priority: priority,
      labels: labels,
      assigneeId: assigneeId,
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
    );
    _tasks.add(task);
    await _save();
    return task;
  }

  Future<void> updateTask(TaskEntity updated) async {
    final idx = _tasks.indexWhere((t) => t.id == updated.id);
    if (idx != -1) {
      _tasks[idx] = updated;
      await _save();
    }
  }

  Future<void> completeTask(String id,
      {bool undo = false, String? completedByUserId}) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _tasks[idx] = _tasks[idx].copyWith(
        isCompleted: !undo,
        completedAt: undo ? null : DateTime.now(),
        completedByUserId: undo ? null : completedByUserId,
        clearCompletedBy: undo,
      );
      await _save();
    }
  }

  Future<void> softDeleteTask(String id, {String? deletedByUserId}) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _tasks[idx] = _tasks[idx].copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
        deletedByUserId: deletedByUserId,
      );
      await _save();
    }
  }

  Future<void> restoreTask(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _tasks[idx] = _tasks[idx].copyWith(
        isDeleted: false,
        deletedAt: null,
        clearDeletedBy: true,
      );
      await _save();
    }
  }

  Future<void> hardDeleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await _save();
  }

  Future<void> purgeOldDeletedTasks({int daysThreshold = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysThreshold));
    _tasks.removeWhere(
      (t) =>
          t.isDeleted &&
          t.deletedAt != null &&
          t.deletedAt!.isBefore(cutoff),
    );
    await _save();
  }

  @override
  Future<void> clearFileIdForOwnerTasks(String ownerId, String fileId) async {
    var changed = false;
    for (var i = 0; i < _tasks.length; i++) {
      final t = _tasks[i];
      if (t.ownerId == ownerId && t.fileId == fileId) {
        _tasks[i] = t.copyWith(clearFileId: true);
        changed = true;
      }
    }
    if (changed) await _save();
  }
}
