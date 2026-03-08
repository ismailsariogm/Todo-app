import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_l10n.dart';
import '../../../app/providers.dart';
import '../../../domain/entities/conversation_entity.dart';
import '../../../domain/entities/message_entity.dart';
import '../../auth/auth_provider.dart';
import '../../tasks/widgets/home_background.dart';
import '../chat_provider.dart';
import '../widgets/chat_attach_sheet.dart';
import '../widgets/message_bubble.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversation});

  final ConversationEntity conversation;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _ctrl.clear();
    await ref.read(chatActionsProvider).sendMessage(
          conversation: widget.conversation,
          content: text,
        );
    setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _sendAttachment(String content) async {
    setState(() => _sending = true);
    await ref.read(chatActionsProvider).sendMessage(
          conversation: widget.conversation,
          content: content,
        );
    setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(),
    );
    if (confirmed == true && mounted) {
      await ref.read(chatActionsProvider).deleteConversation(
            widget.conversation.id,
          );
      ref.read(activeConversationProvider.notifier).state = null;
    }
  }

  Future<void> _confirmBlock(BuildContext context) async {
    final l = ref.read(appL10nProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final other = widget.conversation.participants
        .where((p) => p.uid != user.uid)
        .firstOrNull;
    if (other == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0533),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.blockConfirm, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.blockUser),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(chatActionsProvider).blockFriend(other.uid);
      ref.read(activeConversationProvider.notifier).state = null;
      await ref.read(chatActionsProvider).deleteConversation(widget.conversation.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.blockSuccess)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(chatUserProfileProvider);
    final msgsAsync =
        ref.watch(messagesStreamProvider(widget.conversation.id));

    final isGroup = widget.conversation.type == ConversationType.group;

    return Stack(
      children: [
        const HomeBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed: () {
                ref.read(activeConversationProvider.notifier).state = null;
              },
            ),
            title: Row(
              children: [
                _Avatar(
                  initials: widget.conversation.avatarInitials,
                  colorHex: widget.conversation.avatarColor,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.conversation.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isGroup)
                        Text(
                          '${widget.conversation.participants.length} üye',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.videocam_outlined,
                    color: Colors.white70, size: 24),
                onPressed: () => _showCallComingSoon(context),
              ),
              IconButton(
                icon: const Icon(Icons.call_outlined,
                    color: Colors.white70, size: 22),
                onPressed: () => _showCallComingSoon(context),
              ),
              if (isGroup)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.white70, size: 22),
                  onPressed: () => _confirmDelete(context),
                )
              else
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70, size: 22),
                  color: const Color(0xFF2A1060),
                  onSelected: (v) async {
                    if (v == 'delete') await _confirmDelete(context);
                    else if (v == 'block') await _confirmBlock(context);
                  },
                  itemBuilder: (_) {
                    final l = ref.read(appL10nProvider);
                    return [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.white70, size: 20),
                            SizedBox(width: 10),
                            Text('Sohbeti Sil', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.red.shade300, size: 20),
                            const SizedBox(width: 10),
                            Text(l.blockUser, style: TextStyle(color: Colors.red.shade300)),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: msgsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      e.toString(),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const _EmptyChat();
                    }
                    _scrollToBottom();
                    return profileAsync.when(
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                      data: (profile) {
                        return ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemCount: messages.length,
                          itemBuilder: (_, i) {
                            final msg = messages[i];
                            final isMe = msg.senderId == profile?.uid;
                            return MessageBubble(
                              message: msg,
                              isMe: isMe,
                              showSenderName: isGroup && !isMe,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              _InputBar(
                ctrl: _ctrl,
                sending: _sending,
                onSend: _send,
                onAttach: () => showChatAttachSheet(
                  context,
                  onSend: _sendAttachment,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3), width: 1.5),
            ),
            child: const Icon(Icons.chat_bubble_outline,
                color: Colors.white70, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz mesaj yok',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'İlk mesajı sen gönder!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

void _showCallComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Görüntülü / sesli arama yakında eklenecek'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF8B40F0),
    ),
  );
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.ctrl,
    required this.sending,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController ctrl;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottom + 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        border: Border(
          top: BorderSide(
              color: Colors.white.withValues(alpha: 0.15), width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAttach,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25), width: 1),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25), width: 1),
              ),
              child: TextField(
                controller: ctrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Mesaj yaz...',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B40F0).withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Delete dialog ─────────────────────────────────────────────────────────────

class _DeleteDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A0533),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Sohbeti Sil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      content: const Text(
        'Bu sohbet ve tüm mesajlar kalıcı olarak silinecek.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('İptal',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sil',
              style: TextStyle(
                  color: Color(0xFFCF4DA6), fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── Avatar helper ─────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.colorHex,
    this.size = 44,
  });

  final String initials;
  final String colorHex;
  final double size;

  Color _parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _parseHex(colorHex).withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _parseHex(colorHex).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
