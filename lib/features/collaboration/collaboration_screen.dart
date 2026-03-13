import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:todo_note/app/router.dart';
import 'package:todo_note/data/repositories/project_repository.dart'
    show projectRepositoryProvider, WebProjectRepository;
import 'package:todo_note/domain/entities/project_entity.dart';
import 'package:todo_note/features/auth/auth_provider.dart';
import 'package:todo_note/features/collaboration/group_badge_widget.dart';
import 'package:todo_note/features/tasks/providers/tasks_provider.dart'
    show communitySubGroupsProvider, sharedGroupsProvider,
        sharedCommunityGroupsProvider;
import 'package:todo_note/features/tasks/widgets/home_background.dart';

// Top-level family so Riverpod caches by groupId
final _groupMembersProvider = StreamProvider.family<List<GroupMemberEntity>, String>(
  (ref, groupId) => ref.watch(projectRepositoryProvider).watchGroupMembers(groupId),
);

class CollaborationScreen extends ConsumerStatefulWidget {
  const CollaborationScreen({super.key});

  @override
  ConsumerState<CollaborationScreen> createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends ConsumerState<CollaborationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WebProjectRepository.instance.init(forceReload: true);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(sharedGroupsProvider);
    final communityAsync = ref.watch(sharedCommunityGroupsProvider);

    return Stack(
      children: [
        const HomeBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Gruplarım',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                TotalGroupBadgesHeader(),
              ],
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Gruplarım'),
                Tab(text: 'Topluluk Grubu'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _GroupsTab(projectsAsync: groupsAsync),
              _CommunityGroupsTab(projectsAsync: communityAsync),
            ],
          ),
          floatingActionButton: _CreateGroupFabs(),
        ),
      ],
    );
  }
}

// ─── Gruplarım sekmesi ──────────────────────────────────────────────────────

class _GroupsTab extends StatelessWidget {
  const _GroupsTab({required this.projectsAsync});
  final AsyncValue<List<ProjectEntity>> projectsAsync;

  @override
  Widget build(BuildContext context) {
    return projectsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      error: (e, _) => Center(
        child: Text('Hata: $e',
            style: const TextStyle(color: Colors.white)),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.group_add_outlined,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.40),
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz grup yok',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aşağıdaki "Yeni Grup" butonu ile ilk grubunuzu oluşturun.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }
        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _GroupCard(group: groups[i]),
                  childCount: groups.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Topluluk Grubu sekmesi ──────────────────────────────────────────────────

class _CommunityGroupsTab extends StatelessWidget {
  const _CommunityGroupsTab({required this.projectsAsync});
  final AsyncValue<List<ProjectEntity>> projectsAsync;

  @override
  Widget build(BuildContext context) {
    return projectsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      error: (e, _) => Center(
        child: Text('Hata: $e',
            style: const TextStyle(color: Colors.white)),
      ),
      data: (communities) {
        if (communities.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.groups_outlined,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.40),
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz topluluk grubu yok',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aşağıdaki "Topluluk Grubu" butonu ile\nilk topluluğunuzu oluşturun.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }
        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _CommunityGroupCard(community: communities[i]),
                  childCount: communities.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Topluluk Grubu kartı ────────────────────────────────────────────────────

class _CommunityGroupCard extends ConsumerWidget {
  const _CommunityGroupCard({required this.community});
  final ProjectEntity community;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subGroupsAsync = ref.watch(communitySubGroupsProvider(community.id));
    final subCount = subGroupsAsync.valueOrNull?.length ?? 0;
    final groupColor =
        Color(int.parse(community.colorHex.replaceFirst('#', '0xFF')));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => context.push(
            '${AppRoutes.communityDetail}/${community.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: groupColor.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: groupColor.withValues(alpha: 0.40),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: community.photoBase64 != null &&
                        community.photoBase64!.isNotEmpty
                    ? ClipOval(
                        child: Image.memory(
                          base64Decode(community.photoBase64!),
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.groups_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (community.description != null &&
                        community.description!.isNotEmpty)
                      Text(
                        community.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.folder_outlined,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.60)),
                        const SizedBox(width: 4),
                        Text(
                          '$subCount alt grup',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.60),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.55)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Create Group FABs ───────────────────────────────────────────────────────

class _CreateGroupFabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => context.push(AppRoutes.communityGroupForm),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push(AppRoutes.groupForm),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B40F0).withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Group Card ───────────────────────────────────────────────────────────────

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group});
  final ProjectEntity group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final membersAsync = ref.watch(_groupMembersProvider(group.id));

    final groupColor =
        Color(int.parse(group.colorHex.replaceFirst('#', '0xFF')));

    final members = membersAsync.valueOrNull ?? [];
    final myRole = members
        .where((m) => m.userId == user?.uid)
        .map((m) => m.role)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () =>
            context.push('${AppRoutes.groupDetail}/${group.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar (profil fotoğrafı veya baş harf)
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: groupColor.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: groupColor.withValues(alpha: 0.40),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: group.photoBase64 != null &&
                        group.photoBase64!.isNotEmpty
                    ? ClipOval(
                        child: Image.memory(
                          base64Decode(group.photoBase64!),
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          group.name.isNotEmpty
                              ? group.name[0].toUpperCase()
                              : 'G',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (group.description != null &&
                        group.description!.isNotEmpty)
                      Text(
                        group.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.people_alt_outlined,
                            size: 14,
                            color:
                                Colors.white.withValues(alpha: 0.60)),
                        const SizedBox(width: 4),
                        Text(
                          '${members.length} üye',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.60),
                            fontSize: 12,
                          ),
                        ),
                        if (myRole != null) ...[
                          const SizedBox(width: 10),
                          _RoleBadge(role: myRole),
                        ],
                        const SizedBox(width: 8),
                        GroupCardBadges(groupId: group.id),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.55)),
            ],
          ),
        ),
      ),
    );
  }

}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      'yonetici' || 'owner' => ('Yönetici', const Color(0xFFEF4444)),
      'kıdemli' => ('Kıdemli', const Color(0xFFF59E0B)),
      _ => ('Üye', const Color(0xFF10B981)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
