import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:todo_note/app/router.dart';
import 'package:todo_note/data/repositories/chat_repository.dart';
import 'package:todo_note/domain/entities/message_entity.dart';
import 'package:todo_note/domain/entities/project_entity.dart';
import 'package:todo_note/features/auth/auth_provider.dart';
import 'package:todo_note/domain/group_permissions.dart';
import 'package:todo_note/data/repositories/task_repository.dart'
    show WebTaskRepository;
import 'package:todo_note/features/tasks/providers/tasks_provider.dart'
    show GroupTaskTab, groupAllTasksCountProvider, groupMembersProvider,
        groupTaskTabProvider, groupSearchQueryProvider, groupTasksProvider,
        sharedGroupsProvider, groupTaskFilterProvider, groupTaskProgressProvider,
        taskFilesProvider;
import 'package:todo_note/features/tasks/providers/group_filter_provider.dart';
import 'package:todo_note/app/theme.dart' show PriorityColor;
import 'package:todo_note/features/tasks/widgets/folder_manage_bottom_sheet.dart';
import 'package:todo_note/features/tasks/widgets/home_background.dart';
import 'package:todo_note/features/tasks/widgets/task_card.dart';
import 'package:todo_note/features/tasks/widgets/task_progress_dual_section.dart'
    show TaskProgressTodaySection, TaskProgressOngoingSection;
import 'package:todo_note/features/chat/widgets/chat_attach_sheet.dart';
import 'package:todo_note/features/chat/widgets/message_content_widget.dart';
import 'package:todo_note/features/collaboration/group_badge_widget.dart'
    show totalGroupMessageBadgeProvider, totalGroupTaskBadgeProvider;
import 'package:todo_note/features/collaboration/group_notification_providers.dart';
import 'package:todo_note/services/group_notification_storage.dart';
import 'package:todo_note/ui/widgets/pink_fab.dart';

// ─── Providers for this screen ────────────────────────────────────────────────

final _groupMessagesProvider =
    StreamProvider.family<List<MessageEntity>, String>((ref, convId) {
  return ChatRepository.instance.watchMessages(convId);
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  String get _convId => 'group_proj_${widget.groupId}';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WebTaskRepository.instance.init();
      // İlk açılışta görüntülenen sekmenin bildirimini sıfırla
      if (mounted) _updateBadgesForTab(_tabCtrl.index);
    });
  }

  void _onTabChanged() {
    // Tab değişimi tamamlandığında çalış (indexIsChanging false olduğunda)
    if (_tabCtrl.indexIsChanging) return;
    _updateBadgesForTab(_tabCtrl.index);
  }

  /// Sadece veri yüklüyse bildirimi sıfırla (görüntülenen = işaretle)
  void _updateBadgesForTab(int tab) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (tab == 0) {
      final convId = 'group_proj_${widget.groupId}';
      final msgsAsync = ref.read(_groupMessagesProvider(convId));
      if (!msgsAsync.hasValue) return; // Veri yüklenmeden güncelleme
      final msgs = msgsAsync.valueOrNull ?? [];
      final uid = user.uid;
      final visible = msgs
          .where((m) =>
              !m.isDeleted && !m.deletedForUserIds.contains(uid))
          .length;
      setLastViewedMessageCount(user.uid, widget.groupId, visible);
      ref.invalidate(groupMessageBadgeProvider(widget.groupId));
      ref.invalidate(totalGroupMessageBadgeProvider);
    } else if (tab == 1) {
      final countAsync = ref.read(groupAllTasksCountProvider(widget.groupId));
      if (!countAsync.hasValue) return; // Veri yüklenmeden güncelleme
      final count = countAsync.valueOrNull ?? 0;
      setLastViewedTaskCount(user.uid, widget.groupId, count);
      ref.invalidate(groupTaskBadgeProvider(widget.groupId));
      ref.invalidate(totalGroupTaskBadgeProvider);
    }
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    // NOT: ref.read() dispose() içinde çağrılamaz (Riverpod hata verir).
    // Badge'ler onTabChanged ve ref.listen ile zaten güncellenir.
    _tabCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    final groupAsync = ref.watch(sharedGroupsProvider);

    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));

    final group = groupAsync.valueOrNull
        ?.where((p) => p.id == widget.groupId)
        .firstOrNull;

    final members = membersAsync.valueOrNull ?? [];

    // Sekmede görüntülerken veri yüklendiğinde veya güncellendiğinde bildirimi sıfırla
    ref.listen(_groupMessagesProvider(_convId), (_, next) {
      if (next.hasValue && _tabCtrl.index == 0 && !_tabCtrl.indexIsChanging) {
        _updateBadgesForTab(0);
      }
    });
    ref.listen(groupAllTasksCountProvider(widget.groupId), (_, next) {
      if (next.hasValue && _tabCtrl.index == 1 && !_tabCtrl.indexIsChanging) {
        _updateBadgesForTab(1);
      }
    });

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
                Text(
                  group?.name ?? 'Grup',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${members.length} üye',
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
                onPressed: () =>
                    context.push('${AppRoutes.groupSettings}/${widget.groupId}'),
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
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              // ── Chat Tab ─────────────────────────────────────────────────
              _ChatTab(
                convId: _convId,
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

              // ── Tasks Tab ─────────────────────────────────────────────────
              _TasksTab(groupId: widget.groupId),
            ],
          ),
        ),
      ],
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
      await ChatRepository.instance.editMessage(_convId, msg.id, result);
    }
  }

  Future<void> _deleteForMe(MessageEntity msg, String? userId) async {
    if (userId == null) return;
    await ChatRepository.instance.deleteMessageForMe(_convId, msg.id, userId);
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
      await ChatRepository.instance.deleteMessageForEveryone(_convId, msg.id);
    }
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

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _sending = true);
    try {
      await ChatRepository.instance.sendMessage(
        conversationId: _convId,
        senderId: user.uid,
        senderName: user.displayName,
        content: text,
        ownerUid: user.uid,
        participantUids: [user.uid],
      );
      _msgCtrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAttachment(String content) async {
    final user = ref.read(currentUserProvider);
    if (user == null || _sending) return;

    setState(() => _sending = true);
    try {
      await ChatRepository.instance.sendMessage(
        conversationId: _convId,
        senderId: user.uid,
        senderName: user.displayName,
        content: content,
        ownerUid: user.uid,
        participantUids: [user.uid],
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

// ─── Chat Tab ─────────────────────────────────────────────────────────────────

class _ChatTab extends ConsumerWidget {
  const _ChatTab({
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
    final messagesAsync = ref.watch(_groupMessagesProvider(convId));
    var messages = messagesAsync.valueOrNull ?? [];
    final uid = currentUser?.uid;
    messages = messages
        .where((m) =>
            !m.isDeleted &&
            (uid == null || !m.deletedForUserIds.contains(uid)))
        .toList();

    return Column(
      children: [
        // Messages list
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
                        'Henüz mesaj yok\nGrubunuza ilk mesajı gönderin!',
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
                    final isAttachment = msg.content.startsWith(kMsgPrefixImage) ||
                        msg.content.startsWith(kMsgPrefixDocument) ||
                        msg.content.startsWith(kMsgPrefixContact) ||
                        msg.content.startsWith(kMsgPrefixPoll);
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

        // Message input
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
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: TextField(
                    controller: msgCtrl,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: 'Mesaj yaz...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                      colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)],
                    ),
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

// ─── Message Bubble ───────────────────────────────────────────────────────────

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
    if (isSystemSettings) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: const Color(0xFFEF4444)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    msg.content,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final hasMenu =
        onEdit != null || onDeleteForMe != null || onDeleteForEveryone != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF8B40F0).withValues(alpha: 0.70),
              child: Text(
                msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isMe && hasMenu) ...[
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
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
                          value: 'edit',
                          child: Text('Düzenle'),
                        ),
                      if (onDeleteForMe != null)
                        const PopupMenuItem(
                          value: 'delete_me',
                          child: Text('Benden sil'),
                        ),
                      if (onDeleteForEveryone != null)
                        const PopupMenuItem(
                          value: 'delete_all',
                          child: Text('Herkesten sil',
                              style: TextStyle(color: Color(0xFFEF4444))),
                        ),
                    ],
                  ),
                  const SizedBox(width: 2),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        Text(
                          msg.senderName,
                          style: const TextStyle(
                            color: Color(0xFFCF4DA6),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      buildMessageContent(msg.content, isMe: isMe),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _fmtTime(msg.sentAt),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                          if (msg.editedAt != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(düzenlendi)',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ],
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

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─── Tasks Tab ────────────────────────────────────────────────────────────────

class _TasksTab extends ConsumerStatefulWidget {
  const _TasksTab({required this.groupId});
  final String groupId;

  @override
  ConsumerState<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<_TasksTab> {
  final _searchCtrl = TextEditingController();

  static final _tabs = [
    (tab: GroupTaskTab.active,  label: 'Devam Eden', icon: Icons.timelapse_rounded),
    (tab: GroupTaskTab.today,   label: 'Bugün',       icon: Icons.today_rounded),
    (tab: GroupTaskTab.done,    label: 'Bitti',        icon: Icons.check_circle_outline),
    (tab: GroupTaskTab.deleted, label: 'Silindi',      icon: Icons.delete_outline),
    (tab: GroupTaskTab.all,     label: 'Tümü',         icon: Icons.list_rounded),
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
                    const Text('Filtrele', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                    )),
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
                  onChanged: (v) => setModalState(() =>
                      local = local.copyWith(searchQuery: v)),
                  controller: TextEditingController(text: local.searchQuery),
                ),
                const SizedBox(height: 12),
                const Text('Oluşturulma tarihi', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                )),
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
                            initialDate: local.createdDateFrom ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d != null) setModalState(() =>
                              local = local.copyWith(createdDateFrom: d));
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
                            initialDate: local.createdDateTo ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d != null) setModalState(() =>
                              local = local.copyWith(createdDateTo: d));
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Görev zamanı (son tarih)', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                )),
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
                            initialDate: local.dueDateFrom ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d != null) setModalState(() =>
                              local = local.copyWith(dueDateFrom: d));
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
                            initialDate: local.dueDateTo ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d != null) setModalState(() =>
                              local = local.copyWith(dueDateTo: d));
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Klasör', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                )),
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
                const Text('Oluşturan kullanıcılar', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                )),
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
                        if (v) ids.add(m.userId);
                        else ids.remove(m.userId);
                        local = local.copyWith(creatorUserIds: ids);
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Görev önceliği', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                )),
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
                        if (v) list.add(p);
                        else list.remove(p);
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
    final searchQ    = ref.watch(groupSearchQueryProvider(widget.groupId));
    final tasksAsync = ref.watch(groupTasksProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final groupAsync = ref.watch(sharedGroupsProvider);
    final user = ref.watch(currentUserProvider);
    final members = membersAsync.valueOrNull ?? [];
    final group = groupAsync.valueOrNull
        ?.where((p) => p.id == widget.groupId)
        .firstOrNull;
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

    // Apply search filter
    if (searchQ.trim().isNotEmpty) {
      final q = searchQ.toLowerCase();
      tasks = tasks
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              (t.notes?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    // Apply group filter
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
            // ── Search bar ──────────────────────────────────────────────────
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
                  onChanged: (q) => ref
                      .read(groupSearchQueryProvider(widget.groupId).notifier)
                      .state = q,
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

            // ── Filtrele + Filter tabs ─────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  // Filtrele butonu (sol taraf)
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
                  final active = currentTab == opt.tab;
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
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF8B40F0)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
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

            // ── Task list ──────────────────────────────────────────────────
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
                                    : 'Bu grupta henüz görev yok\n"Görev Ekle" ile ekleyin',
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
                          padding:
                              const EdgeInsets.fromLTRB(12, 4, 12, 100),
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

        // FAB — grup context'i ile görev ekle (yetkiye göre)
        if (canAdd)
          Positioned(
            right: 16,
            bottom: 16,
            child: PinkFab(
              heroTag: 'fab_group_${widget.groupId}',
              onTap: () => context.push(
                '${AppRoutes.taskForm}?groupId=${widget.groupId}',
              ),
            ),
          ),
      ],
    );
  }
}
