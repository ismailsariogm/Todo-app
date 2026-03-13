import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/filter_entity.dart';
import '../providers/filter_provider.dart';
import '../providers/tasks_provider.dart';
import 'filter_bottom_sheet.dart';

/// Filter chip bar.
/// [pinkTheme] = true → white-based colors for the HomeScreen pink background.
/// SwiftUI equivalent: FilterChips with matchedGeometryEffect + press scaleEffect.
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key, this.pinkTheme = false});

  final bool pinkTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(taskFilterProvider);
    final filesAsync = ref.watch(taskFilesProvider);

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // All-filters button
          _AnimChip(
            label: 'Filtreler',
            icon: Icons.tune_rounded,
            isActive: filter.hasActiveFilters,
            pinkTheme: pinkTheme,
            onTap: () => _showFilterSheet(context, ref),
          ),
          const SizedBox(width: 8),
          _Divider(pinkTheme: pinkTheme),
          const SizedBox(width: 8),

          // Date filter chips
          for (final df in DateFilter.values.where((d) => d != DateFilter.none))
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _AnimChip(
                label: _dateLabel(df),
                isActive: filter.dateFilter == df,
                pinkTheme: pinkTheme,
                onTap: () {
                  ref.read(taskFilterProvider.notifier).setDateFilter(
                        filter.dateFilter == df ? DateFilter.none : df,
                      );
                },
              ),
            ),

          _Divider(pinkTheme: pinkTheme),
          const SizedBox(width: 6),

          // Priority chips
          for (int p = 1; p <= 3; p++)
            Padding(
              padding: EdgeInsets.only(right: 6, left: p == 1 ? 8 : 0),
              child: _PriorityAnimChip(
                priority: p,
                isActive: filter.priority == p,
                pinkTheme: pinkTheme,
                onTap: () {
                  ref.read(taskFilterProvider.notifier).setPriority(
                        filter.priority == p ? null : p,
                      );
                },
              ),
            ),

          // Klasör filtreleri — ana ekranda kolay erişim
          filesAsync.when(
            data: (files) {
              if (files.isEmpty) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Divider(pinkTheme: pinkTheme),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _AnimChip(
                      label: 'Tümü',
                      isActive: filter.fileId == null,
                      pinkTheme: pinkTheme,
                      onTap: () =>
                          ref.read(taskFilterProvider.notifier).setFile(null),
                    ),
                  ),
                  ...files.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _AnimChip(
                        label: f.name,
                        isActive: filter.fileId == f.id,
                        pinkTheme: pinkTheme,
                        onTap: () {
                          ref.read(taskFilterProvider.notifier).setFile(
                                filter.fileId == f.id ? null : f.id,
                              );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          if (filter.hasActiveFilters) ...[
            const SizedBox(width: 4),
            _AnimChip(
              label: 'Temizle',
              icon: Icons.close_rounded,
              isActive: false,
              pinkTheme: pinkTheme,
              onTap: () => ref.read(taskFilterProvider.notifier).reset(),
            ),
          ],
        ],
      ),
    );
  }

  String _dateLabel(DateFilter df) => switch (df) {
        DateFilter.today => 'Bugün',
        DateFilter.tomorrow => 'Yarın',
        DateFilter.overdue => 'Geciken',
        DateFilter.next7days => 'Bu Hafta',
        DateFilter.none => '',
      };

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const FilterBottomSheet(),
    );
  }
}

// ── Animated date/generic filter chip ──────────────────────────────────────
// SwiftUI: Chip with .scaleEffect(pressed ? 0.96:1) + matchedGeometryEffect bg

class _AnimChip extends StatefulWidget {
  const _AnimChip({
    required this.label,
    this.icon,
    required this.isActive,
    required this.onTap,
    required this.pinkTheme,
  });

  final String label;
  final IconData? icon;
  final bool isActive;
  final VoidCallback onTap;
  final bool pinkTheme;

  @override
  State<_AnimChip> createState() => _AnimChipState();
}

class _AnimChipState extends State<_AnimChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Colors adapt based on theme mode (pink home vs normal screens)
    final activeBg = widget.pinkTheme
        ? Colors.white.withValues(alpha: 0.25)
        : cs.primary;
    final inactiveBg = widget.pinkTheme
        ? Colors.white.withValues(alpha: 0.12)
        : cs.surfaceContainerHighest;
    final activeFg = widget.pinkTheme ? Colors.white : cs.onPrimary;
    final inactiveFg = widget.pinkTheme
        ? Colors.white.withValues(alpha: 0.80)
        : cs.onSurface;
    final activeBorder = widget.pinkTheme
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.transparent;
    final inactiveBorder = widget.pinkTheme
        ? Colors.white.withValues(alpha: 0.20)
        : Colors.transparent;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        // SwiftUI: .scaleEffect(pressed ? 0.96 : 1.0)
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isActive ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isActive ? activeBorder : inactiveBorder,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 14,
                  color: widget.isActive ? activeFg : inactiveFg,
                ),
                const SizedBox(width: 4),
              ],
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      widget.isActive ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isActive ? activeFg : inactiveFg,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated priority chip ──────────────────────────────────────────────────

class _PriorityAnimChip extends StatefulWidget {
  const _PriorityAnimChip({
    required this.priority,
    required this.isActive,
    required this.onTap,
    required this.pinkTheme,
  });

  final int priority;
  final bool isActive;
  final VoidCallback onTap;
  final bool pinkTheme;

  @override
  State<_PriorityAnimChip> createState() => _PriorityAnimChipState();
}

class _PriorityAnimChipState extends State<_PriorityAnimChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = PriorityColor.of(widget.priority);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isActive ? color : color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isActive
                  ? color
                  : color.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  widget.isActive ? FontWeight.w700 : FontWeight.w600,
              color:
                  widget.isActive ? Colors.white : color,
            ),
            child: Text(PriorityColor.label(widget.priority)),
          ),
        ),
      ),
    );
  }
}

// ── Divider ────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider({required this.pinkTheme});
  final bool pinkTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(vertical: 9),
      color: pinkTheme
          ? Colors.white.withValues(alpha: 0.30)
          : Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
