import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tasks/providers/tasks_provider.dart';
import 'group_notification_providers.dart';

/// Görev rozeti ikonu (not defteri)
class GroupTaskBadgeIcon extends ConsumerWidget {
  const GroupTaskBadgeIcon({
    super.key,
    required this.groupId,
    this.iconSize = 18,
  });

  final String groupId;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeAsync = ref.watch(groupTaskBadgeProvider(groupId));
    return badgeAsync.when(
      data: (count) => _buildIcon(count),
      loading: () => Icon(Icons.note_add_outlined, size: iconSize, color: Colors.white),
      error: (_, __) => Icon(Icons.note_add_outlined, size: iconSize, color: Colors.white),
    );
  }

  Widget _buildIcon(int count) {
    if (count == 0) {
      return Icon(Icons.note_add_outlined, size: iconSize, color: Colors.white);
    }
    return Badge(
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      backgroundColor: const Color(0xFFEF4444),
      child: Icon(Icons.note_add_outlined, size: iconSize, color: Colors.white),
    );
  }
}

/// Grup kartında görev + mesaj rozetleri (sadece sayı > 0 ise göster)
class GroupCardBadges extends ConsumerWidget {
  const GroupCardBadges({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskBadge = ref.watch(groupTaskBadgeProvider(groupId));
    final msgBadge = ref.watch(groupMessageBadgeProvider(groupId));
    final taskCount = taskBadge.valueOrNull ?? 0;
    final msgCount = msgBadge.valueOrNull ?? 0;
    if (taskCount == 0 && msgCount == 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (taskCount > 0) ...[
          Badge(
            label: Text('$taskCount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
            backgroundColor: const Color(0xFFEF4444),
            child: Icon(Icons.note_add_outlined, size: 14, color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(width: 4),
        ],
        if (msgCount > 0)
          Badge(
            label: Text('$msgCount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
            backgroundColor: const Color(0xFFEF4444),
            child: Icon(Icons.chat_bubble_outline, size: 14, color: Colors.white.withValues(alpha: 0.85)),
          ),
      ],
    );
  }
}

/// Mesaj rozeti ikonu
class GroupMessageBadgeIcon extends ConsumerWidget {
  const GroupMessageBadgeIcon({
    super.key,
    required this.groupId,
    this.iconSize = 18,
  });

  final String groupId;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeAsync = ref.watch(groupMessageBadgeProvider(groupId));
    return badgeAsync.when(
      data: (count) => _buildIcon(count),
      loading: () => Icon(Icons.chat_bubble_outline, size: iconSize, color: Colors.white),
      error: (_, __) => Icon(Icons.chat_bubble_outline, size: iconSize, color: Colors.white),
    );
  }

  Widget _buildIcon(int count) {
    if (count == 0) {
      return Icon(Icons.chat_bubble_outline, size: iconSize, color: Colors.white);
    }
    return Badge(
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      backgroundColor: const Color(0xFFEF4444),
      child: Icon(Icons.chat_bubble_outline, size: iconSize, color: Colors.white),
    );
  }
}

/// Gruplar için toplam görev rozeti
final totalGroupTaskBadgeProvider = FutureProvider<int>((ref) async {
  ref.watch(sharedGroupsProvider);
  final groups = ref.read(sharedGroupsProvider).valueOrNull ?? [];
  if (groups.isEmpty) return 0;
  int total = 0;
  for (final g in groups) {
    total += await ref.read(groupTaskBadgeProvider(g.id).future);
  }
  return total;
});

/// Gruplar için toplam mesaj rozeti
final totalGroupMessageBadgeProvider = FutureProvider<int>((ref) async {
  ref.watch(sharedGroupsProvider);
  final groups = ref.read(sharedGroupsProvider).valueOrNull ?? [];
  if (groups.isEmpty) return 0;
  int total = 0;
  for (final g in groups) {
    total += await ref.read(groupMessageBadgeProvider(g.id).future);
  }
  return total;
});

/// Başlık yanında toplam rozetleri gösteren widget
class TotalGroupBadgesHeader extends ConsumerWidget {
  const TotalGroupBadgesHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskBadge = ref.watch(totalGroupTaskBadgeProvider);
    final msgBadge = ref.watch(totalGroupMessageBadgeProvider);
    final taskCount = taskBadge.valueOrNull ?? 0;
    final msgCount = msgBadge.valueOrNull ?? 0;
    if (taskCount == 0 && msgCount == 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (taskCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Badge(
              label: Text('$taskCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              backgroundColor: const Color(0xFFEF4444),
              child: Icon(Icons.note_add_outlined, size: 18, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
        if (msgCount > 0)
          Badge(
            label: Text('$msgCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
            backgroundColor: const Color(0xFFEF4444),
            child: Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white.withValues(alpha: 0.9)),
          ),
      ],
    );
  }
}
