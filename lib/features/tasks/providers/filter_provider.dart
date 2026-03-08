import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/filter_entity.dart';
import '../../../data/repositories/project_repository.dart';
import '../../auth/auth_provider.dart';

// ─── Active filter ────────────────────────────────────────────────────────
final taskFilterProvider =
    StateNotifierProvider<TaskFilterNotifier, TaskFilter>(
  TaskFilterNotifier.new,
);

class TaskFilterNotifier extends StateNotifier<TaskFilter> {
  TaskFilterNotifier(Ref ref) : super(const TaskFilter());

  void setDateFilter(DateFilter f) =>
      state = state.copyWith(dateFilter: f);

  void setPriority(int? p) =>
      state = state.copyWith(priority: p, clearPriority: p == null);

  void toggleLabel(String label) {
    final labels = List<String>.from(state.labels);
    if (labels.contains(label)) {
      labels.remove(label);
    } else {
      labels.add(label);
    }
    state = state.copyWith(labels: labels);
  }

  void setProject(String? id) =>
      state = state.copyWith(projectId: id, clearProject: id == null);

  void setStatus(StatusFilter s) =>
      state = state.copyWith(statusFilter: s);

  void setSearchQuery(String q) =>
      state = state.copyWith(searchQuery: q);

  void applyFilter(TaskFilter filter) => state = filter;

  void reset() => state = const TaskFilter();
}

// ─── Saved filters ────────────────────────────────────────────────────────
final savedFiltersProvider = StreamProvider((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchSavedFilters(user.uid);
});
