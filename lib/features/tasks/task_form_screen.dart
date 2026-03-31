import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/repositories/task_repository.dart';
import '../../domain/entities/subtask_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../../services/auto_sync_service.dart';
import '../../services/notification_service.dart';
import '../../services/subtask_storage.dart';
import '../../services/task_history_service.dart';
import '../auth/auth_provider.dart';
import 'widgets/create_folder_dialog.dart';
import 'widgets/home_background.dart';
import 'package:todo_note/app/app_l10n.dart';

import 'providers/tasks_provider.dart'
    show groupTasksProvider, subtasksProvider, taskFilesProvider;

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.taskId, this.groupId});

  final String? taskId;
  final String? groupId; // pre-fills projectId when coming from group screen

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  DateTime? _dueAt;
  DateTime? _reminderAt;
  int _priority = 4;
  String _recurrence = 'none';
  List<String> _labels = [];
  String? _projectId;
  String? _fileId;
  bool _loading = false;
  bool _isEdit = false;
  TaskEntity? _original;

  final _subtaskCtrl = TextEditingController();
  final List<String> _subtasks = [];

  @override
  void initState() {
    super.initState();
    if (widget.groupId != null) {
      _projectId = widget.groupId;
    }
    if (widget.taskId != null) {
      _isEdit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTask());
    }
  }

  Future<void> _loadTask() async {
    final repo = ref.read(taskRepositoryProvider);
    final task = await repo.getTaskById(widget.taskId!);
    if (task != null && mounted) {
      final subs = await loadSubtasks(task.id);
      setState(() {
        _original = task;
        _titleCtrl.text = task.title;
        _notesCtrl.text = task.notes ?? '';
        _dueAt = task.dueAt;
        _reminderAt = task.reminderAt;
        _priority = task.priority;
        _recurrence = task.recurrenceRule;
        _labels = List.from(task.labels);
        _projectId = task.projectId;
        _fileId = task.fileId;
        _subtasks.clear();
        _subtasks.addAll(subs.map((s) => s.title));
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _tagCtrl.dispose();
    _subtaskCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            title: Text(
              _isEdit ? 'Görevi Düzenle' : 'Görev Ekle',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            actions: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                )
              else
                TextButton(
                  onPressed: _save,
                  child: const Text(
                    'Kaydet',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Title ───────────────────────────────────────────────
            Builder(builder: (ctx) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              final textColor = isDark ? Colors.white : Colors.black;
              final hintColor = isDark
                  ? Colors.white.withValues(alpha: 0.40)
                  : Colors.black38;
              final cardColor = isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.90);
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: isDark
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.14))
                          : null,
                    ),
                    child: TextFormField(
                      controller: _titleCtrl,
                      autofocus: !_isEdit,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Görev başlığı...',
                        hintStyle: TextStyle(color: hintColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Başlık gerekli'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: isDark
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.14))
                          : null,
                    ),
                    child: TextFormField(
                      controller: _notesCtrl,
                      maxLines: 4,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Notlar ekle...',
                        hintStyle: TextStyle(color: hintColor),
                        contentPadding: const EdgeInsets.all(14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 20),
            const Divider(),

            // ── Date & Time ─────────────────────────────────────────
            _FormSection(
              children: [
                _FieldTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Son Tarih',
                  value: _dueAt != null
                      ? DateFormat('d MMM yyyy – HH:mm', 'tr_TR').format(_dueAt!)
                      : null,
                  placeholder: 'Tarih seç',
                  onTap: _pickDueDate,
                  onClear: _dueAt != null ? () => setState(() => _dueAt = null) : null,
                ),
                _FieldTile(
                  icon: Icons.notifications_outlined,
                  label: 'Hatırlatıcı',
                  value: _reminderAt != null
                      ? DateFormat('d MMM – HH:mm', 'tr_TR').format(_reminderAt!)
                      : null,
                  placeholder: 'Hatırlatma ayarla',
                  onTap: _pickReminder,
                  onClear: _reminderAt != null
                      ? () => setState(() => _reminderAt = null)
                      : null,
                ),
                if (_reminderAt != null)
                  _DropdownTile(
                    icon: Icons.repeat_rounded,
                    label: 'Tekrar',
                    value: _recurrence,
                    items: const {
                      'none': 'Tekrarsız',
                      'daily': 'Her gün',
                      'weekly': 'Her hafta',
                      'monthly': 'Her ay',
                    },
                    onChanged: (v) => setState(() => _recurrence = v!),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Priority ────────────────────────────────────────────
            _FormSection(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 20,
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Öncelik',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(4, (i) {
                          final p = i + 1;
                          final color = PriorityColor.of(p);
                          final selected = _priority == p;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _priority = p),
                              child: Container(
                                margin: EdgeInsets.only(
                                  right: i < 3 ? 6 : 0,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? color
                                      : color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: selected
                                      ? null
                                      : Border.all(
                                          color: color.withOpacity(0.4),
                                        ),
                                ),
                                child: Text(
                                  PriorityColor.label(p),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Labels ──────────────────────────────────────────────
            _FormSection(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.label_outline,
                            size: 20,
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Etiketler',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      if (_labels.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          children: _labels
                              .map(
                                (l) => Chip(
                                  label: Text('#$l'),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () =>
                                      setState(() => _labels.remove(l)),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _tagCtrl,
                              style: const TextStyle(color: Colors.black),
                              decoration: const InputDecoration(
                                hintText: 'Etiket ekle...',
                                hintStyle: TextStyle(color: Colors.black38),
                                isDense: true,
                              ),
                              onSubmitted: _addLabel,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => _addLabel(_tagCtrl.text),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Klasörlerim (kişisel ve grup görevleri için kategorileme) ───
            _FolderSection(
                fileId: _fileId,
                onFileChanged: (id) => setState(() => _fileId = id),
              ),

            const SizedBox(height: 12),

            // ── Subtasks ────────────────────────────────────────────
            _FormSection(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.checklist_rounded,
                            size: 20,
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Alt Görevler',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      ..._subtasks.map(
                        (s) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.radio_button_unchecked,
                            size: 18,
                          ),
                          title: Text(s),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () =>
                                setState(() => _subtasks.remove(s)),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _subtaskCtrl,
                              style: const TextStyle(color: Colors.black),
                              decoration: const InputDecoration(
                                hintText: 'Alt görev ekle...',
                                hintStyle: TextStyle(color: Colors.black38),
                                isDense: true,
                              ),
                              onSubmitted: (v) {
                                if (v.trim().isNotEmpty) {
                                  setState(() {
                                    _subtasks.add(v.trim());
                                    _subtaskCtrl.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              if (_subtaskCtrl.text.trim().isNotEmpty) {
                                setState(() {
                                  _subtasks.add(_subtaskCtrl.text.trim());
                                  _subtaskCtrl.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // TODO(v2): Attachments (photo/file upload)
            // TODO(v2): Location-based reminders
            const SizedBox(height: 96),
          ],
        ),
      ),
        ),
      ],
    );
  }

  void _addLabel(String value) {
    final v = value.trim().replaceAll('#', '');
    if (v.isNotEmpty && !_labels.contains(v)) {
      setState(() => _labels.add(v));
    }
    _tagCtrl.clear();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final minDue = now.add(const Duration(minutes: 1));
    final initialDate = _dueAt != null && _dueAt!.isAfter(minDue)
        ? _dueAt!
        : minDue;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;
    final initialTime = _dueAt != null && _dueAt!.isAfter(minDue)
        ? TimeOfDay.fromDateTime(_dueAt!)
        : TimeOfDay.fromDateTime(minDue);
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (!mounted) return;
    var due = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? minDue.hour,
      time?.minute ?? minDue.minute,
    );
    if (due.isBefore(minDue)) due = minDue;
    setState(() => _dueAt = due);
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final minRem = now.add(const Duration(minutes: 1));
    final initialDate = (_reminderAt != null && _reminderAt!.isAfter(minRem))
        ? _reminderAt!
        : (_dueAt != null && _dueAt!.isAfter(minRem))
            ? _dueAt!
            : minRem;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;
    final initialTime = (_reminderAt != null && _reminderAt!.isAfter(minRem))
        ? TimeOfDay.fromDateTime(_reminderAt!)
        : TimeOfDay.fromDateTime(minRem);
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (!mounted) return;
    var rem = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? minRem.hour,
      time?.minute ?? minRem.minute,
    );
    if (rem.isBefore(minRem)) rem = minRem;
    setState(() => _reminderAt = rem);
  }

  Future<void> _save() async {
    // Manually validate and show a visible error if title is empty
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _showError('Görev başlığı boş olamaz.');
      return;
    }

    setState(() => _loading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        _showError('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
        return;
      }
      final deviceId = await ref.read(deviceIdProvider.future);
      final repo = ref.read(taskRepositoryProvider);

      TaskEntity task;
      if (_isEdit && _original != null) {
        final userId = user.uid;
        final displayName = user.displayName.isEmpty ? 'Kullanıcı' : user.displayName;
        final orig = _original!;

        // Collect changes for history
        final changes = <Map<String, String>>[];
        final newNotes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
        if (orig.title != title) {
          changes.add({'field': 'title', 'from': orig.title, 'to': title});
        }
        if ((orig.notes ?? '') != (newNotes ?? '')) {
          changes.add({'field': 'notes', 'from': orig.notes ?? '', 'to': newNotes ?? ''});
        }
        if (orig.priority != _priority) {
          changes.add({'field': 'priority', 'from': '${orig.priority}', 'to': '$_priority'});
        }
        if (orig.recurrenceRule != _recurrence) {
          changes.add({'field': 'recurrenceRule', 'from': orig.recurrenceRule, 'to': _recurrence});
        }
        final origDue = orig.dueAt?.toIso8601String() ?? '';
        final newDue = _dueAt?.toIso8601String() ?? '';
        if (origDue != newDue) {
          changes.add({'field': 'dueAt', 'from': origDue, 'to': newDue});
        }
        final origRem = orig.reminderAt?.toIso8601String() ?? '';
        final newRem = _reminderAt?.toIso8601String() ?? '';
        if (origRem != newRem) {
          changes.add({'field': 'reminderAt', 'from': origRem, 'to': newRem});
        }

        task = orig.copyWith(
          title: title,
          notes: newNotes,
          dueAt: _dueAt,
          clearDueAt: _dueAt == null,
          reminderAt: _reminderAt,
          clearReminderAt: _reminderAt == null,
          recurrenceRule: _recurrence,
          priority: _priority,
          labels: _labels,
          projectId: _projectId,
          fileId: _fileId,
          clearFileId: _fileId == null,
          updatedAt: DateTime.now(),
          updatedByUserId: userId,
        );
        await repo.updateTask(task);

        // Record edit history
        if (changes.isNotEmpty) {
          unawaited(recordEdited(
            taskId: task.id,
            userId: userId,
            userDisplayName: displayName,
            changes: changes,
          ));
        }
        final existing = await loadSubtasks(task.id);
        final byTitle = {for (var s in existing) s.title: s};
        final now = DateTime.now();
        final entities = _subtasks.asMap().entries.map((e) {
          final prev = byTitle[e.value];
          return SubtaskEntity(
            id: prev?.id ?? '${task.id}_sub_${e.key}',
            taskId: task.id,
            title: e.value,
            isCompleted: prev?.isCompleted ?? false,
            sortOrder: e.key,
            createdAt: prev?.createdAt ?? now,
          );
        }).toList();
        await saveSubtasks(task.id, entities);
      } else {
        task = await repo.createTask(
          ownerId: user.uid,
          title: title,
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
          dueAt: _dueAt,
          reminderAt: _reminderAt,
          recurrenceRule: _recurrence,
          priority: _priority,
          labels: _labels,
          projectId: _projectId,
          fileId: _fileId,
          deviceId: deviceId,
        );
        // Record create history
        final displayName = user.displayName.isEmpty ? 'Kullanıcı' : user.displayName;
        unawaited(recordCreated(
          taskId: task.id,
          userId: user.uid,
          userDisplayName: displayName,
        ));
      }

      // Alt görevleri kaydet (sadece yeni görev için; düzenlemede yukarıda yapıldı)
      if (!_isEdit && _subtasks.isNotEmpty) {
        final now = DateTime.now();
        final entities = _subtasks.asMap().entries.map((e) => SubtaskEntity(
          id: '${task.id}_sub_${e.key}',
          taskId: task.id,
          title: e.value,
          isCompleted: false,
          sortOrder: e.key,
          createdAt: now,
        )).toList();
        await saveSubtasks(task.id, entities);
      }

      // Provider'ları yenile ve anlık kaydet
      ref.invalidate(subtasksProvider(task.id));
      if (widget.groupId != null) {
        ref.invalidate(groupTasksProvider(widget.groupId!));
      }
      AutoSyncService.instance.flush();

      // Schedule notification (web stub — no-op)
      if (_reminderAt != null && _reminderAt!.isAfter(DateTime.now())) {
        try {
          await NotificationService.instance.scheduleTaskReminder(
            taskId: task.id,
            title: task.title,
            body: task.notes ?? 'Görevinizin zamanı geldi!',
            scheduledAt: _reminderAt!,
          );
        } catch (_) {}
      }

      if (mounted) {
        HapticFeedback.lightImpact();
        context.pop();
      }
    } catch (e) {
      if (mounted) _showError('Görev kaydedilemedi: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

// ─── Form UI helpers ──────────────────────────────────────────────────────

class _FolderSection extends ConsumerWidget {
  const _FolderSection({
    required this.fileId,
    required this.onFileChanged,
  });

  final String? fileId;
  final ValueChanged<String?> onFileChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(taskFilesProvider);
    final user = ref.watch(currentUserProvider);
    final cs = Theme.of(context).colorScheme;
    final l = ref.watch(appL10nProvider);

    return _FormSection(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.folder_special_outlined,
                    size: 20,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l.tabFolders,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: user != null
                        ? () => showCreateFolderDialog(context, ref,
                            onFolderCreated: onFileChanged)
                        : null,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l.addFolder),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              filesAsync.when(
                loading: () => const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, __) => Text(
                  l.foldersLoadError,
                  style: TextStyle(color: cs.error),
                ),
                data: (files) {
                  final items = <String, String>{
                    '': 'Seç',
                    ...{for (final f in files) f.id: f.name},
                  };
                  final currentValue = fileId ?? '';
                  return DropdownButtonFormField<String>(
                    value: items.containsKey(currentValue)
                        ? currentValue
                        : '',
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: items.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        onFileChanged(v == null || v.isEmpty ? null : v),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.90),
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
      child: Column(children: children),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.icon,
    required this.label,
    this.value,
    required this.placeholder,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.7)),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value ?? placeholder,
            style: TextStyle(
              color: value != null
                  ? cs.primary
                  : cs.onSurface.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
          if (onClear != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onClear,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  const _DropdownTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.7)),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        items: items.entries
            .map(
              (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
