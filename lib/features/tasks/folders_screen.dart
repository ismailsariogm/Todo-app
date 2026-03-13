import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_l10n.dart';
import '../../app/router.dart';
import '../../domain/entities/task_file_entity.dart';
import '../auth/auth_provider.dart';
import 'widgets/home_background.dart';
import 'widgets/create_folder_dialog.dart';
import 'providers/tasks_provider.dart';
import 'providers/filter_provider.dart';

/// Klasörlerim ekranı — kişisel görev klasörlerini listeler ve filtrelemeye yönlendirir.
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(taskFilesProvider);
    final user = ref.watch(currentUserProvider);
    final l = ref.watch(appL10nProvider);

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
            title: Text(
              l.tabFolders,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                tooltip: l.addFolder,
                onPressed: () => _showAddFolderDialog(context, ref, user?.uid, l),
              ),
            ],
          ),
          body: filesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            error: (e, _) => Center(
              child: Text(
                '${l.foldersLoadError}: $e',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            data: (files) {
              if (files.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.noFoldersYet,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.noFoldersSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () =>
                              _showAddFolderDialog(context, ref, user?.uid, l),
                          icon: const Icon(Icons.add),
                          label: Text(l.addFolder),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 120),
                itemCount: files.length,
                itemBuilder: (_, i) => _FolderTile(
                  folder: files[i],
                  onTap: () {
                    ref.read(taskFilterProvider.notifier).setFile(files[i].id);
                    context.go(AppRoutes.home);
                  },
                  onRefresh: () => ref.refresh(taskFilesProvider),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static Future<void> _showAddFolderDialog(
    BuildContext context,
    WidgetRef ref,
    String? userId,
    AppL10n l,
  ) async {
    if (userId == null) return;
    await showCreateFolderDialog(context, ref);
  }
}

class _FolderTile extends ConsumerWidget {
  const _FolderTile({
    required this.folder,
    required this.onTap,
    required this.onRefresh,
  });

  final TaskFileEntity folder;
  final VoidCallback onTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _parseColor(folder.colorHex);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.folder_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                folder.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.6),
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
      return const Color(0xFF6366F1);
    }
  }
}
