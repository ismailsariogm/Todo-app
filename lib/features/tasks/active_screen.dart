import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:todo_note/app/app_l10n.dart';
import 'package:todo_note/app/router.dart';
import 'package:todo_note/ui/widgets/pink_fab.dart';
import 'package:todo_note/ui/widgets/empty_state_widget.dart';
import 'package:todo_note/features/tasks/providers/tasks_provider.dart';
import 'package:todo_note/features/tasks/widgets/task_card.dart';
import 'package:todo_note/features/tasks/widgets/filter_bar.dart';

class ActiveScreen extends ConsumerWidget {
  const ActiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(filteredTasksProvider);
    final allActive = ref.watch(activeTasksProvider);
    final completed = ref.watch(completedTasksProvider);
    final l = ref.watch(appL10nProvider);

    final activeCount = allActive.valueOrNull?.length ?? 0;
    final completedCount = completed.valueOrNull?.length ?? 0;
    final total = activeCount + completedCount;
    final progress = total == 0 ? 0.0 : completedCount / total;

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

              // ── Tamamlama Barı ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _ProgressCard(
                    activeCount: activeCount,
                    completedCount: completedCount,
                    progress: progress,
                    l: l,
                  ),
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

// ── Progress card ────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.activeCount,
    required this.completedCount,
    required this.progress,
    required this.l,
  });

  final int activeCount;
  final int completedCount;
  final double progress;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Aktif
              _StatChip(
                icon: Icons.radio_button_checked,
                color: const Color(0xFF8B40F0),
                label: l.activeLoading,
                count: activeCount,
              ),
              // Tamamlanan
              _StatChip(
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
                label: l.completedLoading,
                count: completedCount,
              ),
              // Yüzde
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF10B981),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.completed(completedCount, completedCount + activeCount),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.60),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
