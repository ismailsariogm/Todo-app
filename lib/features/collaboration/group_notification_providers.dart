import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../chat/chat_provider.dart';
import '../tasks/providers/tasks_provider.dart';
import '../../services/group_notification_storage.dart';

/// Grup görev rozeti: görüntülenmemiş görev sayısı
final groupTaskBadgeProvider = FutureProvider.family<int, String>((ref, groupId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;
  ref.watch(groupAllTasksCountProvider(groupId));
  final countAsync = ref.read(groupAllTasksCountProvider(groupId));
  final current = countAsync.valueOrNull ?? 0;
  final last = await getLastViewedTaskCount(user.uid, groupId);
  return math.max(0, current - last);
});

/// Grup mesaj rozeti: görüntülenmemiş mesaj sayısı
final groupMessageBadgeProvider = FutureProvider.family<int, String>((ref, groupId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;
  final convId = 'group_proj_$groupId';
  ref.watch(messagesStreamProvider(convId));
  final msgsAsync = ref.read(messagesStreamProvider(convId));
  final msgs = msgsAsync.valueOrNull ?? [];
  final visible = msgs
      .where((m) =>
          !m.isDeleted && !m.deletedForUserIds.contains(user.uid))
      .length;
  final last = await getLastViewedMessageCount(user.uid, groupId);
  return math.max(0, visible - last);
});
