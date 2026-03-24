import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../domain/entities/task_entity.dart';
import '../../../domain/entities/subtask_entity.dart';
import '../../../domain/entities/project_entity.dart';
import '../../../domain/entities/project_entity.dart' show GroupMemberEntity;
import '../../../features/auth/auth_provider.dart';
import '../../../domain/entities/task_file_entity.dart';
import '../../../services/subtask_storage.dart';
import '../../../services/task_file_storage.dart';
import 'filter_provider.dart';
import 'group_filter_provider.dart';

// ─── Active tasks ─────────────────────────────────────────────────────────
final activeTasksProvider = StreamProvider<List<TaskEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchActiveTasks(user.uid);
});

// ─── Today tasks ──────────────────────────────────────────────────────────
final todayTasksProvider = StreamProvider<List<TaskEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchTodayTasks(user.uid);
});

// ─── Completed tasks ──────────────────────────────────────────────────────
final completedTasksProvider = StreamProvider<List<TaskEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchCompletedTasks(user.uid);
});

// ─── Deleted tasks ────────────────────────────────────────────────────────
final deletedTasksProvider = StreamProvider<List<TaskEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchDeletedTasks(user.uid);
});

// ─── Filtered tasks ───────────────────────────────────────────────────────
final filteredTasksProvider = StreamProvider<List<TaskEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(taskRepositoryProvider);
  final filter = ref.watch(taskFilterProvider);
  return repo.watchFilteredTasks(ownerId: user.uid, filter: filter);
});

// ─── Single task ──────────────────────────────────────────────────────────
final taskByIdProvider =
    FutureProvider.family<TaskEntity?, String>((ref, taskId) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getTaskById(taskId);
});

// ─── Subtasks (for TaskCard display & completion check) ───────────────────
final subtasksProvider =
    FutureProvider.family<List<SubtaskEntity>, String>((ref, taskId) async {
  return loadSubtasks(taskId);
});

// ─── Search results ───────────────────────────────────────────────────────
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<TaskEntity>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  final repo = ref.watch(taskRepositoryProvider);
  return repo.searchTasks(user.uid, query.trim());
});

// ─── Recent searches ──────────────────────────────────────────────────────
final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>(
  RecentSearchesNotifier.new,
);

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier(Ref ref) : super([]);

  void add(String q) {
    if (q.trim().isEmpty) return;
    final updated = [q, ...state.where((s) => s != q)].take(10).toList();
    state = updated;
  }

  void remove(String q) {
    state = state.where((s) => s != q).toList();
  }

  void clear() => state = [];
}

// ─── Task files (kişisel dosya/kategoriler) ───────────────────────────────
final taskFilesProvider = FutureProvider<List<TaskFileEntity>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return TaskFileStorage.instance.getFiles(user.uid);
});

// ─── Projects (owned) ─────────────────────────────────────────────────────
final projectsProvider = StreamProvider<List<ProjectEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchProjects(user.uid);
});

// ─── Shared groups (owned + member) — normal gruplar, topluluk hariç ───────
final sharedGroupsProvider = StreamProvider<List<ProjectEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchSharedGroupsForUser(user.uid).map((list) =>
      list.where((p) => !p.isCommunityGroup && p.parentCommunityId == null).toList());
});

// ─── Topluluk grupları (owned + member) ────────────────────────────────────
final sharedCommunityGroupsProvider = StreamProvider<List<ProjectEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchSharedGroupsForUser(user.uid).map((list) =>
      list.where((p) => p.isCommunityGroup).toList());
});

// ─── Group members (shared provider used by detail + settings screens) ────
final groupMembersProvider =
    StreamProvider.family<List<GroupMemberEntity>, String>((ref, groupId) {
  return ref.watch(projectRepositoryProvider).watchGroupMembers(groupId);
});

// ─── Group tasks providers ─────────────────────────────────────────────────

enum GroupTaskTab { all, today, active, done, deleted }

final groupTaskTabProvider =
    StateProvider.family<GroupTaskTab, String>((_, __) => GroupTaskTab.active);

final groupSearchQueryProvider =
    StateProvider.family<String, String>((_, __) => '');

final groupTaskFilterProvider =
    StateProvider.family<GroupTaskFilter, String>((_, __) => const GroupTaskFilter());

final groupTasksProvider =
    StreamProvider.family<List<TaskEntity>, String>((ref, groupId) {
  final tab = ref.watch(groupTaskTabProvider(groupId));
  final repo = ref.watch(taskRepositoryProvider);
  return switch (tab) {
    GroupTaskTab.all     => repo.watchGroupTasks(groupId),
    GroupTaskTab.today   => repo.watchGroupTodayTasks(groupId),
    GroupTaskTab.active  => repo.watchGroupActiveTasks(groupId),
    GroupTaskTab.done    => repo.watchGroupCompletedTasks(groupId),
    GroupTaskTab.deleted => repo.watchGroupDeletedTasks(groupId),
  };
});

// ─── Tüm paylaşılan projeler (grup + topluluk + alt grup) ──────────────────
final allSharedProjectsForUserProvider =
    StreamProvider<List<ProjectEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchSharedGroupsForUser(user.uid);
});

// ─── Proje ID ile (grup, topluluk veya alt grup) ───────────────────────────
final projectByIdProvider =
    FutureProvider.family<ProjectEntity?, String>((ref, id) async {
  final all = await ref.watch(allSharedProjectsForUserProvider.future);
  return all.where((p) => p.id == id).firstOrNull;
});

// ─── Topluluk grubu (id ile) ──────────────────────────────────────────────
final communityByIdProvider =
    FutureProvider.family<ProjectEntity?, String>((ref, communityId) async {
  final groups = await ref.read(sharedCommunityGroupsProvider.future);
  return groups.where((p) => p.id == communityId).firstOrNull;
});

// ─── Topluluk alt grupları ────────────────────────────────────────────────
final communitySubGroupsProvider =
    StreamProvider.family<List<ProjectEntity>, String>((ref, communityId) {
  return ref.watch(projectRepositoryProvider).watchSubGroups(communityId);
});

/// Tüm grup görevlerinin sayısı (bildirim rozeti için)
final groupAllTasksCountProvider =
    StreamProvider.family<int, String>((ref, groupId) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchGroupTasks(groupId).map((tasks) => tasks.length);
});

// ─── İlerleme çubukları (Bugün / Devam eden) — kişisel + grup ─────────────

/// Bugün tamamlanan görev sayısı (completedAt = bugün).
int _countCompletedToday(List<TaskEntity> completed) {
  final now = DateTime.now();
  return completed.where((t) {
    final c = t.completedAt;
    if (c == null) return false;
    return c.year == now.year && c.month == now.month && c.day == now.day;
  }).length;
}

typedef TaskProgressPair = ({int done, int total});

/// Ana ekran: Bugün (son tarihi bugün bekleyen + bugün tamamlanan) ve Devam eden (aktif+tamamlanan).
final homeTaskProgressProvider = Provider<TaskProgressSnapshot>((ref) {
  final todayAsync = ref.watch(todayTasksProvider);
  final activeAsync = ref.watch(activeTasksProvider);
  final completedAsync = ref.watch(completedTasksProvider);
  final loading =
      todayAsync.isLoading || activeAsync.isLoading || completedAsync.isLoading;
  if (loading || !todayAsync.hasValue || !activeAsync.hasValue || !completedAsync.hasValue) {
    return TaskProgressSnapshot.loading();
  }
  final todayActive = todayAsync.value!;
  final active = activeAsync.value!;
  final completed = completedAsync.value!;
  final todayDone = _countCompletedToday(completed);
  final todayTotal = todayActive.length + todayDone;
  final ongoingTotal = active.length + completed.length;
  return TaskProgressSnapshot(
    loading: false,
    today: (done: todayDone, total: todayTotal),
    ongoing: (done: completed.length, total: ongoingTotal),
  );
});

class TaskProgressSnapshot {
  const TaskProgressSnapshot({
    required this.loading,
    required this.today,
    required this.ongoing,
  });

  factory TaskProgressSnapshot.loading() => const TaskProgressSnapshot(
        loading: true,
        today: (done: 0, total: 0),
        ongoing: (done: 0, total: 0),
      );

  final bool loading;
  final TaskProgressPair today;
  final TaskProgressPair ongoing;
}

// ─── Grup görevleri: istatistik akışları (sekmeden bağımsız) ───────────────

final groupStatsTodayTasksProvider =
    StreamProvider.family<List<TaskEntity>, String>((ref, groupId) {
  return ref.watch(taskRepositoryProvider).watchGroupTodayTasks(groupId);
});

final groupStatsActiveTasksProvider =
    StreamProvider.family<List<TaskEntity>, String>((ref, groupId) {
  return ref.watch(taskRepositoryProvider).watchGroupActiveTasks(groupId);
});

final groupStatsCompletedTasksProvider =
    StreamProvider.family<List<TaskEntity>, String>((ref, groupId) {
  return ref.watch(taskRepositoryProvider).watchGroupCompletedTasks(groupId);
});

final groupTaskProgressProvider =
    Provider.family<TaskProgressSnapshot, String>((ref, groupId) {
  final todayAsync = ref.watch(groupStatsTodayTasksProvider(groupId));
  final activeAsync = ref.watch(groupStatsActiveTasksProvider(groupId));
  final completedAsync = ref.watch(groupStatsCompletedTasksProvider(groupId));
  final loading = todayAsync.isLoading ||
      activeAsync.isLoading ||
      completedAsync.isLoading;
  if (loading ||
      !todayAsync.hasValue ||
      !activeAsync.hasValue ||
      !completedAsync.hasValue) {
    return TaskProgressSnapshot.loading();
  }
  final todayActive = todayAsync.value!;
  final active = activeAsync.value!;
  final completed = completedAsync.value!;
  final todayDone = _countCompletedToday(completed);
  final todayTotal = todayActive.length + todayDone;
  final ongoingTotal = active.length + completed.length;
  return TaskProgressSnapshot(
    loading: false,
    today: (done: todayDone, total: todayTotal),
    ongoing: (done: completed.length, total: ongoingTotal),
  );
});
