import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:todo_note/app/app_l10n.dart';
import 'package:todo_note/app/providers.dart';
import 'package:todo_note/app/router.dart';
import 'package:todo_note/ui/widgets/glass_widgets.dart';
import 'package:todo_note/features/auth/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final l = ref.watch(appL10nProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l.settings,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 108, 16, 120),
        children: [
          // ── Profilim ─────────────────────────────────────────────────────
          GlassSectionLabel(l.myProfile),
          GlassCard(
            child: ListTile(
              onTap: () => context.push(AppRoutes.profileSettings),
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? Text(
                        (user?.displayName ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              title: Text(
                user?.displayName ?? l.user,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l.profileSubtitle,
                style:
                    TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
              ),
              trailing: Icon(Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.50), size: 20),
            ),
          ),
          const SizedBox(height: 16),

          // ── Engellenenler ──────────────────────────────────────────────────
          GlassSectionLabel(l.blockedUsers),
          GlassCard(
            child: GlassTile(
              icon: Icons.block_outlined,
              title: l.blockedUsers,
              subtitle: l.blockedUsersSubtitle,
              onTap: () => context.push(AppRoutes.blockedUsers),
            ),
          ),
          const SizedBox(height: 16),

          // ── Görünüm ───────────────────────────────────────────────────────
          GlassSectionLabel(l.appearance),
          GlassCard(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined, color: Colors.white),
              title: Text(
                l.theme,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: SegmentedButton<ThemeMode>(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white.withValues(alpha: 0.30);
                    }
                    return Colors.white.withValues(alpha: 0.10);
                  }),
                  foregroundColor:
                      const WidgetStatePropertyAll(Colors.white),
                  side: WidgetStatePropertyAll(
                    BorderSide(
                        color: Colors.white.withValues(alpha: 0.30), width: 1),
                  ),
                ),
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.brightness_auto, size: 16),
                    tooltip: l.systemTheme,
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode, size: 16),
                    tooltip: l.lightTheme,
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode, size: 16),
                    tooltip: l.darkTheme,
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (modes) {
                  ref.read(themeModeProvider.notifier).setMode(modes.first);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Dil Tercihleri ────────────────────────────────────────────────
          GlassSectionLabel(l.language),
          GlassCard(
            child: ListTile(
              leading:
                  const Icon(Icons.language, color: Colors.white),
              title: Text(
                l.appLanguage,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: SegmentedButton<String>(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white.withValues(alpha: 0.30);
                    }
                    return Colors.white.withValues(alpha: 0.10);
                  }),
                  foregroundColor:
                      const WidgetStatePropertyAll(Colors.white),
                  side: WidgetStatePropertyAll(
                    BorderSide(
                        color: Colors.white.withValues(alpha: 0.30), width: 1),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: 'tr',
                    label: Text('TR', style: TextStyle(fontSize: 13)),
                  ),
                  ButtonSegment(
                    value: 'en',
                    label: Text('EN', style: TextStyle(fontSize: 13)),
                  ),
                ],
                selected: {locale.languageCode},
                onSelectionChanged: (langs) {
                  ref
                      .read(localeProvider.notifier)
                      .setLocale(Locale(langs.first));
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Bildirimler ───────────────────────────────────────────────────
          GlassSectionLabel(l.notifications),
          GlassCard(
            child: GlassTile(
              icon: Icons.notifications_outlined,
              title: l.notificationSettings,
              subtitle: l.notificationSubtitle,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.notificationComingSoon)),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Veri & Senkronizasyon ─────────────────────────────────────────
          GlassSectionLabel(l.dataSync),
          GlassCard(
            child: GlassTile(
              icon: Icons.cloud_sync_outlined,
              title: l.syncNow,
              subtitle: l.syncSubtitle,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.syncStarted)),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Hakkında ──────────────────────────────────────────────────────
          GlassSectionLabel(l.about),
          GlassCard(
            child: Column(
              children: [
                GlassTile(
                  icon: Icons.info_outline,
                  title: l.appVersion,
                  subtitle: '1.0.0 (MVP)',
                  onTap: () {},
                  trailing: const SizedBox.shrink(),
                ),
                const GlassDivider(),
                GlassTile(
                  icon: Icons.privacy_tip_outlined,
                  title: l.privacy,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Çıkış Yap ────────────────────────────────────────────────────
          GestureDetector(
            onTap: () => _signOut(context, ref, l),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFCC1A3A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFF4466).withValues(alpha: 0.60),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCC1A3A).withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    l.signOut,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Future<void> _signOut(
      BuildContext context, WidgetRef ref, AppL10n l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1060),
        title: Text(
          l.signOutConfirm,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l.cancel,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFCC1A3A),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.signOut),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
    }
  }
}
