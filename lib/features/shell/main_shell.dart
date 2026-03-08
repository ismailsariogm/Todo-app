import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:todo_note/app/app_l10n.dart';
import 'package:todo_note/app/router.dart';
import 'package:todo_note/features/chat/chat_panel.dart';
import 'package:todo_note/features/chat/chat_provider.dart';
import 'package:todo_note/features/chat/screens/conversation_screen.dart';
import 'package:todo_note/features/tasks/widgets/home_background.dart';
import 'package:todo_note/ui/widgets/pink_fab.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabIcons = [
    _TabIcon(
      path: AppRoutes.home,
      icon: Icons.wb_sunny_outlined,
      activeIcon: Icons.wb_sunny,
    ),
    _TabIcon(
      path: AppRoutes.active,
      icon: Icons.radio_button_unchecked,
      activeIcon: Icons.radio_button_checked,
    ),
    _TabIcon(
      path: AppRoutes.completed,
      icon: Icons.check_circle_outline,
      activeIcon: Icons.check_circle,
    ),
    _TabIcon(
      path: AppRoutes.trash,
      icon: Icons.delete_outline,
      activeIcon: Icons.delete,
    ),
    _TabIcon(
      path: AppRoutes.settings,
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
    ),
  ];

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabIcons.length; i++) {
      if (loc.startsWith(_tabIcons[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = _selectedIndex(context);
    final isPanelOpen = ref.watch(chatPanelOpenProvider);
    final activeConv = ref.watch(activeConversationProvider);
    final l = ref.watch(appL10nProvider);

    final tabs = [
      _TabItem(icon: _tabIcons[0], label: l.tabToday),
      _TabItem(icon: _tabIcons[1], label: l.tabOngoing),
      _TabItem(icon: _tabIcons[2], label: l.tabCompleted),
      _TabItem(icon: _tabIcons[3], label: l.tabDeleted),
      _TabItem(icon: _tabIcons[4], label: l.tabSettings),
    ];

    final isOnHome = idx == 0 && activeConv == null;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        const HomeBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: activeConv != null
              ? ConversationScreen(conversation: activeConv)
              : child,
          bottomNavigationBar: activeConv != null
              ? null
              : _AnimatedTabBar(
                  selectedIndex: idx,
                  tabs: tabs,
                  onTabSelected: (i) => context.go(tabs[i].icon.path),
                  onChatTap: () {
                    ref.read(chatPanelOpenProvider.notifier).state = true;
                  },
                ),
        ),
        // FAB Stack'in en üstünde — tab bar'ın üzerinde, tıklamaları alır
        if (isOnHome)
          Positioned(
            right: 16,
            bottom: bottomPad + 78,
            child: PinkFab(
              heroTag: 'fab_home',
              onTap: () => context.push(AppRoutes.taskForm),
              pulse: true,
            ),
          ),
        if (isPanelOpen) const ChatPanel(),
      ],
    );
  }
}

// ── Animated tab bar ──────────────────────────────────────────────────────────

class _AnimatedTabBar extends StatelessWidget {
  const _AnimatedTabBar({
    required this.selectedIndex,
    required this.tabs,
    required this.onTabSelected,
    required this.onChatTap,
  });

  final int selectedIndex;
  final List<_TabItem> tabs;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onChatTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottom + 10),
      child: Row(
        children: [
          _ChatButton(onTap: onChatTap),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final tabW = constraints.maxWidth / tabs.length;
                    return SizedBox(
                      height: 58,
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeInOutCubic,
                            left: selectedIndex * tabW,
                            width: tabW,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              for (int i = 0; i < tabs.length; i++)
                                _TabButton(
                                  tab: tabs[i],
                                  isSelected: selectedIndex == i,
                                  onTap: () => onTabSelected(i),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat button ───────────────────────────────────────────────────────────────

class _ChatButton extends StatefulWidget {
  const _ChatButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ChatButton> createState() => _ChatButtonState();
}

class _ChatButtonState extends State<_ChatButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.3)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
    _opacityAnim = Tween<double>(begin: 0.5, end: 0.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: _scaleAnim.value,
                child: Opacity(
                  opacity: _opacityAnim.value,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 1.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              child!,
            ],
          ),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B40F0).withValues(alpha: 0.55),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tab button ────────────────────────────────────────────────────────────────

class _TabButton extends StatefulWidget {
  const _TabButton({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final _TabItem tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  widget.isSelected
                      ? widget.tab.icon.activeIcon
                      : widget.tab.icon.icon,
                  key: ValueKey(widget.isSelected),
                  color: Colors.white.withValues(
                    alpha: widget.isSelected ? 1.0 : 0.60,
                  ),
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: Colors.white.withValues(
                    alpha: widget.isSelected ? 1.0 : 0.60,
                  ),
                ),
                child: Text(widget.tab.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _TabIcon {
  const _TabIcon({
    required this.path,
    required this.icon,
    required this.activeIcon,
  });

  final String path;
  final IconData icon;
  final IconData activeIcon;
}

class _TabItem {
  const _TabItem({required this.icon, required this.label});
  final _TabIcon icon;
  final String label;
}
