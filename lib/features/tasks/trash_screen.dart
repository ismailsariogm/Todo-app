import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:todo_note/app/app_l10n.dart';
import 'package:todo_note/data/repositories/task_repository.dart';
import 'package:todo_note/ui/widgets/empty_state_widget.dart';
import 'package:todo_note/features/tasks/providers/tasks_provider.dart';
import 'package:todo_note/features/tasks/widgets/task_card.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(deletedTasksProvider);
    final l = ref.watch(appL10nProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: tasks.when(
          data: (list) => Text(l.trashTitle(list.length)),
          loading: () => Text(l.trashLoading),
          error: (_, __) => Text(l.trashLoading),
        ),
        actions: [
          tasks.when(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : TextButton.icon(
                    onPressed: () => _confirmClearAll(context, ref, l),
                    icon: const Icon(Icons.delete_forever_rounded,
                        color: Color(0xFFFF6B8A)),
                    label: Text(
                      l.deleteAll,
                      style: const TextStyle(color: Color(0xFFFF6B8A)),
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 100),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.white.withValues(alpha: 0.85), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.trashInfo,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: tasks.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: Colors.white)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.delete_outline_rounded,
                    title: l.noTrashTitle,
                    subtitle: l.noTrashSubtitle,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 120),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) => TaskCard(
                    task: list[i],
                    showCompleteAction: false,
                    showDeleteAction: true,
                    showRestoreAction: true,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(
      BuildContext context, WidgetRef ref, AppL10n l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1060),
        title: Text(l.confirmDeleteAll,
            style: const TextStyle(color: Colors.white)),
        content: Text(
          l.confirmDeleteAllContent,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel,
                style: const TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B8A),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.permanentDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(taskRepositoryProvider);
      final taskList = ref.read(deletedTasksProvider).valueOrNull ?? [];
      for (final t in taskList) {
        await repo.hardDeleteTask(t.id);
      }
    }
  }
}
