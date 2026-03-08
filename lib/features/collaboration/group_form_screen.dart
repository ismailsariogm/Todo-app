import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:todo_note/data/repositories/project_repository.dart';
import 'package:todo_note/domain/entities/chat_user_entity.dart';
import 'package:todo_note/domain/entities/project_entity.dart';
import 'package:todo_note/features/auth/auth_provider.dart';
import 'package:todo_note/features/chat/chat_provider.dart';
import 'package:todo_note/features/collaboration/group_form_shared.dart';
import 'package:todo_note/features/tasks/widgets/home_background.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class GroupFormScreen extends ConsumerStatefulWidget {
  const GroupFormScreen({super.key, this.groupId});
  final String? groupId;

  @override
  ConsumerState<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends ConsumerState<GroupFormScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _colorHex = '#6366F1';
  Uint8List? _groupImageBytes;
  bool _loading = false;

  final List<MemberRole> _selectedMembers = [];

  bool get _isEdit => widget.groupId != null;

  bool get _canCreate {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_isEdit) return true;
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
    super.dispose();
  }

  // ── Grup fotoğrafı seç ───────────────────────────────────────────────────────
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

  // ── Davet gönder ─────────────────────────────────────────────────────────────
  Future<void> _shareViaWhatsApp() async {
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : 'Grubumuz';
    final text = Uri.encodeComponent(
      '🎯 $name grubuna katılmak ister misin?\n'
      'Todo Note uygulamasını indirerek bizimle çalışmaya başla!\n'
      '📲 Uygulama linki: http://localhost:8080',
    );
    final url = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp açılamadı'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _shareViaInstagram() async {
    // Instagram direct share — stories intent (mobile) veya profil (web)
    final url = Uri.parse('https://www.instagram.com/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Instagram açılamadı'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsStreamProvider).valueOrNull ?? [];
    final membersAsync = _isEdit
        ? ref.watch(
            StreamProvider((_) => ref
                  .watch(projectRepositoryProvider)
                .watchGroupMembers(widget.groupId!)),
          )
        : null;

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
            title: Text(
              _isEdit ? 'Grup Detayı' : 'Yeni Grup Oluştur',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            actions: [
              if (!_isEdit)
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
              // ─────────────────────────────────────────────────────────────
              // GRUP FOTOĞRAFI + RENK
              // ─────────────────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    // Grup avatarı (fotoğraf veya baş harf)
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
                                  blurRadius: 18,
                                ),
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
                                          : 'G',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        // Kamera ikonu
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)],
                                ),
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
                          decorationColor: Colors.white.withValues(alpha: 0.40),
                        ),
                      ),
                    ),
                    if (_groupImageBytes != null) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => setState(() => _groupImageBytes = null),
                        child: Text(
                          'Fotoğrafı Kaldır',
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
          const SizedBox(height: 20),
                  ],
                ),
              ),

              // ─────────────────────────────────────────────────────────────
              // GRUP ADI & AÇIKLAMA
              // ─────────────────────────────────────────────────────────────
              GlassField(
                controller: _nameCtrl,
                label: 'Grup Adı',
                icon: Icons.group_rounded,
              ),
              const SizedBox(height: 12),
              GlassField(
                controller: _descCtrl,
                label: 'Açıklama (opsiyonel)',
                icon: Icons.description_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // ─────────────────────────────────────────────────────────────
              // GRUP RENGİ
              // ─────────────────────────────────────────────────────────────
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
                            ? [BoxShadow(color: c.withValues(alpha: 0.60), blurRadius: 10)]
                        : null,
                  ),
                      child: sel
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

              // ─────────────────────────────────────────────────────────────
              // ÜYE EKLE (yalnızca yeni grup)
              // ─────────────────────────────────────────────────────────────
              if (!_isEdit) ...[
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
                          'Her üye için bir rol seçilmeden grup oluşturulamaz.',
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
                    text: 'Henüz arkadaşınız yok. Önce arkadaş ekleyin.',
                  )
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
                            _selectedMembers.add(MemberRole(friend)..role = role);
                          } else {
                            existing!.role = role;
                          }
                        });
                      },
                    );
                  }),

                // Unroled warning
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

                // ───────────────────────────────────────────────────────────
                // GRUP DAVETİ
                // ───────────────────────────────────────────────────────────
                SectionLabel('Gruba Davet Et'),
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
                        'Arkadaşlarını gruba davet etmek için sosyal medyada paylaş:',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                    Row(
                      children: [
                          // WhatsApp
                          Expanded(
                            child: ShareButton(
                              label: 'WhatsApp',
                              icon: Icons.chat_rounded,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                              ),
                              onTap: _shareViaWhatsApp,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Instagram
                        Expanded(
                            child: ShareButton(
                              label: 'Instagram',
                              icon: Icons.camera_rounded,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFE1306C),
                                  Color(0xFFC13584),
                                  Color(0xFF833AB4),
                                ],
                              ),
                              onTap: _shareViaInstagram,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Davet linki kopyala
                      GestureDetector(
                        onTap: () {
                          final name = _nameCtrl.text.trim().isNotEmpty
                              ? _nameCtrl.text.trim()
                              : 'Grubumuz';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '"$name" için davet metni kopyalandı!',
                              ),
                              backgroundColor: const Color(0xFF8B40F0),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.copy_rounded,
                                  color: Colors.white.withValues(alpha: 0.70),
                                  size: 16),
                        const SizedBox(width: 8),
                              Text(
                                'Davet Linkini Kopyala',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.80),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
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

              // ─────────────────────────────────────────────────────────────
              // DÜZENLEME MODU — mevcut üyeler
              // ─────────────────────────────────────────────────────────────
              if (_isEdit && membersAsync != null) ...[
                SectionLabel('Mevcut Üyeler'),
                const SizedBox(height: 8),
                membersAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  error: (e, _) => Text('Hata: $e',
                      style: const TextStyle(color: Colors.white)),
                  data: (members) => Column(
                    children: members
                        .map((m) => _ExistingMemberTile(member: m))
                        .toList(),
                  ),
                ),
              ],

              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
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

      // Fotoğrafı base64'e çevir
      final photoB64 = _groupImageBytes != null
          ? base64Encode(_groupImageBytes!)
          : null;

      final project = await repo.createProject(
        ownerId: user.uid,
        name: name,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        isShared: true,
        colorHex: _colorHex,
        photoBase64: photoB64,
      );

      // Sahibi yönetici olarak ekle
      await repo.addMember(
        groupId: project.id,
        userId: user.uid,
        email: user.email,
        displayName: user.displayName,
        role: 'yonetici',
      );

      // Seçili üyeleri rolleriyle ekle
      for (final m in _selectedMembers) {
        await repo.addMember(
          groupId: project.id,
          userId: m.friend.uid,
          email: m.friend.email,
          displayName: m.friend.displayName,
          role: m.role!,
        );
      }

      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── Existing Member Tile (edit mode) ─────────────────────────────────────────

class _ExistingMemberTile extends StatelessWidget {
  const _ExistingMemberTile({required this.member});
  final GroupMemberEntity member;

  @override
  Widget build(BuildContext context) {
    final roleLabel = switch (member.role) {
      'yonetici' || 'owner' => 'Yönetici',
      'kıdemli'             => 'Kıdemli',
      _                     => 'Üye',
    };
    final roleColor = switch (member.role) {
      'yonetici' || 'owner' => const Color(0xFFEF4444),
      'kıdemli'             => const Color(0xFFF59E0B),
      _                     => const Color(0xFF10B981),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF8B40F0).withValues(alpha: 0.60),
              child: Text(
                member.displayName.isNotEmpty
                    ? member.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.displayName,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  Text(member.email,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: roleColor.withValues(alpha: 0.55)),
              ),
              child: Text(roleLabel,
                  style: TextStyle(
                      color: roleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
