import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/chat_user_entity.dart';
import '../../tasks/widgets/home_background.dart';
import '../chat_provider.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _selectedMembers = <ChatUserEntity>[];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Grup adı boş olamaz');
      return;
    }
    if (_selectedMembers.isEmpty) {
      setState(() => _error = 'En az bir üye seçin');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final conv = await ref.read(chatActionsProvider).createGroup(
          groupName: name,
          members: _selectedMembers,
        );

    if (mounted) {
      setState(() => _loading = false);
      if (conv != null) {
        Navigator.pop(context, conv);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(filteredFriendsProvider);

    return Stack(
      children: [
        const HomeBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Grup Oluştur',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: _loading ? null : _create,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Oluştur',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group icon preview
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF8B40F0).withValues(alpha: 0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.group, color: Colors.white, size: 38),
                  ),
                ),
                const SizedBox(height: 28),

                // Group name
                Text(
                  'Grup Adı',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Ör. Proje Grubu',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4)),
                      prefixIcon: Icon(Icons.edit_outlined,
                          color: Colors.white.withValues(alpha: 0.6), size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFCF4DA6), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _error!,
                        style: const TextStyle(
                            color: Color(0xFFCF4DA6), fontSize: 13),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 28),

                // Member selection
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Üye Seç',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_selectedMembers.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B40F0).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedMembers.length} seçili',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                friendsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  ),
                  error: (e, _) => Text(e.toString(),
                      style: const TextStyle(color: Colors.white70)),
                  data: (friends) {
                    if (friends.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Center(
                          child: Text(
                            'Önce arkadaş eklemen gerekiyor',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: friends.map((f) {
                        final selected = _selectedMembers.any((m) => m.uid == f.uid);
                        return _MemberTile(
                          user: f,
                          selected: selected,
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedMembers.removeWhere(
                                    (m) => m.uid == f.uid);
                              } else {
                                _selectedMembers.add(f);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final ChatUserEntity user;
  final bool selected;
  final VoidCallback onTap;

  Color _parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF8B40F0).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF8B40F0).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _parseHex(user.avatarColorHex),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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
                    user.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    user.userCode,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)],
                      )
                    : null,
                color: selected ? null : Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
