import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_l10n.dart';
import '../../domain/entities/chat_user_entity.dart';
import '../../ui/widgets/glass_widgets.dart';
import '../auth/auth_provider.dart';
import 'blocked_users_provider.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(appL10nProvider);
    final user = ref.watch(currentUserProvider);
    final blockedAsync = ref.watch(blockedUsersListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l.blockedUsers,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : blockedAsync.when(
              data: (users) {
                if (users.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.block_outlined,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l.noBlockedUsers,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l.noBlockedUsersSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 108, 16, 120),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final u = users[index];
                    return _BlockedUserTile(
                      user: u,
                      unblockLabel: l.unblock,
                      onUnblock: () => _unblock(ref, user.uid, u.uid, l),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Text(
                  l.errorLoadingBlocked,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ),
            ),
    );
  }

  Future<void> _unblock(
    WidgetRef ref,
    String myUid,
    String blockedUid,
    AppL10n l,
  ) async {
    await ref.read(blockedUsersStorageProvider).unblockUser(myUid, blockedUid);
    ref.invalidate(blockedUsersListProvider);
    ref.invalidate(blockedUserIdsProvider(myUid));
    ref.invalidate(myInvisibleUserIdsProvider);
    if (ref.context.mounted) {
      ScaffoldMessenger.of(ref.context).showSnackBar(
        SnackBar(content: Text(l.unblockSuccess)),
      );
    }
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.user,
    required this.unblockLabel,
    required this.onUnblock,
  });

  final ChatUserEntity user;
  final String unblockLabel;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(user.avatarColorHex);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color,
              child: Text(
                user.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (user.userCode.isNotEmpty)
                    Text(
                      user.userCode,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: onUnblock,
              child: Text(
                unblockLabel,
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF8B40F0);
    }
  }
}
