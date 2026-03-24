import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../data/repositories/task_repository.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/entities/subtask_entity.dart';
import '../../services/auto_sync_service.dart';
import '../../services/subtask_storage.dart';
import '../../services/task_view_storage.dart';
import '../auth/auth_provider.dart';
import '../tasks/widgets/home_background.dart';
import 'providers/tasks_provider.dart'
    show taskByIdProvider, groupMembersProvider, subtasksProvider;

const _uuid = Uuid();

String _firstCharUpper(String s) {
  if (s.isEmpty) return '?';
  final it = s.runes.iterator;
  if (!it.moveNext()) return '?';
  return String.fromCharCode(it.current).toUpperCase();
}

// ─── Comments (local) ──────────────────────────────────────────────────────
String _commentsKey(String taskId) => 'comments_$taskId';

Future<List<CommentEntity>> _loadComments(String taskId) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_commentsKey(taskId));
  if (raw == null) return [];
  try {
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(CommentEntity.fromJson)
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> _saveComments(
    String taskId, List<CommentEntity> list) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      _commentsKey(taskId), jsonEncode(list.map((c) => c.toJson()).toList()));
}

// ─── Screen ───────────────────────────────────────────────────────────────
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskByIdProvider(taskId));

    return taskAsync.when(
      loading: () => Stack(children: [
        const HomeBackground(),
        const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ]),
      error: (e, _) => Stack(children: [
        const HomeBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
              child: Text('Hata: $e',
                  style: const TextStyle(color: Colors.white))),
        ),
      ]),
      data: (task) {
        if (task == null) {
          return Stack(children: [
            const HomeBackground(),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                foregroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
              ),
              body: const Center(
                  child: Text('Görev bulunamadı',
                      style: TextStyle(color: Colors.white))),
            ),
          ]);
        }
        return _TaskDetail(task: task);
      },
    );
  }
}

class _TaskDetail extends ConsumerStatefulWidget {
  const _TaskDetail({required this.task});

  final TaskEntity task;

  @override
  ConsumerState<_TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends ConsumerState<_TaskDetail> {
  final _commentCtrl = TextEditingController();
  final _subtaskCtrl = TextEditingController();

  List<SubtaskEntity> _subtasks = [];
  List<CommentEntity> _comments = [];
  List<TaskViewRecord> _taskViews = [];
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final subs = await loadSubtasks(widget.task.id);
    final coms = await _loadComments(widget.task.id);
    final views = await loadTaskViews(widget.task.id);
    _recordView();
    if (mounted) {
      setState(() {
        _subtasks = subs;
        _comments = coms;
        _taskViews = views;
        _loadingData = false;
      });
    }
  }

  Future<void> _recordView() async {
    final user = ref.read(currentUserProvider);
    if (user == null || widget.task.projectId == null) return;
    final membersAsync = ref.read(groupMembersProvider(widget.task.projectId!));
    final members = membersAsync.valueOrNull ?? [];
    final m = members.where((x) => x.userId == user.uid).firstOrNull;
    final role = switch (m?.role) {
      'yonetici' || 'owner' => 'Yönetici',
      'kıdemli' => 'Kıdemli',
      _ => 'Üye',
    };
    await recordTaskView(TaskViewRecord(
      taskId: widget.task.id,
      userId: user.uid,
      userDisplayName:
          user.displayName.isEmpty ? 'Kullanıcı' : user.displayName,
      userRole: role,
      viewedAt: DateTime.now(),
    ));
    if (mounted) {
      final views = await loadTaskViews(widget.task.id);
      setState(() => _taskViews = views);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _subtaskCtrl.dispose();
    super.dispose();
  }

  String _memberName(String? userId) {
    if (userId == null || widget.task.projectId == null) return '';
    final membersAsync = ref.watch(groupMembersProvider(widget.task.projectId!));
    final members = membersAsync.valueOrNull ?? [];
    final m = members.where((x) => x.userId == userId).firstOrNull;
    return m?.displayName ?? userId;
  }

  String _memberRole(String userId) {
    if (widget.task.projectId == null) return '';
    final membersAsync = ref.watch(groupMembersProvider(widget.task.projectId!));
    final members = membersAsync.valueOrNull ?? [];
    final m = members.where((x) => x.userId == userId).firstOrNull;
    if (m == null) return '';
    return switch (m.role) {
      'yonetici' || 'owner' => 'Yönetici',
      'kıdemli' => 'Kıdemli',
      _ => 'Üye',
    };
  }

  String _memberEmail(String? userId) {
    if (userId == null || widget.task.projectId == null) return '';
    final membersAsync = ref.watch(groupMembersProvider(widget.task.projectId!));
    final members = membersAsync.valueOrNull ?? [];
    final m = members.where((x) => x.userId == userId).firstOrNull;
    return m?.email ?? '';
  }

  String _creatorName() => _memberName(widget.task.ownerId);
  String _creatorRole() => _memberRole(widget.task.ownerId);

  String _editorDisplayName(String userId) {
    if (widget.task.projectId != null) return _memberName(userId);
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser?.uid == userId) return 'Siz';
    return userId;
  }

  String _editorRole(String userId) {
    if (widget.task.projectId != null) return _memberRole(userId);
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final task = widget.task;
    final priorityColor = PriorityColor.of(task.priority);

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
        actions: [
          if (!task.isDeleted)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: () =>
                  context.push('${AppRoutes.taskForm}?taskId=${task.id}'),
            ),
          if (!task.isDeleted)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6B8A)),
              onPressed: () => _delete(context),
            ),
          if (task.isDeleted) ...[
            TextButton.icon(
              icon: const Icon(Icons.restore, color: Colors.white),
              label: const Text('Geri Yükle',
                  style: TextStyle(color: Colors.white)),
              onPressed: () => _restore(context),
            ),
          ],
        ],
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Title + Priority ───────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style:
                            Theme.of(context).textTheme.displayLarge?.copyWith(
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted
                              ? cs.onSurface.withValues(alpha: 0.4)
                              : cs.onSurface,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        PriorityColor.name(task.priority),
                        style: TextStyle(
                          color: priorityColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Complete button ────────────────────────────────
                if (!task.isDeleted)
                  Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _toggleComplete(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              task.isCompleted
                                  ? Icons.undo_rounded
                                  : Icons.check_circle_outline,
                              color: task.isCompleted
                                  ? const Color(0xFF10B981)
                                  : cs.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              task.isCompleted
                                  ? 'Geri Al'
                                  : 'Tamamlandı Olarak İşaretle',
                              style: TextStyle(
                                color: task.isCompleted
                                    ? const Color(0xFF10B981)
                                    : cs.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),

                // ── Notes ─────────────────────────────────────────
                if (task.notes != null && task.notes!.isNotEmpty) ...[
                  _MetaSection(title: 'Notlar', child: Text(task.notes!)),
                  const SizedBox(height: 16),
                ],

                // ── Meta info ─────────────────────────────────────
                _MetaRow(items: [
                  if (task.dueAt != null)
                    _MetaItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'Son Tarih',
                      value: DateFormat('d MMMM yyyy, HH:mm', 'tr_TR')
                          .format(task.dueAt!),
                      color: task.isOverdue ? cs.error : null,
                    ),
                  if (task.reminderAt != null)
                    _MetaItem(
                      icon: Icons.notifications_outlined,
                      label: 'Hatırlatıcı',
                      value: DateFormat('d MMM, HH:mm', 'tr_TR')
                          .format(task.reminderAt!),
                    ),
                  if (task.recurrenceRule != 'none')
                    _MetaItem(
                      icon: Icons.repeat_rounded,
                      label: 'Tekrar',
                      value: _recurrenceLabel(task.recurrenceRule),
                    ),
                ]),

                if (task.labels.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: task.labels
                        .map((l) => Chip(
                              label: Text('#$l'),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],

                // ── Subtasks ──────────────────────────────────────
                const SizedBox(height: 20),
                _MetaSection(
                  title: 'Alt Görevler',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_subtasks.isEmpty)
                        Text('Henüz alt görev yok.',
                            style: Theme.of(context).textTheme.bodySmall)
                      else
                        ..._subtasks
                            .map((s) => _SubtaskItem(
                                  sub: s,
                                  onToggle: () => _toggleSubtask(s),
                                  memberName: _memberName(s.completedByUserId),
                                  memberRole: _memberRole(s.completedByUserId ?? ''),
                                  memberEmail: _memberEmail(s.completedByUserId),
                                  onTapOnayVerenler: s.isCompleted
                                      ? () => _showOnayVerenler(s)
                                      : null,
                                ))
                            .toList(),
                      if (!task.isDeleted) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _subtaskCtrl,
                                style: const TextStyle(color: Colors.black87),
                                decoration: const InputDecoration(
                                  hintText: 'Alt görev ekle...',
                                  hintStyle: TextStyle(color: Colors.black38),
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _addSubtask(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _addSubtask,
                              icon: const Icon(Icons.add, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Yorum yapanlar (metinler sadece tıklanınca panelde) ──
                _MetaSection(
                  title: 'Yorum yapanlar',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_comments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text('Henüz yorum yok.',
                              style: Theme.of(context).textTheme.bodySmall),
                        )
                      else
                        _CommentAuthorsStrip(
                          comments: _comments,
                          onUserTap: _openUserCommentsPanel,
                        ),
                      const SizedBox(height: 8),
                      if (!task.isDeleted)
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentCtrl,
                                style: const TextStyle(color: Colors.black87),
                                decoration: const InputDecoration(
                                  hintText: 'Yorum ekle...',
                                  hintStyle: TextStyle(color: Colors.black38),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _addComment,
                              icon: const Icon(Icons.send_rounded, size: 18),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // ── Footer ────────────────────────────────────────
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                if (task.updatedByUserId != null) ...[
                  _UserInfoRow(
                    icon: Icons.edit_outlined,
                    label: 'Düzenleyen',
                    name: _editorDisplayName(task.updatedByUserId!),
                    role: _editorRole(task.updatedByUserId!),
                    date: task.updatedAt,
                  ),
                  const SizedBox(height: 4),
                ],
                if (task.projectId != null) ...[
                  _UserInfoRow(
                    icon: Icons.person_add_outlined,
                    label: 'Oluşturan',
                    name: _creatorName(),
                    role: _creatorRole(),
                    date: task.createdAt,
                  ),
                  if (task.isCompleted && task.completedByUserId != null) ...[
                    const SizedBox(height: 4),
                    _UserInfoRow(
                      icon: Icons.check_circle_outline,
                      label: 'Tamamlayan',
                      name: _memberName(task.completedByUserId),
                      role: _memberRole(task.completedByUserId!),
                      date: task.completedAt,
                    ),
                  ],
                  if (task.isDeleted && task.deletedByUserId != null) ...[
                    const SizedBox(height: 4),
                    _UserInfoRow(
                      icon: Icons.delete_outline,
                      label: 'Silen',
                      name: _memberName(task.deletedByUserId),
                      role: _memberRole(task.deletedByUserId!),
                      date: task.deletedAt,
                    ),
                  ],
                  if (_taskViews.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _MetaSection(
                      title: 'Görüntüleyenler',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _taskViews.map((v) => _ViewerChip(
                          name: v.userDisplayName,
                          role: v.userRole,
                          date: v.viewedAt,
                        )).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
                Text(
                  'Oluşturuldu: ${DateFormat('d MMM yyyy, HH:mm', 'tr_TR').format(task.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Güncellendi: ${DateFormat('d MMM yyyy, HH:mm', 'tr_TR').format(task.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 48),
              ],
            ),
        ),
      ],
    );
  }

  String _recurrenceLabel(String r) => switch (r) {
        'daily' => 'Her gün',
        'weekly' => 'Her hafta',
        'monthly' => 'Her ay',
        _ => r,
      };

  Future<void> _toggleComplete(BuildContext context) async {
    HapticFeedback.lightImpact();
    final userId = ref.read(currentUserProvider)?.uid;
    final repo = ref.read(taskRepositoryProvider);
    await repo.completeTask(widget.task.id,
        undo: widget.task.isCompleted, completedByUserId: userId);
    ref.invalidate(taskByIdProvider(widget.task.id));
  }

  Future<void> _delete(BuildContext context) async {
    final userId = ref.read(currentUserProvider)?.uid;
    final repo = ref.read(taskRepositoryProvider);
    await repo.softDeleteTask(widget.task.id, deletedByUserId: userId);
    ref.invalidate(taskByIdProvider(widget.task.id));
    if (context.mounted) context.pop();
  }

  Future<void> _restore(BuildContext context) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.restoreTask(widget.task.id);
    ref.invalidate(taskByIdProvider(widget.task.id));
    if (context.mounted) context.pop();
  }

  Future<void> _addSubtask() async {
    final title = _subtaskCtrl.text.trim();
    if (title.isEmpty) return;
    final newSub = SubtaskEntity(
      id: _uuid.v4(),
      taskId: widget.task.id,
      title: title,
      sortOrder: _subtasks.length,
      createdAt: DateTime.now(),
    );
    final updated = [..._subtasks, newSub];
    await saveSubtasks(widget.task.id, updated);
    ref.invalidate(subtasksProvider(widget.task.id));
    AutoSyncService.instance.flush();
    _subtaskCtrl.clear();
    if (mounted) setState(() => _subtasks = updated);
  }

  Future<void> _toggleSubtask(SubtaskEntity sub) async {
    final userId = ref.read(currentUserProvider)?.uid;
    final now = DateTime.now();
    final updated = _subtasks
        .map((s) => s.id == sub.id
            ? s.copyWith(
                isCompleted: !s.isCompleted,
                completedByUserId: !s.isCompleted ? userId : null,
                completedAt: !s.isCompleted ? now : null,
                clearCompletedBy: s.isCompleted,
              )
            : s)
        .toList();
    await saveSubtasks(widget.task.id, updated);
    ref.invalidate(subtasksProvider(widget.task.id));
    AutoSyncService.instance.flush();
    if (mounted) setState(() => _subtasks = updated);
  }

  void _showOnayVerenler(SubtaskEntity sub) {
    if (sub.completedByUserId == null) return;
    final name = _memberName(sub.completedByUserId);
    final role = _memberRole(sub.completedByUserId!);
    final email = _memberEmail(sub.completedByUserId);
    final dateStr = sub.completedAt != null
        ? DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(sub.completedAt!)
        : '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Onay verenler'),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profil fotoğrafı (avatar)
              CircleAvatar(
                radius: 48,
                backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.email_outlined, size: 14,
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Text(
                      email,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 18,
                        color: Theme.of(ctx).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Tamamlama: $dateStr',
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _addComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider)!;
    final newComment = CommentEntity(
      id: _uuid.v4(),
      taskId: widget.task.id,
      userId: user.uid,
      userDisplayName:
          user.displayName.isEmpty ? 'Kullanıcı' : user.displayName,
      body: text,
      createdAt: DateTime.now(),
    );
    final updated = [..._comments, newComment];
    await _saveComments(widget.task.id, updated);
    _commentCtrl.clear();
    if (mounted) setState(() => _comments = updated);
  }

  void _openUserCommentsPanel(String userId, String displayName) {
    final list = _comments.where((c) => c.userId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (list.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final maxH = MediaQuery.sizeOf(ctx).height * 0.55;
        return SafeArea(
          child: SizedBox(
            height: maxH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          displayName.isNotEmpty
                              ? _firstCharUpper(displayName)
                              : '?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: Theme.of(ctx).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${list.length} yorum',
                              style: Theme.of(ctx).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: cs.outline.withValues(alpha: 0.2)),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return Material(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('d MMM yyyy, HH:mm', 'tr_TR')
                                    .format(c.createdAt),
                                style: Theme.of(ctx).textTheme.labelSmall
                                    ?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                c.body,
                                style: Theme.of(ctx).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────
class _SubtaskItem extends StatelessWidget {
  const _SubtaskItem({
    required this.sub,
    required this.onToggle,
    this.memberName = '',
    this.memberRole = '',
    this.memberEmail = '',
    this.onTapOnayVerenler,
  });

  final SubtaskEntity sub;
  final VoidCallback onToggle;
  final String memberName;
  final String memberRole;
  final String memberEmail;
  final VoidCallback? onTapOnayVerenler;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sol taraf: Onay verenler butonu (sadece tamamlanmış alt görevlerde)
          if (sub.isCompleted && onTapOnayVerenler != null)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTapOnayVerenler,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 14, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Onay verenler',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else if (!sub.isCompleted)
            const SizedBox(width: 4),
          // Checkbox + başlık
          Expanded(
            child: CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                sub.title,
                style: TextStyle(
                  decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
                  color: sub.isCompleted
                      ? cs.onSurface.withValues(alpha: 0.4)
                      : null,
                ),
              ),
              value: sub.isCompleted,
              onChanged: (_) => onToggle(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerChip extends StatelessWidget {
  const _ViewerChip({
    required this.name,
    required this.role,
    required this.date,
  });

  final String name;
  final String role;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = <String>[name];
    if (role.isNotEmpty) parts.add(role);
    parts.add(DateFormat('d MMM yyyy, HH:mm', 'tr_TR').format(date));
    return Chip(
      avatar: CircleAvatar(
        radius: 12,
        backgroundColor: cs.primaryContainer,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(color: cs.onPrimaryContainer, fontSize: 11),
        ),
      ),
      label: Text(parts.join(' • '), style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _UserInfoRow extends StatelessWidget {
  const _UserInfoRow({
    required this.icon,
    required this.label,
    required this.name,
    required this.role,
    required this.date,
  });

  final IconData icon;
  final String label;
  final String name;
  final String role;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[name];
    if (role.isNotEmpty) parts.add(role);
    if (date != null) parts.add(DateFormat('d MMM yyyy, HH:mm', 'tr_TR').format(date!));
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Text(
          '$label: ${parts.join(' • ')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Yorum yapan benzersiz kullanıcılar — tıklanınca o kullanıcının yorumları açılır.
class _CommentAuthorsStrip extends StatelessWidget {
  const _CommentAuthorsStrip({
    required this.comments,
    required this.onUserTap,
  });

  final List<CommentEntity> comments;
  final void Function(String userId, String displayName) onUserTap;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final authors = <CommentEntity>[];
    for (final c in comments) {
      if (seen.add(c.userId)) {
        authors.add(c);
      }
    }
    if (authors.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in authors)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: () => onUserTap(c.userId, c.userDisplayName),
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          c.userDisplayName.isNotEmpty
                              ? _firstCharUpper(c.userDisplayName)
                              : '?',
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 76),
                        child: Text(
                          c.userDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaSection extends StatelessWidget {
  const _MetaSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.45),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.items});

  final List<_MetaItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 12, runSpacing: 8, children: items);
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface.withValues(alpha: 0.6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 10, color: c.withValues(alpha: 0.7))),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    color: c,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}
