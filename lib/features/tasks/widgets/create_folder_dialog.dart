import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_l10n.dart';
import '../../../services/task_file_storage.dart';
import '../providers/tasks_provider.dart';
import '../../auth/auth_provider.dart';

/// Klasör oluşturma dialogu — aynı isimde klasör varsa uyarır.
Future<void> showCreateFolderDialog(
  BuildContext context,
  WidgetRef ref, {
  ValueChanged<String?>? onFolderCreated,
}) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;
  final l = ref.watch(appL10nProvider);

  final nameCtrl = TextEditingController();

  final created = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final hasText = nameCtrl.text.trim().isNotEmpty;
        return AlertDialog(
          title: Text(l.createFolder),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l.folderNameHint,
              hintText: l.folderNameExample,
            ),
            onChanged: (_) => setDialogState(() {}),
            onSubmitted: (_) {
              if (nameCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: hasText ? () => Navigator.pop(ctx, true) : null,
              child: Text(l.addFolder),
            ),
          ],
        );
      },
    ),
  );

  final name = nameCtrl.text.trim();
  nameCtrl.dispose();
  if (created != true || name.isEmpty) return;

  // Aynı isimde klasör var mı kontrol et
  final exists = await TaskFileStorage.instance.hasFolderWithName(user.uid, name);
  if (exists && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.duplicateFolderWarning),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  try {
    final file = await TaskFileStorage.instance.createFile(
      ownerId: user.uid,
      name: name,
    );
    ref.refresh(taskFilesProvider);
    onFolderCreated?.call(file.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.folderCreated(name))),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.folderCreateError}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
