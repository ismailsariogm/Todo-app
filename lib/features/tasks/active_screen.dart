import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:todo_note/app/app_l10n.dart';
import 'package:todo_note/app/router.dart';
import 'package:todo_note/domain/entities/filter_entity.dart';
import 'package:todo_note/features/tasks/providers/filter_provider.dart';
import 'package:todo_note/ui/widgets/pink_fab.dart';
import 'package:todo_note/ui/widgets/empty_state_widget.dart';
import 'package:todo_note/features/tasks/providers/tasks_provider.dart';
import 'package:todo_note/features/tasks/widgets/task_card.dart';
import 'package:todo_note/features/tasks/widgets/filter_bar.dart';
import 'package:todo_note/features/tasks/widgets/task_progress_dual_section.dart';

class ActiveScreen extends ConsumerWidget {
  const ActiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(filteredTasksProvider);
    final progressSnapshot = ref.watch(homeTaskProgressProvider);
    final dateFilter = ref.watch(taskFilterProvider).dateFilter;
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
          data: (list) => Text(l.activeTitle(list.length)),
          loading: () => Text(l.activeLoading),
          error: (_, __) => Text(l.activeLoading),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded, color: Colors.white),
            tooltip: l.sort,
            onPressed: () {},
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(52),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: FilterBar(pinkTheme: true),
          ),
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
          return CustomScrollView(
            slivers: [
              // AppBar alanı boşluk
              const SliverToBoxAdapter(child: SizedBox(height: 120)),

              // ── Bugün + Devam eden ilerleme ─────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: dateFilter == DateFilter.today
                      ? TaskProgressTodaySection(snapshot: progressSnapshot)
                      : TaskProgressOngoingSection(snapshot: progressSnapshot),
                ),
              ),

              // ── Görev Listesi ──────────────────────────────────────
              if (list.isEmpty)
                SliverFillRemaining(
                  child: EmptyStateWidget(
                    icon: Icons.inbox_outlined,
                    title: l.noActiveTasks,
                    subtitle: l.noActiveSubtitle,
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: EdgeInsets.only(
                        bottom: i == list.length - 1 ? 120 : 4,
                      ),
                      child: TaskCard(task: list[i]),
                    ),
                    childCount: list.length,
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: PinkFab(
        heroTag: 'fab_active',
        onTap: () => context.push(AppRoutes.taskForm),
      ),
    );
  }
}

