import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:todo_note/app/app_l10n.dart';
import 'package:todo_note/ui/widgets/empty_state_widget.dart';
import 'package:todo_note/features/tasks/providers/tasks_provider.dart';
import 'package:todo_note/domain/entities/task_entity.dart';
import 'package:todo_note/features/tasks/widgets/task_card.dart';

class CompletedScreen extends ConsumerWidget {
  const CompletedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(completedTasksProvider);
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
          data: (list) => Text(l.completedTitle(list.length)),
          loading: () => Text(l.completedLoading),
          error: (_, __) => Text(l.completedLoading),
        ),
      ),
      body: tasks.when(
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
              icon: Icons.check_circle_outline_rounded,
              title: l.noCompleted,
              subtitle: l.noCompletedSubtitle,
            );
          }
          final grouped = _groupByDate(list, l);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 100, 0, 120),
            itemCount: grouped.length,
            itemBuilder: (_, i) {
              final entry = grouped[i];
              return entry.isHeader
                  ? _DateHeader(label: entry.dateLabel!)
                  : TaskCard(
                      task: entry.task!,
                      showCompleteAction: true,
                      showDeleteAction: true,
                    );
            },
          );
        },
      ),
    );
  }

  List<_ListItem> _groupByDate(List<TaskEntity> tasks, AppL10n l) {
    final result = <_ListItem>[];
    String? lastLabel;
    for (final t in tasks) {
      final label = _dateLabel(t.completedAt, l);
      if (label != lastLabel) {
        result.add(_ListItem.header(label));
        lastLabel = label;
      }
      result.add(_ListItem.task(t));
    }
    return result;
  }

  String _dateLabel(DateTime? dt, AppL10n l) {
    if (dt == null) return l.noDate;
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return l.today;
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return l.yesterday;
    }
    return DateFormat(l.datePattern, l.dateLocale).format(dt);
  }
}

class _ListItem {
  const _ListItem.header(String label)
      : isHeader = true,
        dateLabel = label,
        task = null;

  const _ListItem.task(TaskEntity t)
      : isHeader = false,
        task = t,
        dateLabel = null;

  final bool isHeader;
  final String? dateLabel;
  final TaskEntity? task;
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
