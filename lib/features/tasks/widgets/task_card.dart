import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../domain/entities/project_entity.dart' show GroupMemberEntity;
import '../../../domain/entities/task_entity.dart';
import '../../../services/auto_sync_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/subtask_storage.dart';
import '../../auth/auth_provider.dart';
import '../providers/tasks_provider.dart';

class TaskCard extends ConsumerWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.onComplete,
    this.onDelete,
    this.onRestore,
    this.showCompleteAction = true,
    this.showDeleteAction = true,
    this.showRestoreAction = false,
    this.groupMembers = const [],
    this.groupId,
  });

  final TaskEntity task;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final bool showCompleteAction;
  final bool showDeleteAction;
  final bool showRestoreAction;
  final List<GroupMemberEntity> groupMembers;
  final String? groupId;

  String _memberName(String userId) {
    final m = groupMembers.where((x) => x.userId == userId).firstOrNull;
    return m?.displayName ?? userId;
  }

  String _memberRole(String userId) {
    final m = groupMembers.where((x) => x.userId == userId).firstOrNull;
    if (m == null) return '';
    return switch (m.role) {
      'yonetici' || 'owner' => 'Yönetici',
      'kıdemli' => 'Kıdemli',
      _ => 'Üye',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final priorityColor = PriorityColor.of(task.priority);

    return Slidable(
      key: ValueKey(task.id),
      startActionPane: showCompleteAction
          ? ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.22,
              children: [
                SlidableAction(
                  onPressed: (_) => _complete(ref, context),
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  icon: task.isCompleted
                      ? Icons.undo_rounded
                      : Icons.check_rounded,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ],
            )
          : null,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: showRestoreAction ? 0.44 : 0.22,
        children: [
          if (showRestoreAction)
            SlidableAction(
              onPressed: (_) => _restore(ref),
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              icon: Icons.restore_rounded,
              label: 'Geri Al',
            ),
          if (showDeleteAction)
            SlidableAction(
              onPressed: (_) => _delete(ref, context),
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              icon: showRestoreAction
                  ? Icons.delete_forever_rounded
                  : Icons.delete_outline_rounded,
              label: showRestoreAction ? 'Sil' : null,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/task/${task.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Builder(builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // Açık mod: beyaz kart | Koyu mod: koyu cam kart
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: priorityColor, width: 4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Checkbox ─────────────────────────────────────────
              GestureDetector(
                onTap: showCompleteAction
                    ? () => _complete(ref, context)
                    : null,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 2, right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: task.isCompleted
                          ? const Color(0xFF10B981)
                          : cs.outline,
                      width: 2,
                    ),
                    color: task.isCompleted
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : Colors.transparent,
                  ),
                  child: task.isCompleted
                      ? const Icon(Icons.check, size: 14, color: Color(0xFF10B981))
                      : null,
                ),
              ),
              // ── Content ──────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? cs.onSurface.withOpacity(0.4)
                            : cs.onSurface,
                      ),
                    ),
                    if (task.notes != null && task.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.notes!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    _SubtaskPreview(taskId: task.id),
                    const SizedBox(height: 8),
                    // ── Meta row ───────────────────────────────────
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (task.dueAt != null)
                          _MetaChip(
                            icon: Icons.calendar_today_outlined,
                            label: _formatDate(task.dueAt!),
                            color: task.isOverdue
                                ? cs.error
                                : cs.onSurface.withOpacity(0.5),
                          ),
                        if (task.reminderAt != null)
                          _MetaChip(
                            icon: Icons.notifications_outlined,
                            label: _formatDate(task.reminderAt!),
                            color: cs.onSurface.withOpacity(0.5),
                          ),
                        ...task.labels.take(3).map(
                          (l) => _LabelChip(label: l),
                        ),
                        if (task.assigneeId != null)
                          _MetaChip(
                            icon: Icons.person_outline,
                            label: 'Atanmış',
                            color: cs.primary.withOpacity(0.8),
                          ),
                      ],
                    ),
                    if (groupId != null &&
                        groupMembers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _UserMetaChip(
                            icon: Icons.person_add_outlined,
                            label: _memberName(task.ownerId),
                            role: _memberRole(task.ownerId),
                            date: task.createdAt,
                          ),
                          if (task.isCompleted &&
                              task.completedByUserId != null) ...[
                            const SizedBox(width: 4),
                            _UserMetaChip(
                              icon: Icons.check_circle_outline,
                              label: _memberName(task.completedByUserId!),
                              role: _memberRole(task.completedByUserId!),
                              date: task.completedAt,
                            ),
                          ],
                          if (task.isDeleted &&
                              task.deletedByUserId != null) ...[
                            const SizedBox(width: 4),
                            _UserMetaChip(
                              icon: Icons.delete_outline,
                              label: _memberName(task.deletedByUserId!),
                              role: _memberRole(task.deletedByUserId!),
                              date: task.deletedAt,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // ── Priority badge ────────────────────────────────────
              if (task.priority < 4)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      PriorityColor.label(task.priority),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: priorityColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        }),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Bugün ${DateFormat.Hm().format(dt)}';
    }
    if (dt.difference(now).inDays == 1) {
      return 'Yarın ${DateFormat.Hm().format(dt)}';
    }
    return DateFormat('d MMM', 'tr_TR').format(dt);
  }

  Future<void> _complete(WidgetRef ref, BuildContext context) async {
    final userId = ref.read(currentUserProvider)?.uid;
    HapticFeedback.lightImpact();
    if (!task.isCompleted) {
      final subs = await loadSubtasks(task.id);
      if (subs.isNotEmpty) {
        final incomplete = subs.where((s) => !s.isCompleted).toList();
        if (incomplete.isNotEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Önce ${incomplete.length} alt görevi tamamlayın',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
    }
    final repo = ref.read(taskRepositoryProvider);
    await repo.completeTask(task.id,
        undo: task.isCompleted, completedByUserId: userId);
    if (!task.isCompleted && task.reminderAt != null) {
      await NotificationService.instance.cancelReminder(task.id);
    }
    AutoSyncService.instance.flush();
    onComplete?.call();
  }

  Future<void> _delete(WidgetRef ref, BuildContext context) async {
    HapticFeedback.mediumImpact();
    final userId = ref.read(currentUserProvider)?.uid;
    final repo = ref.read(taskRepositoryProvider);
    await repo.softDeleteTask(task.id, deletedByUserId: userId);
    await NotificationService.instance.cancelReminder(task.id);
    AutoSyncService.instance.flush();
    onDelete?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Görev silindi'),
          action: SnackBarAction(
            label: 'Geri Al',
            onPressed: () => repo.restoreTask(task.id),
          ),
        ),
      );
    }
  }

  Future<void> _restore(WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final repo = ref.read(taskRepositoryProvider);
    await repo.restoreTask(task.id);
    AutoSyncService.instance.flush();
    onRestore?.call();
  }
}

class _SubtaskPreview extends ConsumerWidget {
  const _SubtaskPreview({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(subtasksProvider(taskId));
    return subsAsync.when(
      data: (subs) {
        if (subs.isEmpty) return const SizedBox.shrink();
        final done = subs.where((s) => s.isCompleted).length;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 4),
              Text(
                '$done/${subs.length} alt görev',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }
}

class _UserMetaChip extends StatelessWidget {
  const _UserMetaChip({
    required this.icon,
    required this.label,
    required this.role,
    required this.date,
  });

  final IconData icon;
  final String label;
  final String role;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.onSurface.withOpacity(0.6);
    final dateStr = date != null
        ? DateFormat('d MMM yyyy, HH:mm', 'tr_TR').format(date!)
        : '';
    return Tooltip(
      message: role.isNotEmpty ? '$label • $role • $dateStr' : '$label • $dateStr',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
          ),
          if (role.isNotEmpty) ...[
            const SizedBox(width: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(role, style: TextStyle(fontSize: 9, color: color)),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '#$label',
        style: TextStyle(
          fontSize: 11,
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
