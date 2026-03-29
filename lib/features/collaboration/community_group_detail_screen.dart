import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:todo_note/app/router.dart';
import 'package:todo_note/data/repositories/chat_repository.dart';
import 'package:todo_note/domain/entities/message_entity.dart';
import 'package:todo_note/domain/entities/project_entity.dart' show GroupMemberEntity, ProjectEntity;
import 'package:todo_note/domain/group_permissions.dart';
import 'package:todo_note/features/auth/auth_provider.dart'
    show currentUserProvider;
import 'package:todo_note/data/repositories/task_repository.dart'
    show WebTaskRepository;
import 'package:todo_note/features/tasks/providers/tasks_provider.dart'
    show GroupTaskTab, groupAllTasksCountProvider, groupMembersProvider,
        groupTaskTabProvider, groupSearchQueryProvider, groupTasksProvider,
        groupTaskFilterProvider, groupTaskProgressProvider, taskFilesProvider,
        communityByIdProvider, communitySubGroupsProvider, projectByIdProvider;
import 'package:todo_note/features/tasks/widgets/folder_manage_bottom_sheet.dart';
import 'package:todo_note/features/tasks/widgets/home_background.dart';
import 'package:todo_note/features/tasks/widgets/task_card.dart';
import 'package:todo_note/features/tasks/widgets/task_progress_dual_section.dart'
    show TaskProgressTodaySection, TaskProgressOngoingSection;
import 'package:todo_note/features/chat/widgets/chat_attach_sheet.dart';
import 'package:todo_note/features/chat/widgets/message_content_widget.dart'
    as msg_widget;
import 'package:todo_note/features/collaboration/group_badge_widget.dart'
    show totalGroupMessageBadgeProvider, totalGroupTaskBadgeProvider;
import 'package:todo_note/features/collaboration/group_notification_providers.dart';
import 'package:todo_note/services/group_notification_storage.dart';
import 'package:todo_note/app/theme.dart' show PriorityColor;
import 'package:todo_note/features/tasks/providers/group_filter_provider.dart';
import 'package:todo_note/ui/widgets/pink_fab.dart';

final _communityMessagesProvider =
    StreamProvider.family<List<MessageEntity>, String>((ref, convId) {
  return ChatRepository.instance.watchMessages(convId);
});

class CommunityGroupDetailScreen extends ConsumerStatefulWidget {
  const CommunityGroupDetailScreen({
    super.key,
    required this.communityId,
  });

  final String communityId;

  @override
  ConsumerState<CommunityGroupDetailScreen> createState() =>
      _CommunityGroupDetailScreenState();
}

class _CommunityGroupDetailScreenState
    extends ConsumerState<CommunityGroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _msgCtrl = TextEditingController();
  bool _sending = false;
  /// null = Genel (topluluk), aksi halde alt grup id
  String? _selectedGroupId;

  String get _effectiveGroupId => _selectedGroupId ?? widget.communityId;
  String get _effectiveConvId => 'group_proj_$_effectiveGroupId';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WebTaskRepository.instance.init();
      if (mounted) _updateBadgesForTab(_tabCtrl.index);
    });
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    _updateBadgesForTab(_tabCtrl.index);
  }

  void _updateBadgesForTab(int tab) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final gid = _effectiveGroupId;
    if (tab == 0) {
      final msgsAsync = ref.read(_communityMessagesProvider('group_proj_$gid'));
      if (!msgsAsync.hasValue) return;
      final msgs = msgsAsync.valueOrNull ?? [];
      final visible = msgs
          .where((m) =>
              !m.isDeleted && !m.deletedForUserIds.contains(user.uid))
          .length;
      setLastViewedMessageCount(user.uid, gid, visible);
      ref.invalidate(groupMessageBadgeProvider(gid));
      ref.invalidate(totalGroupMessageBadgeProvider);
    } else if (tab == 1) {
      final countAsync = ref.read(groupAllTasksCountProvider(gid));
      if (!countAsync.hasValue) return;
      final count = countAsync.valueOrNull ?? 0;
      setLastViewedTaskCount(user.uid, gid, count);
      ref.invalidate(groupTaskBadgeProvider(gid));
      ref.invalidate(totalGroupTaskBadgeProvider);
    }
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _updateBadgesForTab(_tabCtrl.index);
    _tabCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final communityAsync = ref.watch(communityByIdProvider(widget.communityId));
    final subGroupsAsync =
        ref.watch(communitySubGroupsProvider(widget.communityId));

    final community = communityAsync.valueOrNull;
    final subGroups = subGroupsAsync.valueOrNull ?? [];

    ref.listen(_communityMessagesProvider(_effectiveConvId), (_, next) {
      if (next.hasValue && _tabCtrl.index == 0 && !_tabCtrl.indexIsChanging) {
        _updateBadgesForTab(0);
      }
    });
    ref.listen(groupAllTasksCountProvider(_effectiveGroupId), (_, next) {
      if (next.hasValue && _tabCtrl.index == 1 && !_tabCtrl.indexIsChanging) {
        _updateBadgesForTab(1);
      }
    });

    return communityAsync.when(
      loading: () => Stack(
        children: [
          const HomeBackground(),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ],
      ),
      error: (e, _) => Stack(
        children: [
          const HomeBackground(),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: Text('Hata: $e',
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
      data: (_) {
        if (community == null) {
          return Stack(
            children: [
              const HomeBackground(),
              Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(
                  child: Text('Topluluk bulunamadı',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          );
        }
        final selectedName = _selectedGroupId == null
            ? community.name
            : subGroups
                    .where((g) => g.id == _selectedGroupId)
                    .map((g) => g.name)
                    .firstOrNull ??
                community.name;
        final selectedMembers = ref
            .watch(groupMembersProvider(_effectiveGroupId))
            .valueOrNull ?? [];

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
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          selectedName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.groups_rounded,
                            color: Colors.white.withValues(alpha: 0.8), size: 20),
                      ],
                    ),
                    Text(
                      '${selectedMembers.length} üye',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.videocam_outlined,
                        color: Colors.white, size: 22),
                    onPressed: () => _showCallComingSoon(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call_outlined,
                        color: Colors.white, size: 20),
                    onPressed: () => _showCallComingSoon(context),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push(
                        '${AppRoutes.groupSettings}/$_effectiveGroupId'),
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white, size: 18),
                    label: const Text(
                      'Ayarlar',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                ],
                bottom: TabBar(
                  controller: _tabCtrl,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Sohbet'),
                    Tab(icon: Icon(Icons.checklist_rounded), text: 'Görevler'),
                  ],
                ),
              ),
              body: Row(
                children: [
                  if (subGroups.isNotEmpty) ...[
                    Container(
                      width: 240,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border(
                          right: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        children: [
                          _SidePanelTile(
                            label: 'Genel',
                            subtitle: community.name,
                            icon: Icons.groups_rounded,
                            isSelected: _selectedGroupId == null,
                            onTap: () {
                              setState(() {
                                _selectedGroupId = null;
                                _msgCtrl.clear();
                              });
                            },
                          ),
                          const Divider(
                            color: Colors.white24,
                            height: 1,
                            indent: 12,
                            endIndent: 12,
                          ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
                            child: Text(
                              'Alt Gruplar',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ...subGroups.map((g) => _SubGroupSideTile(
                                group: g,
                                isSelected: _selectedGroupId == g.id,
                                onTap: () {
                                  setState(() {
                                    _selectedGroupId = g.id;
                                    _msgCtrl.clear();
                                  });
                                },
                              )),
                        ],
                      ),
                    ),
                  ],
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _CommunityChatTab(
                          convId: _effectiveConvId,
                          currentUser: user,
                          msgCtrl: _msgCtrl,
                          sending: _sending,
                          onSend: _sendMessage,
                          onAttach: () => showChatAttachSheet(
                            context,
                            onSend: _sendAttachment,
                          ),
                          onEditMessage: _showEditMessage,
                          onDeleteForMe: _deleteForMe,
                          onDeleteForEveryone: _deleteForEveryone,
                        ),
                        _CommunityTasksTab(groupId: _effectiveGroupId),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCallComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Görüntülü / sesli arama yakında eklenecek'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF8B40F0),
      ),
    );
  }

  Future<void> _showEditMessage(MessageEntity msg) async {
    final ctrl = TextEditingController(text: msg.content);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mesajı Düzenle'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Mesaj'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ChatRepository.instance.editMessage(_effectiveConvId, msg.id, result);
    }
  }

  Future<void> _deleteForMe(MessageEntity msg, String? userId) async {
    if (userId == null) return;
    await ChatRepository.instance.deleteMessageForMe(_effectiveConvId, msg.id, userId);
  }

  Future<void> _deleteForEveryone(MessageEntity msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Herkesten Sil'),
        content: const Text(
          'Bu mesajı herkesin sohbetinden silmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ChatRepository.instance.deleteMessageForEveryone(_effectiveConvId, msg.id);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final u = ref.read(currentUserProvider);
    if (u == null) return;

    setState(() => _sending = true);
    try {
      await ChatRepository.instance.sendMessage(
        conversationId: _effectiveConvId,
        senderId: u.uid,
        senderName: u.displayName,
        content: text,
        ownerUid: u.uid,
        participantUids: [u.uid],
      );
      _msgCtrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAttachment(String content) async {
    final u = ref.read(currentUserProvider);
    if (u == null || _sending) return;

    setState(() => _sending = true);
    try {
      await ChatRepository.instance.sendMessage(
        conversationId: _effectiveConvId,
        senderId: u.uid,
        senderName: u.displayName,
        content: content,
        ownerUid: u.uid,
        participantUids: [u.uid],
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _SidePanelTile extends StatelessWidget {
  const _SidePanelTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B40F0).withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle,
                    color: const Color(0xFF8B40F0), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubGroupSideTile extends StatelessWidget {
  const _SubGroupSideTile({
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  final ProjectEntity group;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final groupColor =
        Color(int.parse(group.colorHex.replaceFirst('#', '0xFF')));

    return Material(
      color: isSelected
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: groupColor.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: group.photoBase64 != null && group.photoBase64!.isNotEmpty
                    ? ClipOval(
                        child: Image.memory(
                          base64Decode(group.photoBase64!),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          group.name.isNotEmpty
                              ? group.name[0].toUpperCase()
                              : 'G',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle,
                    color: const Color(0xFF8B40F0), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityChatTab extends ConsumerWidget {
  const _CommunityChatTab({
    required this.convId,
    required this.currentUser,
    required this.msgCtrl,
    required this.sending,
    required this.onSend,
    required this.onAttach,
    required this.onEditMessage,
    required this.onDeleteForMe,
    required this.onDeleteForEveryone,
  });

  final String convId;
  final dynamic currentUser;
  final TextEditingController msgCtrl;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final void Function(MessageEntity) onEditMessage;
  final void Function(MessageEntity, String?) onDeleteForMe;
  final void Function(MessageEntity) onDeleteForEveryone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(_communityMessagesProvider(convId));
    var messages = messagesAsync.valueOrNull ?? [];
    final uid = currentUser?.uid;
    messages = messages
        .where((m) =>
            !m.isDeleted &&
            (uid == null || !m.deletedForUserIds.contains(uid)))
        .toList();

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.40)),
                      const SizedBox(height: 12),
                      Text(
                        'Henüz mesaj yok\nTopluluğunuza ilk mesajı gönderin!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isSystemSettings =
                        msg.senderId == ChatRepository.systemSettingsSenderId;
                    final isMe =
                        !isSystemSettings && msg.senderId == currentUser?.uid;
                    final isAttachment = msg.content.startsWith('img:') ||
                        msg.content.startsWith('doc:') ||
                        msg.content.startsWith('contact:') ||
                        msg.content.startsWith('poll:');
                    return _MessageBubble(
                      msg: msg,
                      isMe: isMe,
                      isSystemSettings: isSystemSettings,
                      onEdit: isSystemSettings || isAttachment
                          ? null
                          : (isMe ? () => onEditMessage(msg) : null),
                      onDeleteForMe: isSystemSettings
                          ? null
                          : () => onDeleteForMe(msg, currentUser?.uid),
                      onDeleteForEveryone: isSystemSettings
                          ? null
                          : (isMe ? () => onDeleteForEveryone(msg) : null),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          color: Colors.black.withValues(alpha: 0.20),
          child: Row(
            children: [
              GestureDetector(
                onTap: onAttach,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: TextField(
                    controller: msgCtrl,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: 'Mesaj yaz...',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.50)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: sending ? null : onSend,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B40F0).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.msg,
    required this.isMe,
    this.isSystemSettings = false,
    this.onEdit,
    this.onDeleteForMe,
    this.onDeleteForEveryone,
  });

  final MessageEntity msg;
  final bool isMe;
  final bool isSystemSettings;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleteForMe;
  final VoidCallback? onDeleteForEveryone;

  @override
  Widget build(BuildContext context) {
    final hasMenu = (onEdit != null || onDeleteForMe != null ||
        onDeleteForEveryone != null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) const SizedBox(width: 4),
          if (isMe) const SizedBox(width: 6),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isMe && hasMenu)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.7)),
                    color: Colors.white,
                    onSelected: (v) {
                      switch (v) {
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'delete_me':
                          onDeleteForMe?.call();
                          break;
                        case 'delete_all':
                          onDeleteForEveryone?.call();
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                            value: 'edit', child: Text('Düzenle')),
                      if (onDeleteForMe != null)
                        const PopupMenuItem(
                            value: 'delete_me', child: Text('Benden sil')),
                      if (onDeleteForEveryone != null)
                        const PopupMenuItem(
                            value: 'delete_all',
                            child: Text('Herkesten sil',
                                style: TextStyle(color: Color(0xFFEF4444)))),
                    ],
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFF8B40F0).withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe)
                        Text(msg.senderName,
                            style: const TextStyle(
                                color: Color(0xFFCF4DA6),
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      buildMessageContent(msg.content, isMe: isMe),
                      const SizedBox(height: 2),
                      Text(
                        '${msg.sentAt.hour.toString().padLeft(2, '0')}:${msg.sentAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget buildMessageContent(String content, {required bool isMe}) {
    return msg_widget.buildMessageContent(content, isMe: isMe);
  }
}

class _CommunityTasksTab extends ConsumerStatefulWidget {
  const _CommunityTasksTab({required this.groupId});
  final String groupId;

  @override
  ConsumerState<_CommunityTasksTab> createState() =>
      _CommunityTasksTabState();
}

class _CommunityTasksTabState extends ConsumerState<_CommunityTasksTab> {
  final _searchCtrl = TextEditingController();

  static const _tabs = [
    (tab: GroupTaskTab.active, label: 'Devam Eden', icon: Icons.timelapse_rounded),
    (tab: GroupTaskTab.today, label: 'Bugün', icon: Icons.today_rounded),
    (tab: GroupTaskTab.done, label: 'Bitti', icon: Icons.check_circle_outline),
    (tab: GroupTaskTab.deleted, label: 'Silindi', icon: Icons.delete_outline),
    (tab: GroupTaskTab.all, label: 'Tümü', icon: Icons.list_rounded),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showGroupFilterSheet(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    List<GroupMemberEntity> members,
  ) {
    final filter = ref.read(groupTaskFilterProvider(groupId));
    final notifier = ref.read(groupTaskFilterProvider(groupId).notifier);
    var local = filter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filtrele',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    TextButton(
                      onPressed: () {
                        notifier.state = const GroupTaskFilter();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Sıfırla'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Görev ismi',
                    hintText: 'Görev adında ara...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) =>
                      setModalState(() => local = local.copyWith(searchQuery: v)),
                  controller: TextEditingController(text: local.searchQuery),
                ),
                const SizedBox(height: 12),
                const Text('Oluşturulma tarihi',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(local.createdDateFrom != null
                            ? '${local.createdDateFrom!.day}.${local.createdDateFrom!.month}.${local.createdDateFrom!.year}'
                            : 'Başlangıç'),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate:
                                local.createdDateFrom ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d != null) {
                            setModalState(() =>
                                local = local.copyWith(createdDateFrom: d));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(local.createdDateTo != null
                            ? '${local.createdDateTo!.day}.${local.createdDateTo!.month}.${local.createdDateTo!.year}'
                            : 'Bitiş'),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate:
                                local.createdDateTo ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d != null) {
                            setModalState(() =>
                                local = local.copyWith(createdDateTo: d));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Görev zamanı (son tarih)',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event, size: 16),
                        label: Text(local.dueDateFrom != null
                            ? '${local.dueDateFrom!.day}.${local.dueDateFrom!.month}'
                            : 'Başlangıç'),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate:
                                local.dueDateFrom ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d != null) {
                            setModalState(() =>
                                local = local.copyWith(dueDateFrom: d));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event, size: 16),
                        label: Text(local.dueDateTo != null
                            ? '${local.dueDateTo!.day}.${local.dueDateTo!.month}'
                            : 'Bitiş'),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate:
                                local.dueDateTo ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d != null) {
                            setModalState(() =>
                                local = local.copyWith(dueDateTo: d));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Klasör',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Consumer(
                  builder: (ctx, ref, _) {
                    final filesAsync = ref.watch(taskFilesProvider);
                    return filesAsync.when(
                      data: (files) {
                        if (files.isEmpty) return const SizedBox.shrink();
                        return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            FilterChip(
                              label: const Text('Tümü'),
                              selected: local.fileId == null,
                              onSelected: (_) => setModalState(() =>
                                  local = local.copyWith(clearFileId: true)),
                            ),
                            ...files.map((f) => FilterChip(
                              label: Text(f.name),
                              selected: local.fileId == f.id,
                              onSelected: (_) => setModalState(() =>
                                  local = local.copyWith(fileId: f.id)),
                            )),
                          ],
                        );
                      },
                      loading: () => const SizedBox(height: 32),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                const Text('Oluşturan kullanıcılar',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: members.map((m) {
                    final sel = local.creatorUserIds.contains(m.userId);
                    return FilterChip(
                      label: Text(m.displayName),
                      selected: sel,
                      onSelected: (v) => setModalState(() {
                        final ids = List<String>.from(local.creatorUserIds);
                        if (v) {
                          ids.add(m.userId);
                        } else {
                          ids.remove(m.userId);
                        }
                        local = local.copyWith(creatorUserIds: ids);
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Görev önceliği',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [1, 2, 3, 4].map((p) {
                    final sel = local.priorities.contains(p);
                    return FilterChip(
                      avatar: CircleAvatar(
                        backgroundColor: PriorityColor.of(p),
                        radius: 8,
                      ),
                      label: Text(PriorityColor.label(p)),
                      selected: sel,
                      onSelected: (v) => setModalState(() {
                        final list = List<int>.from(local.priorities);
                        if (v) {
                          list.add(p);
                        } else {
                          list.remove(p);
                        }
                        local = local.copyWith(priorities: list);
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    notifier.state = local;
                    Navigator.pop(ctx);
                  },
                  child: const Text('Uygula'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(groupTaskTabProvider(widget.groupId));
    final searchQ = ref.watch(groupSearchQueryProvider(widget.groupId));
    final tasksAsync = ref.watch(groupTasksProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final projectAsync = ref.watch(projectByIdProvider(widget.groupId));
    final user = ref.watch(currentUserProvider);
    final members = membersAsync.valueOrNull ?? [];
    final group = projectAsync.valueOrNull;
    final myRole = members
        .where((m) => m.userId == user?.uid)
        .map((m) => m.role)
        .firstOrNull;
    final isOwner = group?.ownerId == user?.uid;
    final canAdd = GroupPermissions.canAddTask(myRole) || isOwner;
    final canComplete = GroupPermissions.canCompleteTask(myRole) || isOwner;
    final groupProgress = ref.watch(groupTaskProgressProvider(widget.groupId));

    var tasks = tasksAsync.valueOrNull ?? [];
    final filter = ref.watch(groupTaskFilterProvider(widget.groupId));

    if (searchQ.trim().isNotEmpty) {
      final q = searchQ.toLowerCase();
      tasks = tasks
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              (t.notes?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    if (filter.hasActiveFilters) {
      tasks = tasks.where((t) {
        if (filter.searchQuery.trim().isNotEmpty) {
          final q = filter.searchQuery.toLowerCase();
          if (!t.title.toLowerCase().contains(q) &&
              !(t.notes?.toLowerCase().contains(q) ?? false)) return false;
        }
        if (filter.createdDateFrom != null) {
          final d = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
          if (d.isBefore(filter.createdDateFrom!)) return false;
        }
        if (filter.createdDateTo != null) {
          final d = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
          if (d.isAfter(filter.createdDateTo!)) return false;
        }
        if (filter.dueDateFrom != null && t.dueAt != null) {
          final d = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
          if (d.isBefore(filter.dueDateFrom!)) return false;
        }
        if (filter.dueDateTo != null && t.dueAt != null) {
          final d = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
          if (d.isAfter(filter.dueDateTo!)) return false;
        }
        if (filter.creatorUserIds.isNotEmpty &&
            !filter.creatorUserIds.contains(t.ownerId)) return false;
        if (filter.priorities.isNotEmpty &&
            !filter.priorities.contains(t.priority)) return false;
        if (filter.fileId != null) {
          if (t.fileId != filter.fileId) return false;
        }
        return true;
      }).toList();
    }

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: Colors.white,
                  onChanged: (q) =>
                      ref.read(groupSearchQueryProvider(widget.groupId).notifier).state = q,
                  decoration: InputDecoration(
                    hintText: 'Görevlerde ara...',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 14),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search,
                        color: Colors.white.withValues(alpha: 0.60), size: 20),
                    suffixIcon: searchQ.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close,
                                color: Colors.white.withValues(alpha: 0.60),
                                size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref
                                  .read(groupSearchQueryProvider(widget.groupId)
                                      .notifier)
                                  .state = '';
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: switch (currentTab) {
                GroupTaskTab.today => TaskProgressTodaySection(
                    snapshot: groupProgress,
                    compact: true,
                  ),
                GroupTaskTab.active => TaskProgressOngoingSection(
                    snapshot: groupProgress,
                    compact: true,
                  ),
                _ => const SizedBox.shrink(),
              },
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showGroupFilterSheet(
                      context,
                      ref,
                      widget.groupId,
                      members,
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: filter.hasActiveFilters
                            ? const Color(0xFF8B40F0).withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: filter.hasActiveFilters
                              ? const Color(0xFF8B40F0)
                              : Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            size: 16,
                            color: filter.hasActiveFilters
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.75),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Filtrele',
                            style: TextStyle(
                              color: filter.hasActiveFilters
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                              fontWeight: filter.hasActiveFilters
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          if (filter.hasActiveFilters) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${(filter.searchQuery.isNotEmpty ? 1 : 0) + filter.creatorUserIds.length + filter.priorities.length + (filter.createdDateFrom != null ? 1 : 0) + (filter.createdDateTo != null ? 1 : 0) + (filter.dueDateFrom != null ? 1 : 0) + (filter.dueDateTo != null ? 1 : 0)}',
                                style: const TextStyle(
                                  color: Color(0xFF8B40F0),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const FolderManageToolbarGlassButton(),
                  ..._tabs.map((opt) {
                  final active = ref.watch(groupTaskTabProvider(widget.groupId)) == opt.tab;
                  return GestureDetector(
                    onTap: () => ref
                        .read(groupTaskTabProvider(widget.groupId).notifier)
                        .state = opt.tab,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: active
                            ? const LinearGradient(colors: [
                                Color(0xFF8B40F0),
                                Color(0xFFCF4DA6),
                              ])
                            : null,
                        color: active
                            ? null
                            : Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? Colors.transparent
                              : Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(opt.icon,
                              size: 14,
                              color: active
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.65)),
                          const SizedBox(width: 5),
                          Text(
                            opt.label,
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
                        ],
                      ),
                    ),
                  );
                }).toList(),
                ],
              ),
            ),
            Expanded(
              child: tasksAsync.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white))
                  : tasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.checklist_outlined,
                                  size: 48,
                                  color: Colors.white.withValues(alpha: 0.40)),
                              const SizedBox(height: 12),
                              Text(
                                searchQ.isNotEmpty
                                    ? 'Arama sonucu bulunamadı'
                                    : 'Bu toplulukta henüz görev yok\n"Görev Ekle" ile ekleyin',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.60),
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                          itemCount: tasks.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: TaskCard(
                              task: tasks[i],
                              showCompleteAction: canComplete,
                              groupId: widget.groupId,
                              groupMembers: members,
                            ),
                          ),
                        ),
            ),
          ],
        ),
        if (canAdd)
          Positioned(
            right: 16,
            bottom: 16,
            child: PinkFab(
              heroTag: 'fab_community_${widget.groupId}',
              onTap: () => context.push(
                  '${AppRoutes.taskForm}?groupId=${widget.groupId}'),
            ),
          ),
      ],
    );
  }
}
