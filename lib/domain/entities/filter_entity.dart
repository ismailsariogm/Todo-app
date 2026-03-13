import 'dart:convert';

enum DateFilter { none, today, tomorrow, overdue, next7days }

enum StatusFilter { active, completed, deleted, all }

class TaskFilter {
  final DateFilter dateFilter;
  final StatusFilter statusFilter;
  final int? priority; // null = all
  final List<String> labels;
  final String? projectId;
  final String? fileId; /// Kişisel görev dosyası filtresi
  final String searchQuery;

  const TaskFilter({
    this.dateFilter = DateFilter.none,
    this.statusFilter = StatusFilter.active,
    this.priority,
    this.labels = const [],
    this.projectId,
    this.fileId,
    this.searchQuery = '',
  });

  bool get hasActiveFilters =>
      dateFilter != DateFilter.none ||
      priority != null ||
      labels.isNotEmpty ||
      projectId != null ||
      fileId != null ||
      searchQuery.isNotEmpty;

  TaskFilter copyWith({
    DateFilter? dateFilter,
    StatusFilter? statusFilter,
    int? priority,
    bool clearPriority = false,
    List<String>? labels,
    String? projectId,
    bool clearProject = false,
    String? fileId,
    bool clearFileId = false,
    String? searchQuery,
  }) {
    return TaskFilter(
      dateFilter: dateFilter ?? this.dateFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      priority: clearPriority ? null : (priority ?? this.priority),
      labels: labels ?? this.labels,
      projectId: clearProject ? null : (projectId ?? this.projectId),
      fileId: clearFileId ? null : (fileId ?? this.fileId),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  TaskFilter reset() => const TaskFilter();

  Map<String, dynamic> toJson() => {
    'dateFilter': dateFilter.name,
    'statusFilter': statusFilter.name,
    'priority': priority,
    'labels': labels,
    'projectId': projectId,
    'fileId': fileId,
    'searchQuery': searchQuery,
  };

  factory TaskFilter.fromJson(Map<String, dynamic> m) => TaskFilter(
    dateFilter:
        DateFilter.values.firstWhere(
          (e) => e.name == m['dateFilter'],
          orElse: () => DateFilter.none,
        ),
    statusFilter:
        StatusFilter.values.firstWhere(
          (e) => e.name == m['statusFilter'],
          orElse: () => StatusFilter.active,
        ),
    priority: m['priority'] as int?,
    labels: (m['labels'] as List<dynamic>?)?.cast<String>() ?? [],
    projectId: m['projectId'] as String?,
    fileId: m['fileId'] as String?,
    searchQuery: (m['searchQuery'] as String?) ?? '',
  );

  String toJsonString() => jsonEncode(toJson());
  factory TaskFilter.fromJsonString(String s) =>
      TaskFilter.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

class SavedFilterEntity {
  final String id;
  final String userId;
  final String name;
  final TaskFilter filter;
  final DateTime createdAt;

  const SavedFilterEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.filter,
    required this.createdAt,
  });
}
