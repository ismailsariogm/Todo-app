import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:todo_note/app/app_l10n.dart';
import 'package:todo_note/app/providers.dart';
import 'package:todo_note/features/auth/auth_provider.dart';
import 'package:todo_note/features/tasks/widgets/home_background.dart';
import 'package:todo_note/ui/widgets/glass_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _aboutCtrl = TextEditingController();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _aboutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final user = ref.watch(currentUserProvider);
    final l = ref.watch(appL10nProvider);

    final photoUrl = profile.photoUrl ?? user?.photoURL;
    final displayName = user?.displayName ?? l.user;
    final email = user?.email ?? '';
    final phone = user?.phone ?? '';
    final countryCode = user?.countryCode ?? '';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l.profileTitle,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          // Same animated background as the main shell
          const HomeBackground(),

          // Content
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 108, 16, 120),
            children: [
              // ── Avatar ─────────────────────────────────────────────────
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      backgroundImage: photoUrl != null
                          ? (photoUrl.startsWith('data:')
                              ? MemoryImage(base64Decode(
                                  photoUrl.split(',').last))
                              : NetworkImage(photoUrl) as ImageProvider)
                          : null,
                      child: photoUrl == null
                          ? Text(
                              displayName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    GestureDetector(
                      onTap: () => _showPhotoOptions(context, l, profile),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B40F0),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  email,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),

              // ── Hesap bilgileri (read-only) ────────────────────────────
              GlassSectionLabel('Hesap Bilgileri'),
              GlassCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.email_outlined,
                          color: Colors.white.withValues(alpha: 0.80), size: 22),
                      title: Text('E-posta',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12)),
                      subtitle: Text(
                        email.isNotEmpty ? email : '—',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const GlassDivider(),
                      ListTile(
                        leading: Icon(Icons.phone_outlined,
                            color: Colors.white.withValues(alpha: 0.80),
                            size: 22),
                        title: Text('Telefon',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 12)),
                        subtitle: Text(
                          '$countryCode $phone',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20)),
                          ),
                          child: Text('Salt Okunur',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.50),
                                  fontSize: 10)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Hakkımda ───────────────────────────────────────────────
              GlassSectionLabel(l.aboutMe),
              GlassCard(
                child: ListTile(
                  leading: Icon(Icons.info_outline,
                      color: Colors.white.withValues(alpha: 0.85), size: 22),
                  title: Text(
                    profile.aboutMe.isEmpty
                        ? l.aboutMePlaceholder
                        : profile.aboutMe,
                    style: TextStyle(
                      color: profile.aboutMe.isEmpty
                          ? Colors.white.withValues(alpha: 0.45)
                          : Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Icon(Icons.edit,
                      color: Colors.white.withValues(alpha: 0.50), size: 18),
                  onTap: () => _editAboutMe(context, l, profile.aboutMe),
                ),
              ),
              const SizedBox(height: 16),

              // ── Gizlilik ───────────────────────────────────────────────
              GlassSectionLabel(l.privacySection),
              GlassCard(
                child: Column(
                  children: [
                    GlassSwitchTile(
                      icon: Icons.visibility_outlined,
                      title: l.onlineVisibility,
                      subtitle: l.onlineSubtitle,
                      value: profile.onlineVisible,
                      onChanged: (v) => ref
                          .read(profileProvider.notifier)
                          .setOnlineVisible(v),
                    ),
                    const GlassDivider(),
                    GlassSwitchTile(
                      icon: Icons.done_all,
                      title: l.readReceipts,
                      subtitle: l.readReceiptsSubtitle,
                      value: profile.readReceipts,
                      onChanged: (v) => ref
                          .read(profileProvider.notifier)
                          .setReadReceipts(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Bağlantılar ─────────────────────────────────────────────
              GlassSectionLabel(l.links),
              GlassCard(
                child: Column(
                  children: [
                    ...profile.links.asMap().entries.map((entry) => Column(
                          children: [
                            if (entry.key > 0) const GlassDivider(),
                            ListTile(
                              leading: Icon(Icons.link,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  size: 22),
                              title: Text(
                                entry.value,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.remove_circle_outline,
                                    color: Colors.white.withValues(alpha: 0.55),
                                    size: 20),
                                onPressed: () {
                                  final updated =
                                      List<String>.from(profile.links)
                                        ..removeAt(entry.key);
                                  ref
                                      .read(profileProvider.notifier)
                                      .setLinks(updated);
                                },
                              ),
                            ),
                          ],
                        )),
                    if (profile.links.isNotEmpty) const GlassDivider(),
                    ListTile(
                      leading: Icon(Icons.add_circle_outline,
                          color: Colors.white.withValues(alpha: 0.85), size: 22),
                      title: Text(
                        l.addLink,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      onTap: () => _addLink(context, l, profile),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Gruplar ────────────────────────────────────────────────
              GlassSectionLabel(l.groups),
              GlassCard(
                child: GlassTile(
                  icon: Icons.group_outlined,
                  title: l.viewGroups,
                  subtitle: l.viewGroupsSubtitle,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPhotoOptions(
      BuildContext context, AppL10n l, ProfileSettings profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A1060),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Galeriden seç
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Colors.white70),
              title: Text(
                l.chooseFromGallery,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(context, l, ImageSource.gallery);
              },
            ),
            // Kameradan çek
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: Colors.white70),
              title: Text(
                l.takePhoto,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(context, l, ImageSource.camera);
              },
            ),
            // URL ile ekle
            ListTile(
              leading:
                  const Icon(Icons.link, color: Colors.white70),
              title: Text(
                l.enterUrlOption,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _enterPhotoUrl(context, l);
              },
            ),
            if (profile.photoUrl != null) ...[
              const Divider(color: Colors.white24, height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                title: Text(
                  l.removePhoto,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(profileProvider.notifier).setPhotoUrl(null);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white38),
              title: Text(
                l.cancel,
                style: const TextStyle(color: Colors.white38),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(
      BuildContext context, AppL10n l, ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (xFile == null) return;

      final bytes = await xFile.readAsBytes();
      final base64Str = base64Encode(bytes);
      final mimeType = xFile.mimeType ?? 'image/jpeg';
      final dataUrl = 'data:$mimeType;base64,$base64Str';

      // Check approximate size (SharedPreferences/localStorage ~5MB limit)
      if (dataUrl.length > 1500000) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.imageTooLarge)),
          );
        }
        return;
      }

      await ref.read(profileProvider.notifier).setPhotoUrl(dataUrl);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.imageTooLarge)),
        );
      }
    }
  }

  Future<void> _enterPhotoUrl(BuildContext context, AppL10n l) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1060),
        title: Text(
          l.photoUrlTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'https://...',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white38),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel,
                style: const TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B40F0)),
            onPressed: () {
              final url = ctrl.text.trim();
              if (url.isNotEmpty) {
                ref.read(profileProvider.notifier).setPhotoUrl(url);
              }
              Navigator.pop(ctx);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  Future<void> _editAboutMe(
      BuildContext context, AppL10n l, String current) async {
    _aboutCtrl.text = current;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1060),
        title: Text(
          l.aboutMeTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: _aboutCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 4,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: l.aboutMeHint,
            hintStyle: const TextStyle(color: Colors.white38),
            counterStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white38),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel,
                style: const TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B40F0)),
            onPressed: () {
              ref
                  .read(profileProvider.notifier)
                  .setAboutMe(_aboutCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  Future<void> _addLink(
      BuildContext context, AppL10n l, ProfileSettings profile) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1060),
        title: Text(
          l.addLink,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'https://',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white38),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel,
                style: const TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B40F0)),
            onPressed: () {
              final url = ctrl.text.trim();
              if (url.isNotEmpty) {
                final updated = [...profile.links, url];
                ref.read(profileProvider.notifier).setLinks(updated);
              }
              Navigator.pop(ctx);
            },
            child: Text(l.add),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }
}
