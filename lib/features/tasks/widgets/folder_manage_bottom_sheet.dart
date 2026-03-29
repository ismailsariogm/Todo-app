import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_l10n.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../domain/entities/task_file_entity.dart';
import '../../../services/task_file_storage.dart';
import '../../auth/auth_provider.dart';
import '../providers/filter_provider.dart';
import '../providers/tasks_provider.dart';
import 'create_folder_dialog.dart';

/// Ana filtre çubuğunda (P1–P3 yanında) kullanılan klasör yönetim düğmesi.
class FolderManageStripButton extends ConsumerWidget {
  const FolderManageStripButton({super.key, required this.pinkTheme});

  final bool pinkTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: 'Klasörleri yönet',
      child: _StripIconChip(
        pinkTheme: pinkTheme,
        icon: Icons.folder_special_outlined,
        onTap: () => showFolderManageSheet(context, ref),
      ),
    );
  }
}

/// Grup / topluluk görev çubuğunda Filtrele’nin yanında.
class FolderManageToolbarGlassButton extends ConsumerWidget {
  const FolderManageToolbarGlassButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: 'Klasörleri yönet',
      child: GestureDetector(
        onTap: () => showFolderManageSheet(context, ref),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Icon(
            Icons.folder_special_outlined,
            size: 18,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

Future<void> clearFolderIdFromFilters(WidgetRef ref, String fileId) async {
  final main = ref.read(taskFilterProvider);
  if (main.fileId == fileId) {
    ref.read(taskFilterProvider.notifier).setFile(null);
  }
  final projects = await ref.read(allSharedProjectsForUserProvider.future);
  for (final p in projects) {
    final gf = ref.read(groupTaskFilterProvider(p.id));
    if (gf.fileId == fileId) {
      ref.read(groupTaskFilterProvider(p.id).notifier).state =
          gf.copyWith(clearFileId: true);
    }
  }
}

Future<void> showFolderManageSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _FolderManageSheetBody(),
  );
}

class _FolderManageSheetBody extends ConsumerStatefulWidget {
  const _FolderManageSheetBody();

  @override
  ConsumerState<_FolderManageSheetBody> createState() =>
      _FolderManageSheetBodyState();
}

class _FolderManageSheetBodyState extends ConsumerState<_FolderManageSheetBody> {
  @override
  Widget build(BuildContext context) {
    final l = ref.watch(appL10nProvider);
    final user = ref.watch(currentUserProvider);
    final filesAsync = ref.watch(taskFilesProvider);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.tabFolders,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: user == null
                        ? null
                        : () async {
                            await showCreateFolderDialog(context, ref);
                            if (mounted) {
                              ref.invalidate(taskFilesProvider);
                            }
                          },
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(l.addFolder),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('${l.foldersLoadError}: $e')),
                data: (files) {
                  if (files.isEmpty) {
                    return ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(24),
                      children: [
                        Icon(Icons.folder_open_outlined,
                            size: 48, color: cs.outline),
                        const SizedBox(height: 12),
                        Text(
                          l.noFoldersYet,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.noFoldersSubtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: files.length,
                    itemBuilder: (_, i) {
                      final f = files[i];
                      return ListTile(
                        leading: Icon(Icons.folder_outlined, color: cs.primary),
                        title: Text(f.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Adı düzenle',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: user == null
                                  ? null
                                  : () => _renameFolder(context, f),
                            ),
                            IconButton(
                              tooltip: 'Sil',
                              icon: Icon(Icons.delete_outline, color: cs.error),
                              onPressed: user == null
                                  ? null
                                  : () => _deleteFolder(context, f, user.uid),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameFolder(
    BuildContext context,
    TaskFileEntity folder,
  ) async {
    final l = ref.read(appL10nProvider);
    final ctrl = TextEditingController(text: folder.name);
    String? newName;
    try {
      newName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_tr ? 'Klasör adını düzenle' : 'Rename folder'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l.folderNameHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(_tr ? 'Kaydet' : 'Save'),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
    if (!context.mounted) return;
    if (newName == null || newName.isEmpty || newName == folder.name) return;
    try {
      await TaskFileStorage.instance.updateFile(
        TaskFileEntity(
          id: folder.id,
          ownerId: folder.ownerId,
          name: newName,
          colorHex: folder.colorHex,
          sortOrder: folder.sortOrder,
          createdAt: folder.createdAt,
        ),
      );
      ref.invalidate(taskFilesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr ? 'Klasör güncellendi' : 'Folder updated')),
        );
      }
    } catch (e) {
      final msg = e.toString().contains('duplicate_folder')
          ? l.duplicateFolderWarning
          : '${l.folderCreateError}: $e';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor:
                e.toString().contains('duplicate_folder') ? Colors.orange : null,
          ),
        );
      }
    }
  }

  bool get _tr => Localizations.localeOf(context).languageCode == 'tr';

  Future<void> _deleteFolder(
    BuildContext context,
    TaskFileEntity folder,
    String uid,
  ) async {
    final l = ref.read(appL10nProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tr ? 'Klasörü sil' : 'Delete folder'),
        content: Text(
          _tr
              ? '"${folder.name}" silinsin mi? Bu klasördeki görevler klasörsüz kalır.'
              : 'Delete "${folder.name}"? Tasks will become uncategorized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(_tr ? 'Sil' : 'Delete'),
          ),
        ],
      ),
    );
    if (!context.mounted || ok != true) return;
    await WebTaskRepository.instance.init();
    await WebTaskRepository.instance.clearFileIdForOwnerTasks(uid, folder.id);
    await TaskFileStorage.instance.deleteFile(folder.id);
    await clearFolderIdFromFilters(ref, folder.id);
    ref.invalidate(taskFilesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr ? 'Klasör silindi' : 'Folder deleted'),
        ),
      );
    }
  }
}

/// Filtre çubuğu ile aynı görsel dil (P1–P3 şeridi).
class _StripIconChip extends StatefulWidget {
  const _StripIconChip({
    required this.pinkTheme,
    required this.icon,
    required this.onTap,
  });

  final bool pinkTheme;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_StripIconChip> createState() => _StripIconChipState();
}

class _StripIconChipState extends State<_StripIconChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inactiveBg = widget.pinkTheme
        ? Colors.white.withValues(alpha: 0.12)
        : cs.surfaceContainerHighest;
    final fg = widget.pinkTheme
        ? Colors.white.withValues(alpha: 0.88)
        : cs.onSurface;
    final border = widget.pinkTheme
        ? Colors.white.withValues(alpha: 0.20)
        : Colors.transparent;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: inactiveBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Icon(widget.icon, size: 18, color: fg),
        ),
      ),
    );
  }
}
