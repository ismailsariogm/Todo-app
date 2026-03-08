/// Grup görevleri için filtre modeli
class GroupTaskFilter {
  final String searchQuery;
  final DateTime? createdDateFrom;
  final DateTime? createdDateTo;
  final DateTime? createdTimeFrom;
  final DateTime? createdTimeTo;
  final DateTime? dueDateFrom;
  final DateTime? dueDateTo;
  final List<String> creatorUserIds;
  final List<int> priorities;

  const GroupTaskFilter({
    this.searchQuery = '',
    this.createdDateFrom,
    this.createdDateTo,
    this.createdTimeFrom,
    this.createdTimeTo,
    this.dueDateFrom,
    this.dueDateTo,
    this.creatorUserIds = const [],
    this.priorities = const [],
  });

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      createdDateFrom != null ||
      createdDateTo != null ||
      createdTimeFrom != null ||
      createdTimeTo != null ||
      dueDateFrom != null ||
      dueDateTo != null ||
      creatorUserIds.isNotEmpty ||
      priorities.isNotEmpty;

  GroupTaskFilter copyWith({
    String? searchQuery,
    DateTime? createdDateFrom,
    DateTime? createdDateTo,
    DateTime? createdTimeFrom,
    DateTime? createdTimeTo,
    DateTime? dueDateFrom,
    DateTime? dueDateTo,
    List<String>? creatorUserIds,
    List<int>? priorities,
    bool clearCreatedDateFrom = false,
    bool clearCreatedDateTo = false,
    bool clearCreatedTimeFrom = false,
    bool clearCreatedTimeTo = false,
    bool clearDueDateFrom = false,
    bool clearDueDateTo = false,
    bool clearCreatorUserIds = false,
    bool clearPriorities = false,
  }) =>
      GroupTaskFilter(
        searchQuery: searchQuery ?? this.searchQuery,
        createdDateFrom: clearCreatedDateFrom ? null : (createdDateFrom ?? this.createdDateFrom),
        createdDateTo: clearCreatedDateTo ? null : (createdDateTo ?? this.createdDateTo),
        createdTimeFrom: clearCreatedTimeFrom ? null : (createdTimeFrom ?? this.createdTimeFrom),
        createdTimeTo: clearCreatedTimeTo ? null : (createdTimeTo ?? this.createdTimeTo),
        dueDateFrom: clearDueDateFrom ? null : (dueDateFrom ?? this.dueDateFrom),
        dueDateTo: clearDueDateTo ? null : (dueDateTo ?? this.dueDateTo),
        creatorUserIds: clearCreatorUserIds ? [] : (creatorUserIds ?? this.creatorUserIds),
        priorities: clearPriorities ? [] : (priorities ?? this.priorities),
      );

  GroupTaskFilter reset() => const GroupTaskFilter();
}
