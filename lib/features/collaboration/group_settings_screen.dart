import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:todo_note/app/router.dart';
import 'package:todo_note/data/repositories/chat_repository.dart';
import 'package:todo_note/data/repositories/project_repository.dart';
import 'package:todo_note/domain/entities/chat_user_entity.dart';
import 'package:todo_note/domain/entities/project_entity.dart';
import 'package:todo_note/domain/group_permissions.dart';
import 'package:todo_note/features/auth/auth_provider.dart';
import 'package:todo_note/features/chat/chat_provider.dart';
import 'package:todo_note/features/tasks/providers/tasks_provider.dart';
import 'package:todo_note/features/tasks/providers/tasks_provider.dart'
    show sharedGroupsProvider, sharedCommunityGroupsProvider, projectByIdProvider;
import 'package:todo_note/features/collaboration/image_crop_screen.dart';
import 'package:todo_note/features/tasks/widgets/home_background.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  late TextEditingController _nameCtrl;
  String? _selectedColorHex;
  bool _saving = false;

  static const _colorOptions = [
    '#6366F1', '#0EA5E9', '#10B981', '#F97316',
    '#EF4444', '#8B5CF6', '#EC4899', '#14B8A6',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    // Use stable top-level providers instead of inline StreamProvider
    final groupAsync = ref.watch(sharedGroupsProvider);
    final communityAsync = ref.watch(sharedCommunityGroupsProvider);
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final friends = ref.watch(friendsStreamProvider).valueOrNull ?? [];

    final projectAsync = ref.watch(projectByIdProvider(widget.groupId));
    final group = groupAsync.valueOrNull
            ?.where((p) => p.id == widget.groupId)
            .firstOrNull ??
        communityAsync.valueOrNull
            ?.where((p) => p.id == widget.groupId)
            .firstOrNull ??
        projectAsync.valueOrNull;

    // Sync name field with group name when group first loads
    if (group != null && _nameCtrl.text.isEmpty) {
      _nameCtrl.text = group.name;
      _selectedColorHex ??= group.colorHex;
    } else if (group != null) {
      _selectedColorHex ??= group.colorHex;
    }

    final members = membersAsync.valueOrNull ?? [];
    final myRole = members
        .where((m) => m.userId == user?.uid)
        .map((m) => m.role)
        .firstOrNull;
    final canEdit = GroupPermissions.canEditGroupInfo(myRole);
    final canEditPhoto = GroupPermissions.canEditGroupPhoto(myRole);
    final canInvite = GroupPermissions.canInvite(myRole);
    final canDeleteGroup = GroupPermissions.canDeleteGroup(myRole);

    final groupColor = Color(
      int.parse(
          (_selectedColorHex ?? group?.colorHex ?? '#6366F1')
              .replaceFirst('#', '0xFF')),
    );

    // Loading state: show spinner until group and members are available
    final isLoading = (group == null &&
            (groupAsync.isLoading ||
                communityAsync.isLoading ||
                projectAsync.isLoading)) ||
        membersAsync.isLoading;
    final hasError = groupAsync.hasError || membersAsync.hasError;
    if (isLoading && group == null && members.isEmpty) {
      return Stack(
        children: [
          const HomeBackground(),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              surfaceTintColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              title: const Text(
                'Grup Ayarları',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      );
    }
    // Group not found after loading (e.g. user removed from group)
    final groupsLoaded = !groupAsync.isLoading &&
        !communityAsync.isLoading &&
        !projectAsync.isLoading;
    if (groupsLoaded &&
        group == null &&
        (groupAsync.valueOrNull != null ||
            communityAsync.valueOrNull != null ||
            projectAsync.valueOrNull != null)) {
      return Stack(
        children: [
          const HomeBackground(),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              surfaceTintColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              title: const Text(
                'Grup Ayarları',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_off,
                        size: 48, color: Colors.white.withValues(alpha: 0.7)),
                    const SizedBox(height: 16),
                    Text(
                      'Grup bulunamadı veya erişim yetkiniz yok.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (hasError) {
      return Stack(
        children: [
          const HomeBackground(),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              surfaceTintColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              title: const Text(
                'Grup Ayarları',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.white.withValues(alpha: 0.7)),
                    const SizedBox(height: 16),
                    Text(
                      'Grup bilgileri yüklenirken hata oluştu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        const HomeBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              'Grup Ayarları',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
            actions: [
              if (canEdit)
                _saving
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : TextButton(
                        onPressed: () => _saveGroupInfo(group),
                        child: const Text(
                          'Kaydet',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 100),
            children: [
              // ── Group avatar + name ────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: canEditPhoto ? () => _pickProfilePhoto(group) : null,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: groupColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: groupColor.withValues(alpha: 0.45),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: group != null &&
                                    group!.photoBase64 != null &&
                                    group!.photoBase64!.isNotEmpty
                                ? ClipOval(
                                    child: Image.memory(
                                      base64Decode(group!.photoBase64!),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      _nameCtrl.text.isNotEmpty
                                          ? _nameCtrl.text[0].toUpperCase()
                                          : 'G',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                          ),
                          if (canEditPhoto)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B40F0),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (canEditPhoto) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Profil fotoğrafı değiştirmek için dokunun',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 12,
                        ),
                      ),
                      if (group != null &&
                          group!.photoBase64 != null &&
                          group!.photoBase64!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => _removeProfilePhoto(group),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                          ),
                          child: const Text('Profil fotoğrafını kaldır'),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // ── Grup Adı ──────────────────────────────────────────────────
              _SectionLabel('Grup Adı'),
              const SizedBox(height: 8),
              _GlassTextField(
                controller: _nameCtrl,
                hint: 'Grup adı girin...',
                enabled: canEdit,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              // ── Renk (sadece yönetici) ─────────────────────────────────────
              if (canEdit) ...[
                _SectionLabel('Grup Rengi'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: _colorOptions.map((hex) {
                    final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                    final sel = _selectedColorHex == hex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColorHex = hex),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: sel
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                      color: c.withValues(alpha: 0.55),
                                      blurRadius: 8)
                                ]
                              : null,
                        ),
                        child: sel
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
              ],

              // ── Members ───────────────────────────────────────────────────
              _SectionLabel('Grup Üyeleri (${members.length})'),
              const SizedBox(height: 8),
              if (members.isEmpty && !membersAsync.isLoading)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    'Henüz üye yok.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 14,
                    ),
                  ),
                )
              else
                ...members.map((m) => _MemberTile(
                    member: m,
                    isMe: m.userId == user?.uid,
                    canChangeRole: GroupPermissions.canChangeRoles(myRole) &&
                        m.userId != user?.uid,
                    canRemove: GroupPermissions.canRemoveMember(
                        myRole, m.role) &&
                        m.userId != user?.uid,
                    onRoleChanged: GroupPermissions.canChangeRoles(myRole) &&
                            m.userId != user?.uid
                        ? (newRole) => _changeRole(m.userId, m.email,
                            m.displayName, newRole)
                        : null,
                    onRemove: GroupPermissions.canRemoveMember(myRole, m.role) &&
                            m.userId != user?.uid
                        ? () => _removeMember(m.userId)
                        : null,
                    onLongPress: () => _showMemberPanel(context, m),
                  )),

              const SizedBox(height: 24),

              // ── Davet seçenekleri (WhatsApp, Instagram) ───────────────────
              if (canInvite) ...[
                _SectionLabel('Davet Seçenekleri'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _InviteOptionTile(
                        icon: Icons.chat,
                        label: 'WhatsApp',
                        color: const Color(0xFF25D366),
                        onTap: () => _inviteViaWhatsApp(group?.name ?? 'Grup'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InviteOptionTile(
                        icon: Icons.camera_alt,
                        label: 'Instagram',
                        color: const Color(0xFFE4405F),
                        onTap: () => _inviteViaInstagram(group?.name ?? 'Grup'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionLabel('Gruba Davet Et'),
                const SizedBox(height: 8),
                _InviteSection(
                  friends: friends,
                  existingMemberIds: members.map((m) => m.userId).toList(),
                  onInvite: (friend, role) =>
                      _inviteFriend(friend, role),
                ),
                const SizedBox(height: 28),
              ],

              // ── Gruptan Çık ─────────────────────────────────────────────────
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _confirmLeaveGroup(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded,
                          color: Color(0xFFF59E0B), size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'Gruptan Çık',
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Grubu Sil (sadece Yönetici) ─────────────────────────────────
              if (canDeleteGroup)
                GestureDetector(
                  onTap: () => _confirmDeleteGroup(),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.40)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.delete_forever_rounded,
                            color: Color(0xFFEF4444), size: 22),
                        const SizedBox(width: 12),
                        Text(
                          'Grubu Sil',
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _postSettingsChange(String changeDescription) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final members = ref.read(groupMembersProvider(widget.groupId)).valueOrNull ?? [];
    final myRole = members
        .where((m) => m.userId == user.uid)
        .map((m) => m.role)
        .firstOrNull ?? 'uye';
    await ChatRepository.instance.sendGroupSettingsChange(
      groupId: widget.groupId,
      userName: user.displayName,
      userRole: myRole,
      changeDescription: changeDescription,
      ownerUid: user.uid,
      participantUids: members.map((m) => m.userId).toList(),
    );
  }

  Future<void> _removeProfilePhoto(ProjectEntity group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Profil Fotoğrafını Kaldır'),
        content: const Text(
          'Grup profil fotoğrafını kaldırmak istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaldır',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(projectRepositoryProvider).updateProject(
          group.id,
          removePhoto: true,
        );
    if (mounted) {
      await _postSettingsChange('Grup profil fotoğrafını kaldıran');
      ref.invalidate(sharedGroupsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil fotoğrafı kaldırıldı'),
          duration: Duration(seconds: 3),
        ),
      );
      setState(() {});
    }
  }

  Future<void> _pickProfilePhoto(ProjectEntity? group) async {
    if (group == null) return;
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (xfile == null || !mounted) return;
      final bytes = await xfile.readAsBytes();
      if (!mounted) return;
      final hadPhoto = group.photoBase64 != null && group.photoBase64!.isNotEmpty;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImageCropScreen(
            imageBytes: bytes,
            onCropComplete: (cropped) async {
              final b64 = base64Encode(cropped);
              await ref.read(projectRepositoryProvider).updateProject(
                group.id,
                photoBase64: b64,
              );
              if (mounted) {
                await _postSettingsChange(
                  hadPhoto
                      ? 'Grup profil fotoğrafını güncelleyen'
                      : 'Grup profil fotoğrafını ekleyen',
                );
                ref.invalidate(sharedGroupsProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profil fotoğrafı güncellendi'),
                    duration: Duration(seconds: 3),
                  ),
                );
                setState(() {});
              }
            },
          ),
        ),
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _saveGroupInfo(ProjectEntity? group) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || group == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(projectRepositoryProvider).updateProject(
            group.id,
            name: name,
            colorHex: _selectedColorHex,
          );
      if (mounted) {
        await _postSettingsChange('Grup bilgilerini (ad/renk) güncelleyen');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grup bilgileri güncellendi'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeRole(
      String userId, String email, String displayName, String role) async {
    await ref.read(projectRepositoryProvider).addMember(
          groupId: widget.groupId,
          userId: userId,
          email: email,
          displayName: displayName,
          role: role,
        );
    if (mounted) {
      await _postSettingsChange(
        '$displayName kullanıcısının rolünü değiştiren',
      );
    }
  }

  Future<void> _removeMember(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Üyeyi Çıkar'),
        content: const Text('Bu üyeyi gruptan çıkarmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Çıkar',
                  style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );
    if (confirmed == true) {
      final memberName = ref
              .read(groupMembersProvider(widget.groupId))
              .valueOrNull
              ?.where((m) => m.userId == userId)
              .map((m) => m.displayName)
              .firstOrNull ??
          'Üye';
      await ref
          .read(projectRepositoryProvider)
          .removeMember(widget.groupId, userId);
      if (mounted) {
        await _postSettingsChange('$memberName üyesini gruptan çıkaran');
      }
    }
  }

  Future<void> _inviteFriend(ChatUserEntity friend, String role) async {
    await ref.read(projectRepositoryProvider).addMember(
          groupId: widget.groupId,
          userId: friend.uid,
          email: friend.email,
          displayName: friend.displayName,
          role: role,
        );
    if (mounted) {
      await _postSettingsChange('${friend.displayName} üyesini gruba ekleyen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${friend.displayName} gruba eklendi'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showMemberPanel(BuildContext context, GroupMemberEntity member) {
    final roleLabel = switch (member.role) {
      'yonetici' || 'owner' => 'Yönetici',
      'kıdemli' => 'Kıdemli',
      _ => 'Üye',
    };
    final roleDesc = GroupPermissions.roleDescription(member.role);
    final roleColor = switch (member.role) {
      'yonetici' || 'owner' => const Color(0xFFEF4444),
      'kıdemli' => const Color(0xFFF59E0B),
      _ => const Color(0xFF10B981),
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0533),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 40,
                backgroundColor: roleColor.withValues(alpha: 0.70),
                child: Text(
                  member.displayName.isNotEmpty
                      ? member.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                member.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                member.email,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: roleColor.withValues(alpha: 0.55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.badge_rounded, color: roleColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Aktif Rol: $roleLabel',
                      style: TextStyle(
                        color: roleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                roleDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLeaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Gruptan Çık'),
        content: const Text(
          'Gruptan çıkmak istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Çık',
                  style: TextStyle(color: Color(0xFFF59E0B)))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final user = ref.read(currentUserProvider);
      await ref.read(projectRepositoryProvider).removeMember(
            widget.groupId, user?.uid ?? '');
      if (mounted) context.pop();
    }
  }

  Future<void> _confirmDeleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Grubu Sil'),
        content: const Text(
          'Grubu silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Grubu Sil',
                  style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(projectRepositoryProvider).deleteProject(widget.groupId);
      if (mounted) context.pop();
    }
  }

  Future<void> _inviteViaWhatsApp(String groupName) async {
    final inviteUrl =
        '${Uri.base.origin}/#${AppRoutes.groupDetail}/${widget.groupId}';
    final text = Uri.encodeComponent(
        '$groupName grubuna katıl: $inviteUrl');
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp açılamadı'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _inviteViaInstagram(String groupName) async {
    final inviteUrl =
        '${Uri.base.origin}/#${AppRoutes.groupDetail}/${widget.groupId}';
    final text = '$groupName grubuna katıl: $inviteUrl';
    await _copyToClipboard(text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Davet linki kopyalandı. Instagram\'da paylaşabilirsiniz.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}

// ─── Member tile with role selector ──────────────────────────────────────────

class _MemberTile extends StatefulWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.canChangeRole,
    required this.canRemove,
    this.onRoleChanged,
    this.onRemove,
    this.onLongPress,
  });

  final GroupMemberEntity member;
  final bool isMe;
  final bool canChangeRole;
  final bool canRemove;
  final ValueChanged<String>? onRoleChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onLongPress;

  @override
  State<_MemberTile> createState() => _MemberTileState();
}

class _MemberTileState extends State<_MemberTile> {
  bool _expanded = false;

  static const _roles = [
    (value: 'yonetici', label: 'Yönetici', color: Color(0xFFEF4444)),
    (value: 'kıdemli',  label: 'Kıdemli',  color: Color(0xFFF59E0B)),
    (value: 'uye',      label: 'Üye',      color: Color(0xFF10B981)),
  ];

  String get _roleLabel => switch (widget.member.role) {
        'yonetici' || 'owner' => 'Yönetici',
        'kıdemli' => 'Kıdemli',
        _ => 'Üye',
      };

  Color get _roleColor => switch (widget.member.role) {
        'yonetici' || 'owner' => const Color(0xFFEF4444),
        'kıdemli' => const Color(0xFFF59E0B),
        _ => const Color(0xFF10B981),
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            GestureDetector(
              onLongPress: widget.onLongPress,
              child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: _roleColor.withValues(alpha: 0.70),
                child: Text(
                  widget.member.displayName.isNotEmpty
                      ? widget.member.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.member.displayName +
                          (widget.isMe ? ' (Ben)' : ''),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _roleColor.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: _roleColor.withValues(alpha: 0.55)),
                    ),
                    child: Text(
                      _roleLabel,
                      style: TextStyle(
                          color: _roleColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                widget.member.email,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
              ),
              trailing: widget.canChangeRole && widget.onRoleChanged != null
                  ? IconButton(
                      icon: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                      onPressed: () => setState(() => _expanded = !_expanded),
                    )
                  : null,
            ),
            ),

            // Role picker (expanded)
            if (_expanded && widget.canChangeRole && widget.onRoleChanged != null) ...[
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.15)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rol Değiştir:',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: _roles.map((opt) {
                        final active = widget.member.role == opt.value ||
                            (opt.value == 'yonetici' &&
                                widget.member.role == 'owner');
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              widget.onRoleChanged!(opt.value);
                              setState(() => _expanded = false);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: active
                                    ? opt.color.withValues(alpha: 0.85)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: active
                                        ? opt.color
                                        : Colors.white.withValues(alpha: 0.20)),
                              ),
                              child: Text(
                                opt.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: active
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (widget.canRemove && widget.onRemove != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: widget.onRemove,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.40)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_remove_outlined,
                                  color: Color(0xFFEF4444), size: 16),
                              SizedBox(width: 6),
                              Text('Gruptan Çıkar',
                                  style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Invite section ───────────────────────────────────────────────────────────

class _InviteSection extends StatefulWidget {
  const _InviteSection({
    required this.friends,
    required this.existingMemberIds,
    required this.onInvite,
  });

  final List<ChatUserEntity> friends;
  final List<String> existingMemberIds;
  final void Function(ChatUserEntity friend, String role) onInvite;

  @override
  State<_InviteSection> createState() => _InviteSectionState();
}

class _InviteSectionState extends State<_InviteSection> {
  final Map<String, String?> _pendingRoles = {};

  static const _roles = [
    (value: 'yonetici', label: 'Yönetici', color: Color(0xFFEF4444)),
    (value: 'kıdemli',  label: 'Kıdemli',  color: Color(0xFFF59E0B)),
    (value: 'uye',      label: 'Üye',      color: Color(0xFF10B981)),
  ];

  List<ChatUserEntity> get _invitable => widget.friends
      .where((f) => !widget.existingMemberIds.contains(f.uid))
      .toList();

  @override
  Widget build(BuildContext context) {
    if (_invitable.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Text(
          'Tüm arkadaşlarınız zaten grupta.',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60), fontSize: 13),
        ),
      );
    }

    return Column(
      children: _invitable.map((friend) {
        final avatarColor =
            Color(int.parse(friend.avatarColorHex.replaceFirst('#', '0xFF')));
        final role = _pendingRoles[friend.uid];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: avatarColor.withValues(alpha: 0.80),
                    child: Text(friend.initials,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  title: Text(friend.displayName,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(friend.email,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12)),
                ),
                // Role + invite button
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rol Seç:',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ..._roles.map((opt) {
                            final active = role == opt.value;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _pendingRoles[friend.uid] = opt.value),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 7),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? opt.color.withValues(alpha: 0.80)
                                        : Colors.white.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: active
                                            ? opt.color
                                            : Colors.white
                                                .withValues(alpha: 0.20)),
                                  ),
                                  child: Text(
                                    opt.label,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: active
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.70),
                                      fontSize: 11,
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: role == null
                                ? null
                                : () {
                                    widget.onInvite(friend, role);
                                    setState(() =>
                                        _pendingRoles.remove(friend.uid));
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: role == null
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFF8B40F0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Ekle',
                                style: TextStyle(
                                  color: role == null
                                      ? Colors.white.withValues(alpha: 0.35)
                                      : Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Invite option tile (WhatsApp, Instagram) ─────────────────────────────────

class _InviteOptionTile extends StatelessWidget {
  const _InviteOptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.controller,
    required this.hint,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: enabled ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: TextStyle(
            color:
                enabled ? Colors.white : Colors.white.withValues(alpha: 0.50)),
        cursorColor: Colors.white,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.white.withValues(alpha: 0.45)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}
