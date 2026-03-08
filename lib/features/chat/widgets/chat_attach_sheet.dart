import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/entities/chat_user_entity.dart';
import '../chat_provider.dart';

/// Mesaj eki formatları (content içinde saklanır)
const String kMsgPrefixImage = '[IMG]';
const String kMsgPrefixDocument = '[DOC]';
const String kMsgPrefixContact = '[CONTACT]';
const String kMsgPrefixPoll = '[POLL]';

const int _maxImageBytes = 2 * 1024 * 1024; // 2MB
const int _maxDocBytes = 512 * 1024; // 512KB

/// Mesajlaşma ekranında + butonuna basıldığında açılan ekleme menüsü.
/// [onSend] — gönderilecek content (formatlı string)
void showChatAttachSheet(
  BuildContext parentContext, {
  required Future<void> Function(String content) onSend,
}) {
  showModalBottomSheet<void>(
    context: parentContext,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ChatAttachSheetContent(
      parentContext: parentContext,
      modalContext: ctx,
      onSend: onSend,
    ),
  );
}

class _ChatAttachSheetContent extends ConsumerStatefulWidget {
  const _ChatAttachSheetContent({
    required this.parentContext,
    required this.modalContext,
    required this.onSend,
  });

  final BuildContext parentContext;
  final BuildContext modalContext;
  final Future<void> Function(String content) onSend;

  @override
  ConsumerState<_ChatAttachSheetContent> createState() =>
      _ChatAttachSheetContentState();
}

class _ChatAttachSheetContentState extends ConsumerState<_ChatAttachSheetContent> {
  bool _loading = false;

  void _showError(String msg) {
    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (xfile == null) {
        if (mounted) Navigator.pop(widget.modalContext);
        return;
      }
      final bytes = await xfile.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        _showError('Fotoğraf çok büyük (max 2MB)');
        return;
      }
      final base64 = base64Encode(bytes);
      final content = '$kMsgPrefixImage$base64';
      Navigator.pop(widget.modalContext);
      await widget.onSend(content);
    } catch (e) {
      _showError('Fotoğraf seçilemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDocument() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) Navigator.pop(widget.modalContext);
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      final name = file.name;
      if (bytes == null || bytes.isEmpty) {
        _showError('Dosya okunamadı');
        return;
      }
      if (bytes.length > _maxDocBytes) {
        _showError('Belge çok büyük (max 512KB)');
        return;
      }
      final base64 = base64Encode(bytes);
      final content = '$kMsgPrefixDocument$name|$base64';
      Navigator.pop(widget.modalContext);
      await widget.onSend(content);
    } catch (e) {
      _showError('Belge seçilemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shareContact() async {
    final friendsAsync = ref.read(filteredFriendsProvider);
    final friends = friendsAsync.valueOrNull ?? [];
    if (friends.isEmpty) {
      _showError('Paylaşılacak arkadaş bulunamadı');
      return;
    }
    Navigator.pop(widget.modalContext);
    final selected = await showDialog<ChatUserEntity>(
      context: widget.parentContext,
      builder: (ctx) => _ContactPickerDialog(friends: friends),
    );
    if (selected == null) return;
    final content =
        '$kMsgPrefixContact${jsonEncode({'uid': selected.uid, 'displayName': selected.displayName})}';
    await widget.onSend(content);
  }

  Future<void> _createPoll() async {
    Navigator.pop(widget.modalContext);
    final result = await showDialog<({String question, List<String> options})>(
      context: widget.parentContext,
      builder: (ctx) => const _PollCreateDialog(),
    );
    if (result == null || result.question.trim().isEmpty) return;
    if (result.options.length < 2) {
      _showError('En az 2 seçenek girin');
      return;
    }
    final content =
        '$kMsgPrefixPoll${jsonEncode({'q': result.question.trim(), 'opts': result.options})}';
    await widget.onSend(content);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A0533),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ekle',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else ...[
              _AttachOption(
                icon: Icons.photo_library_outlined,
                label: 'Fotoğraf / Video',
                onTap: _pickPhoto,
              ),
              _AttachOption(
                icon: Icons.insert_drive_file_outlined,
                label: 'Belge',
                onTap: _pickDocument,
              ),
              _AttachOption(
                icon: Icons.person_add_outlined,
                label: 'Kişi Paylaş',
                onTap: _shareContact,
              ),
              _AttachOption(
                icon: Icons.poll_outlined,
                label: 'Anket Ekle',
                onTap: _createPoll,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B40F0).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Contact Picker Dialog ───────────────────────────────────────────────────

class _ContactPickerDialog extends StatelessWidget {
  const _ContactPickerDialog({required this.friends});
  final List<ChatUserEntity> friends;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A0533),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Kişi Paylaş',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: friends.length,
          itemBuilder: (_, i) {
            final f = friends[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(int.parse(
                    f.avatarColorHex.replaceFirst('#', '0xFF'))),
                child: Text(
                  f.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(
                f.displayName,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                f.userCode,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
              onTap: () => Navigator.pop(context, f),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'İptal',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
        ),
      ],
    );
  }
}

// ─── Poll Create Dialog ─────────────────────────────────────────────────────

class _PollCreateDialog extends StatefulWidget {
  const _PollCreateDialog();

  @override
  State<_PollCreateDialog> createState() => _PollCreateDialogState();
}

class _PollCreateDialogState extends State<_PollCreateDialog> {
  final _questionCtrl = TextEditingController();
  final _optionCtrls = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A0533),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Anket Oluştur',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _questionCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Soru',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                hintText: 'Anket sorusunu yazın',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Seçenekler',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ..._optionCtrls.asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: e.value,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Seçenek ${e.key + 1}',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            }),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _optionCtrls.add(TextEditingController());
                });
              },
              icon: const Icon(Icons.add, color: Color(0xFF8B40F0)),
              label: const Text(
                'Seçenek Ekle',
                style: TextStyle(color: Color(0xFF8B40F0)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'İptal',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
        ),
        FilledButton(
          onPressed: () {
            final opts = _optionCtrls
                .map((c) => c.text.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            Navigator.pop(context, (
              question: _questionCtrl.text.trim(),
              options: opts,
            ));
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8B40F0),
          ),
          child: const Text('Gönder'),
        ),
      ],
    );
  }
}
