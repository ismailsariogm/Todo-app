import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:todo_note/data/repositories/project_repository.dart';
import 'package:todo_note/domain/entities/chat_user_entity.dart';
import 'package:todo_note/features/auth/auth_provider.dart';
import 'package:todo_note/features/chat/chat_provider.dart';
import 'package:todo_note/features/collaboration/group_form_shared.dart';
import 'package:todo_note/features/tasks/widgets/home_background.dart';

/// Topluluk grubu formu — Grup formu ile aynı + en fazla 10 alt grup.
class CommunityGroupFormScreen extends ConsumerStatefulWidget {
  const CommunityGroupFormScreen({super.key});

  @override
  ConsumerState<CommunityGroupFormScreen> createState() =>
      _CommunityGroupFormScreenState();
}

class _CommunityGroupFormScreenState
    extends ConsumerState<CommunityGroupFormScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _colorHex = '#6366F1';
  Uint8List? _groupImageBytes;
  bool _loading = false;

  final List<MemberRole> _selectedMembers = [];
  final List<TextEditingController> _subGroupNameCtrls = [];
  final List<Uint8List?> _subGroupPhotos = [];
  final Map<int, List<MemberRole>> _subGroupMembers = {};

  bool get _canCreate {
    if (_nameCtrl.text.trim().isEmpty) return false;
    return _selectedMembers.every((m) => m.role != null);
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _subGroupNameCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _groupImageBytes = bytes);
  }

  void _addSubGroup() {
    if (_subGroupNameCtrls.length >= 10) return;
    setState(() {
      final ctrl = TextEditingController();
      ctrl.addListener(() => setState(() {}));
      _subGroupNameCtrls.add(ctrl);
      _subGroupPhotos.add(null);
    });
  }

  void _removeSubGroup(int index) {
    setState(() {
      _subGroupNameCtrls[index].dispose();
      _subGroupNameCtrls.removeAt(index);
      _subGroupPhotos.removeAt(index);
      final newMap = <int, List<MemberRole>>{};
      for (final e in _subGroupMembers.entries) {
        if (e.key < index) newMap[e.key] = e.value;
        else if (e.key > index) newMap[e.key - 1] = e.value;
      }
      _subGroupMembers.clear();
      _subGroupMembers.addAll(newMap);
    });
  }

  Future<void> _pickSubGroupImage(int index) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      while (_subGroupPhotos.length <= index) _subGroupPhotos.add(null);
      if (index < _subGroupPhotos.length) {
        _subGroupPhotos[index] = bytes;
      }
    });
  }

  void _showSubGroupMemberSheet(int index) {
    final subName = index < _subGroupNameCtrls.length
        ? _subGroupNameCtrls[index].text.trim()
        : 'Alt grup ${index + 1}';
    final members = _subGroupMembers[index] ?? [];
    final friends = ref.read(friendsStreamProvider).valueOrNull ?? [];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubGroupMemberSheet(
        subGroupLabel: subName.isEmpty ? 'Alt grup ${index + 1}' : subName,
        friends: friends,
        members: List.from(members),
        onSave: (updated) {
          setState(() => _subGroupMembers[index] = updated);
        },
      ),
    );
  }

  Future<void> _shareViaWhatsApp() async {
    final name =
        _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Topluluğumuz';
    final text = Uri.encodeComponent(
      '🎯 $name topluluk grubuna katılmak ister misin?\n'
      'Todo Note uygulamasını indirerek bizimle çalışmaya başla!\n'
      '📲 Uygulama linki: http://localhost:8080',
    );
    final url = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp açılamadı'), duration: Duration(seconds: 3)),
      );
    }
  }

  Future<void> _shareViaInstagram() async {
    final url = Uri.parse('https://www.instagram.com/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instagram açılamadı'), duration: Duration(seconds: 3)),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    if (_selectedMembers.any((m) => m.role == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tüm üyeler için bir rol seçiniz.'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = ref.read(currentUserProvider)!;
      final repo = ref.read(projectRepositoryProvider);

      final photoB64 =
          _groupImageBytes != null ? base64Encode(_groupImageBytes!) : null;

      // 1. Topluluk grubunu oluştur
      final community = await repo.createProject(
        ownerId: user.uid,
        name: name,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        isShared: true,
        colorHex: _colorHex,
        photoBase64: photoB64,
        isCommunityGroup: true,
      );

      // 2. Sahibi yönetici olarak ekle
      await repo.addMember(
        groupId: community.id,
        userId: user.uid,
        email: user.email,
        displayName: user.displayName,
        role: 'yonetici',
      );

      // 3. Seçili üyeleri ekle
      for (final m in _selectedMembers) {
        await repo.addMember(
          groupId: community.id,
          userId: m.friend.uid,
          email: m.friend.email,
          displayName: m.friend.displayName,
          role: m.role!,
        );
      }

      // 4. Alt grupları oluştur (en fazla 10)
      for (var i = 0; i < _subGroupNameCtrls.length; i++) {
        final ctrl = _subGroupNameCtrls[i];
        final subName = ctrl.text.trim();
        if (subName.isEmpty) continue;

        final subPhotoB64 = (i < _subGroupPhotos.length && _subGroupPhotos[i] != null)
            ? base64Encode(_subGroupPhotos[i]!)
            : photoB64;
        final subMembers = _subGroupMembers[i] ?? _selectedMembers;

        final subGroup = await repo.createProject(
          ownerId: user.uid,
          name: subName,
          description: null,
          isShared: true,
          colorHex: _colorHex,
          photoBase64: subPhotoB64,
          parentCommunityId: community.id,
        );

        await repo.addMember(
          groupId: subGroup.id,
          userId: user.uid,
          email: user.email,
          displayName: user.displayName,
          role: 'yonetici',
        );

        for (final m in subMembers) {
          if (m.role == null) continue;
          await repo.addMember(
            groupId: subGroup.id,
            userId: m.friend.uid,
            email: m.friend.email,
            displayName: m.friend.displayName,
            role: m.role!,
          );
        }
      }

      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsStreamProvider).valueOrNull ?? [];
    final groupColor = Color(int.parse(_colorHex.replaceFirst('#', '0xFF')));
    final groupName = _nameCtrl.text.trim();
    final hasUnroled = _selectedMembers.any((m) => m.role == null);

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
              'Yeni Topluluk Grubu Oluştur',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            actions: [
              _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : TextButton(
                      onPressed: (_canCreate && !hasUnroled) ? _save : null,
                      child: Text(
                        'Oluştur',
                        style: TextStyle(
                          color: (_canCreate && !hasUnroled)
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Grup fotoğrafı + renk (GroupFormScreen ile aynı)
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: groupColor,
                              boxShadow: [
                                BoxShadow(
                                    color: groupColor.withValues(alpha: 0.50),
                                    blurRadius: 18),
                              ],
                              image: _groupImageBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(_groupImageBytes!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _groupImageBytes == null
                                ? Center(
                                    child: Text(
                                      groupName.isNotEmpty
                                          ? groupName[0].toUpperCase()
                                          : 'T',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)]),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.50),
                                    width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Text(
                        _groupImageBytes != null
                            ? 'Fotoğrafı Değiştir'
                            : 'Galeriden Fotoğraf Ekle',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white.withValues(alpha: 0.40)),
                      ),
                    ),
                    if (_groupImageBytes != null) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => setState(() => _groupImageBytes = null),
                        child: Text(
                          'Fotoğrafı Kaldır',
                          style: TextStyle(
                              color: Colors.red.shade300, fontSize: 11),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              GlassField(
                  controller: _nameCtrl,
                  label: 'Topluluk Adı',
                  icon: Icons.groups_rounded),
              const SizedBox(height: 12),
              GlassField(
                  controller: _descCtrl,
                  label: 'Açıklama (opsiyonel)',
                  icon: Icons.description_outlined,
                  maxLines: 2),
              const SizedBox(height: 24),
              SectionLabel('Grup Rengi'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kGroupColorOptions.map((hex) {
                  final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                  final sel = _colorHex == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: sel
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                    color: c.withValues(alpha: 0.60),
                                    blurRadius: 10)
                              ]
                            : null,
                      ),
                      child: sel
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              SectionLabel('Üye Ekle'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.amber.shade300, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Her üye için bir rol seçilmeden topluluk oluşturulamaz.',
                        style: TextStyle(
                            color: Colors.amber.shade200, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              if (friends.isEmpty)
                GlassInfo(
                    icon: Icons.person_add_outlined,
                    text: 'Henüz arkadaşınız yok. Önce arkadaş ekleyin.')
              else
                ...friends.map((friend) {
                  final existing = _selectedMembers
                      .where((m) => m.friend.uid == friend.uid)
                      .firstOrNull;
                  final isSelected = existing != null;
                  return FriendRoleTile(
                    friend: friend,
                    isSelected: isSelected,
                    selectedRole: existing?.role,
                    onToggle: () {
                      setState(() {
                        if (isSelected) {
                          _selectedMembers
                              .removeWhere((m) => m.friend.uid == friend.uid);
                        } else {
                          _selectedMembers.add(MemberRole(friend));
                        }
                      });
                    },
                    onRoleChanged: (role) {
                      setState(() {
                        if (!isSelected) {
                          _selectedMembers
                              .add(MemberRole(friend)..role = role);
                        } else {
                          existing!.role = role;
                        }
                      });
                    },
                  );
                }),
              if (hasUnroled)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GlassInfo(
                    icon: Icons.warning_amber_rounded,
                    text: 'Seçili tüm üyeler için rol belirlemeniz gerekiyor.',
                    isWarning: true,
                  ),
                ),
              const SizedBox(height: 28),

              // ─── Alt Gruplar (En fazla 10) ─────────────────────────────────
              SectionLabel('Alt Gruplar (En fazla 10)'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Topluluk içinde en fazla 10 alt grup oluşturabilirsiniz. Her alt grup, üyeler ve görevler için ayrı bir alan olacaktır.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ..._subGroupNameCtrls.asMap().entries.map((e) {
                      final idx = e.key;
                      final hasPhoto = idx < _subGroupPhotos.length &&
                          _subGroupPhotos[idx] != null;
                      final memberCount =
                          (_subGroupMembers[idx] ?? _selectedMembers)
                              .where((m) => m.role != null)
                              .length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _pickSubGroupImage(idx),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.22)),
                                  image: hasPhoto
                                      ? DecorationImage(
                                          image: MemoryImage(_subGroupPhotos[idx]!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: hasPhoto
                                    ? null
                                    : Icon(Icons.photo_library_outlined,
                                        color: Colors.white.withValues(alpha: 0.6),
                                        size: 22),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.22)),
                                ),
                                child: TextField(
                                  controller: e.value,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Alt grup ${e.key + 1}',
                                    hintStyle: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5)),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Üye ve rol ekle',
                              child: IconButton(
                                onPressed: () => _showSubGroupMemberSheet(idx),
                                icon: Badge(
                                  isLabelVisible: memberCount > 0,
                                  label: Text('$memberCount',
                                      style: const TextStyle(fontSize: 10)),
                                  child: Icon(Icons.group_add_outlined,
                                      color: Colors.white.withValues(alpha: 0.85),
                                      size: 22),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeSubGroup(e.key),
                              icon: Icon(Icons.remove_circle_outline,
                                  color: Colors.red.shade300, size: 24),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (_subGroupNameCtrls.length < 10)
                      TextButton.icon(
                        onPressed: _addSubGroup,
                        icon: const Icon(Icons.add,
                            color: Color(0xFF8B40F0), size: 20),
                        label: const Text(
                          'Alt Grup Ekle',
                          style: TextStyle(
                              color: Color(0xFF8B40F0),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              SectionLabel('Topluluğa Davet Et'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Arkadaşlarını topluluğa davet etmek için sosyal medyada paylaş:',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ShareButton(
                            label: 'WhatsApp',
                            icon: Icons.chat_rounded,
                            gradient: const LinearGradient(
                                colors: [Color(0xFF25D366), Color(0xFF128C7E)]),
                            onTap: _shareViaWhatsApp,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ShareButton(
                            label: 'Instagram',
                            icon: Icons.camera_rounded,
                            gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFE1306C),
                                  Color(0xFFC13584),
                                  Color(0xFF833AB4),
                                ]),
                            onTap: _shareViaInstagram,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }
}

/// Alt grup için üye ve rol seçim sayfası (bottom sheet).
class _SubGroupMemberSheet extends StatefulWidget {
  const _SubGroupMemberSheet({
    required this.subGroupLabel,
    required this.friends,
    required this.members,
    required this.onSave,
  });

  final String subGroupLabel;
  final List<ChatUserEntity> friends;
  final List<MemberRole> members;
  final void Function(List<MemberRole>) onSave;

  @override
  State<_SubGroupMemberSheet> createState() => _SubGroupMemberSheetState();
}

class _SubGroupMemberSheetState extends State<_SubGroupMemberSheet> {
  late List<MemberRole> _members;

  @override
  void initState() {
    super.initState();
    _members = widget.members.map((m) => MemberRole(m.friend)..role = m.role).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasUnroled = _members.any((m) => m.role == null);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1B2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.group_rounded,
                    color: Colors.white.withValues(alpha: 0.8), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.subGroupLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Üye ve rol tanımla',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: hasUnroled
                      ? null
                      : () {
                          widget.onSave(_members);
                          Navigator.of(context).pop();
                        },
                  child: Text(
                    'Kaydet',
                    style: TextStyle(
                      color: hasUnroled
                          ? Colors.white.withValues(alpha: 0.35)
                          : const Color(0xFF8B40F0),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.friends.isEmpty)
                  GlassInfo(
                    icon: Icons.person_add_outlined,
                    text: 'Henüz arkadaşınız yok.',
                  )
                else
                  ...widget.friends.map((friend) {
                    final existing =
                        _members.where((m) => m.friend.uid == friend.uid).firstOrNull;
                    final isSelected = existing != null;
                    return FriendRoleTile(
                      friend: friend,
                      isSelected: isSelected,
                      selectedRole: existing?.role,
                      onToggle: () {
                        setState(() {
                          if (isSelected) {
                            _members.removeWhere((m) => m.friend.uid == friend.uid);
                          } else {
                            _members.add(MemberRole(friend));
                          }
                        });
                      },
                      onRoleChanged: (role) {
                        setState(() {
                          if (!isSelected) {
                            _members.add(MemberRole(friend)..role = role);
                          } else {
                            existing!.role = role;
                          }
                        });
                      },
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
