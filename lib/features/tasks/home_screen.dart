import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:todo_note/app/app_l10n.dart';
import 'package:todo_note/app/router.dart';
import 'package:todo_note/features/auth/auth_provider.dart';
import 'package:todo_note/features/chat/chat_provider.dart';
import 'package:todo_note/features/collaboration/group_badge_widget.dart';
import 'package:todo_note/domain/entities/filter_entity.dart';
import 'package:todo_note/features/tasks/providers/filter_provider.dart';
import 'package:todo_note/features/tasks/providers/tasks_provider.dart';
import 'package:todo_note/features/tasks/widgets/task_card.dart';
import 'package:todo_note/features/tasks/widgets/filter_bar.dart';
import 'package:todo_note/features/tasks/widgets/task_progress_dual_section.dart';
import 'package:todo_note/ui/widgets/empty_state_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final progressSnapshot = ref.watch(homeTaskProgressProvider);
    final dateFilter = ref.watch(taskFilterProvider).dateFilter;
    final searchResults = ref.watch(searchResultsProvider);
    final allTasks = ref.watch(filteredTasksProvider);
    final l = ref.watch(appL10nProvider);

    final greeting = _greeting(l);
    final dateStr = DateFormat(l.homeDatePattern, l.dateLocale).format(DateTime.now());

    // Transparent scaffold — HomeBackground from MainShell shows through
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          // ── Glass app bar ─────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            expandedHeight: 110,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$greeting, ${user?.displayName.split(' ').first ?? l.user}!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => context.push(AppRoutes.collab),
                icon: const Icon(Icons.group_outlined, color: Colors.white, size: 20),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.groupWork,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    TotalGroupBadgesHeader(),
                  ],
                ),
              ),
            ],
          ),

          // ── Search bar ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _GlassSearchBar(
                controller: _searchCtrl,
                isSearching: _isSearching,
                hintText: l.searchHint,
                onChanged: (q) {
                  ref.read(searchQueryProvider.notifier).state = q;
                  ref.read(recentSearchesProvider.notifier).add(q);
                  setState(() => _isSearching = q.isNotEmpty);
                },
                onClear: () {
                  _searchCtrl.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                  setState(() => _isSearching = false);
                },
              ),
            ),
          ),

          if (_isSearching) ...[
            // ── Search results ────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                    l.searchResults,
                    style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            searchResults.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(
                  child: Text('Hata: $e',
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
              data: (results) {
                if (results.isEmpty) {
                  return SliverToBoxAdapter(
                    child: EmptyStateWidget(
                      icon: Icons.search_off_rounded,
                      title: l.noResults,
                      subtitle: l.noResultsSubtitle,
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => TaskCard(task: results[i]),
                    childCount: results.length,
                  ),
                );
              },
            ),
          ] else ...[
            // ── Filter chips ─────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: FilterBar(pinkTheme: true),
              ),
            ),

            // ── Bugün VEYA Devam eden ilerleme (tarih filtresine göre ayrı) ─
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: dateFilter == DateFilter.today
                    ? TaskProgressTodaySection(snapshot: progressSnapshot)
                    : TaskProgressOngoingSection(snapshot: progressSnapshot),
              ),
            ),

            // ── Privacy banner ────────────────────────────────────────
            SliverToBoxAdapter(
              child: _PrivacyBanner(l: l),
            ),

            // ── Tasks header ─────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      l.myTasks,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    allTasks.when(
                      data: (list) => Text(
                        l.tasks(list.length),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 13,
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

            // ── Task list ─────────────────────────────────────────────
            allTasks.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(
                  child: Text('Hata: $e',
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return SliverToBoxAdapter(
                    child: EmptyStateWidget(
                      icon: Icons.check_circle_outline_rounded,
                      title: l.noTasksTitle,
                      subtitle: l.noTasksSubtitle,
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: TaskCard(task: tasks[i]),
                    ),
                    childCount: tasks.length,
                  ),
                );
              },
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ],
      ),
      // FAB artık MainShell'de (alt menünün üstünde, tıklanabilir)
    );
  }

  String _greeting(AppL10n l) {
    final h = DateTime.now().hour;
    if (h < 12) return l.greetingMorning;
    if (h < 18) return l.greetingAfternoon;
    return l.greetingEvening;
  }
}

// ── Glass search bar ────────────────────────────────────────────────────────
// SwiftUI: SearchBar with .ultraThinMaterial background

class _GlassSearchBar extends StatefulWidget {
  const _GlassSearchBar({
    required this.controller,
    required this.isSearching,
    required this.onChanged,
    required this.onClear,
    required this.hintText,
  });

  final TextEditingController controller;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;

  @override
  State<_GlassSearchBar> createState() => _GlassSearchBarState();
}

class _GlassSearchBarState extends State<_GlassSearchBar> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _focused ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: _focused ? 0.45 : 0.20),
          width: _focused ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: Icon(Icons.search, color: Colors.white, size: 20),
          ),
          Expanded(
            child: Focus(
              onFocusChange: (f) => setState(() => _focused = f),
                child: TextField(
                controller: widget.controller,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                ),
                onChanged: widget.onChanged,
              ),
            ),
          ),
          if (widget.isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: widget.onClear,
            ),
        ],
      ),
    );
  }
}

// ── Privacy banner ──────────────────────────────────────────────────────────

class _PrivacyBanner extends ConsumerWidget {
  const _PrivacyBanner({required this.l});
  final AppL10n l;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(filteredFriendsProvider).valueOrNull ?? [];

    final bool hasFriends = friends.isNotEmpty;
    final Color color =
        hasFriends ? const Color(0xFF10B981) : const Color(0xFF8B40F0);
    final IconData icon =
        hasFriends ? Icons.group_rounded : Icons.lock_rounded;
    final String text =
        hasFriends ? l.taskPrivateBannerGroup : l.taskPrivateBanner;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

