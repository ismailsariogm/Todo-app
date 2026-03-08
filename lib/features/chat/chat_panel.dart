import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/chat_user_entity.dart';
import '../../domain/entities/conversation_entity.dart';
import 'chat_provider.dart';
import 'screens/add_friend_screen.dart';
import 'screens/conversation_screen.dart';

/// WhatsApp benzeri sol panel.
/// [chatPanelOpenProvider] tarafından kontrol edilir.
/// [activeConversationProvider] seçili sohbeti tutar.
class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel({super.key});

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  int _tabIndex = 0; // 0 = sohbetler, 1 = arkadaşlar
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _ctrl.forward();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _close() {
    _ctrl.reverse().then((_) {
      ref.read(chatPanelOpenProvider.notifier).state = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final panelW = size.width.clamp(0.0, 380.0);

    return Stack(
      children: [
        // ── Backdrop ──────────────────────────────────────────────────────
        FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onTap: _close,
            child: Container(
              width: size.width,
              height: size.height,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
        ),

        // ── Panel ─────────────────────────────────────────────────────────
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: panelW,
          child: SlideTransition(
            position: _slideAnim,
            child: _PanelContent(
              tabIndex: _tabIndex,
              query: _query,
              searchCtrl: _searchCtrl,
              onTabChange: (i) => setState(() => _tabIndex = i),
              onClose: _close,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Panel content ─────────────────────────────────────────────────────────────

class _PanelContent extends ConsumerWidget {
  const _PanelContent({
    required this.tabIndex,
    required this.query,
    required this.searchCtrl,
    required this.onTabChange,
    required this.onClose,
  });

  final int tabIndex;
  final String query;
  final TextEditingController searchCtrl;
  final ValueChanged<int> onTabChange;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0533), Color(0xFF2D1060)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x558B40F0),
            blurRadius: 40,
            offset: Offset(8, 0),
          ),
        ],
      ),
      // Material needed so TextField and Ink widgets can find a Material ancestor
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            _PanelHeader(onClose: onClose),

            // ── Profile strip ────────────────────────────────────────────
            const _MyProfileStrip(),

            const SizedBox(height: 12),

            // ── Search bar ───────────────────────────────────────────────
            _SearchBar(ctrl: searchCtrl),

            const SizedBox(height: 12),

            // ── Tabs ─────────────────────────────────────────────────────
            _TabBar(selected: tabIndex, onSelect: onTabChange),

            const SizedBox(height: 8),

            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: tabIndex == 0
                  ? _ConversationList(query: query, onClose: onClose)
                  : _FriendList(query: query, onClose: onClose),
            ),

            // ── Action buttons ────────────────────────────────────────────
            _ActionBar(currentTab: tabIndex),
          ],
        ),
        ), // SafeArea
      ), // Material
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Mesajlar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close,
              color: Colors.white.withValues(alpha: 0.7),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ── My profile strip ──────────────────────────────────────────────────────────

class _MyProfileStrip extends ConsumerWidget {
  const _MyProfileStrip();

  Color _parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(chatUserProfileProvider);
    return profileAsync.when(
      loading: () => const SizedBox(height: 16),
      error: (_, __) => const SizedBox(),
      data: (profile) {
        if (profile == null) return const SizedBox();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _parseHex(profile.avatarColorHex),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4), width: 2),
                ),
                child: Center(
                  child: Text(
                    profile.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.tag,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.55)),
                        Text(
                          profile.userCode,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.ctrl});
  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
        ),
        child: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Ara...',
            hintStyle:
                TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
            prefixIcon: Icon(Icons.search,
                color: Colors.white.withValues(alpha: 0.5), size: 20),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
    );
  }
}

// ── Tabs ──────────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _TabItem(
                label: 'Sohbetler',
                icon: Icons.chat_outlined,
                isSelected: selected == 0,
                onTap: () => onSelect(0)),
            _TabItem(
                label: 'Arkadaşlar',
                icon: Icons.people_outline,
                isSelected: selected == 1,
                onTap: () => onSelect(1)),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)],
                  )
                : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.5),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color:
                      Colors.white.withValues(alpha: isSelected ? 1.0 : 0.5),
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Conversation list ─────────────────────────────────────────────────────────

class _ConversationList extends ConsumerWidget {
  const _ConversationList({required this.query, required this.onClose});
  final String query;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convsAsync = ref.watch(conversationsStreamProvider);

    return convsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white54)),
      error: (e, _) =>
          Center(child: Text(e.toString(), style: const TextStyle(color: Colors.white70))),
      data: (convs) {
        // Only show direct (1-to-1) conversations; group projects live in "Ortak Grup"
        final directOnly = convs
            .where((c) => c.type == ConversationType.direct)
            .toList();
        final filtered = query.isEmpty
            ? directOnly
            : directOnly
                .where((c) => c.displayName
                    .toLowerCase()
                    .contains(query.toLowerCase()))
                .toList();

        if (filtered.isEmpty) {
          return _EmptyState(
            icon: Icons.chat_bubble_outline,
            message: query.isEmpty
                ? 'Henüz sohbet yok'
                : 'Sonuç bulunamadı',
            subtitle: query.isEmpty
                ? 'Arkadaşların ile konuşmaya başla'
                : null,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _ConvTile(
            conv: filtered[i],
            onTap: () {
              ref.read(activeConversationProvider.notifier).state = filtered[i];
              onClose();
            },
          ),
        );
      },
    );
  }
}

class _ConvTile extends ConsumerWidget {
  const _ConvTile({required this.conv, required this.onTap});
  final ConversationEntity conv;
  final VoidCallback onTap;

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF8B40F0);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeConversationProvider);
    final isActive = active?.id == conv.id;

    String timeStr = '';
    if (conv.lastMessageAt != null) {
      final now = DateTime.now();
      final diff = now.difference(conv.lastMessageAt!);
      if (diff.inDays == 0) {
        timeStr = DateFormat('HH:mm').format(conv.lastMessageAt!);
      } else if (diff.inDays < 7) {
        timeStr = DateFormat('EEE', 'tr_TR').format(conv.lastMessageAt!);
      } else {
        timeStr = DateFormat('dd/MM').format(conv.lastMessageAt!);
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF8B40F0).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? const Color(0xFF8B40F0).withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _parseHex(conv.avatarColor),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      conv.avatarInitials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (conv.type == ConversationType.group)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFF8B40F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.group,
                            color: Colors.white, size: 10),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    conv.lastMessage ?? 'Sohbet başlat',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Friend list ───────────────────────────────────────────────────────────────

class _FriendList extends ConsumerWidget {
  const _FriendList({required this.query, required this.onClose});
  final String query;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsStreamProvider);

    return friendsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white54)),
      error: (e, _) => Center(
          child:
              Text(e.toString(), style: const TextStyle(color: Colors.white70))),
      data: (friends) {
        final filtered = query.isEmpty
            ? friends
            : friends
                .where((f) => f.displayName
                    .toLowerCase()
                    .contains(query.toLowerCase()))
                .toList();

        if (filtered.isEmpty) {
          return _EmptyState(
            icon: Icons.people_outline,
            message: query.isEmpty ? 'Arkadaş listeniz boş' : 'Sonuç bulunamadı',
            subtitle: query.isEmpty
                ? 'Arkadaş eklemek için + düğmesine bas'
                : null,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _FriendTile(
            friend: filtered[i],
            onChat: () async {
              final conv = await ref
                  .read(chatActionsProvider)
                  .openDirectChat(filtered[i]);
              if (conv != null) onClose();
            },
            onRemove: () async {
              await ref
                  .read(chatActionsProvider)
                  .removeFriend(filtered[i].uid);
            },
          ),
        );
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.onChat,
    required this.onRemove,
  });
  final ChatUserEntity friend;
  final VoidCallback onChat;
  final VoidCallback onRemove;

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF8B40F0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(friend.uid),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFCF4DA6).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.person_remove, color: Colors.white70),
      ),
      confirmDismiss: (_) async {
        onRemove();
        return true;
      },
      child: GestureDetector(
        onTap: onChat,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _parseHex(friend.avatarColorHex),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    friend.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      friend.userCode,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onChat,
                icon: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_bubble_outline,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Action bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.currentTab});
  final int currentTab;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Center(
        child: SizedBox(
          width: 200,
          child: _ActionButton(
          icon: Icons.person_add_alt_1_outlined,
          label: 'Arkadaş Ekle',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AddFriendScreen(),
                fullscreenDialog: true),
          ),
        ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B40F0).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.subtitle,
  });
  final IconData icon;
  final String message;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2), width: 1.5),
              ),
              child: Icon(icon,
                  color: Colors.white.withValues(alpha: 0.5), size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
