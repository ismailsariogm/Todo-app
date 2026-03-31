import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/task_history_service.dart';
import '../../../services/task_view_storage.dart';

// ─── Entry point ─────────────────────────────────────────────────────────────

void showTaskInfoSheet(BuildContext context, String taskId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TaskInfoSheet(taskId: taskId),
  );
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _TaskInfoSheet extends StatefulWidget {
  const _TaskInfoSheet({required this.taskId});
  final String taskId;

  @override
  State<_TaskInfoSheet> createState() => _TaskInfoSheetState();
}

class _TaskInfoSheetState extends State<_TaskInfoSheet> {
  List<TaskHistoryRecord> _history = [];
  List<TaskViewRecord> _views = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await loadTaskHistory(widget.taskId);
    final v = await loadTaskViews(widget.taskId);
    if (mounted) {
      setState(() {
        _history = h;
        _views = v;
        _loading = false;
      });
    }
  }

  List<TaskHistoryRecord> _ofType(String type) =>
      _history.where((r) => r.eventType == type).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark
        ? const Color(0xFF1E1B2E)
        : cs.surface;

    return Container(
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.info_outline_rounded,
                      color: cs.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Görev Bilgisi',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Flexible(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shrinkWrap: true,
                children: [
                  _Section(
                    icon: Icons.add_circle_outline_rounded,
                    iconColor: const Color(0xFF6366F1),
                    title: 'Oluşturan',
                    records: _ofType(TaskEvent.created),
                    onProfileTap: (r) => _openProfile(context, r.userId,
                        r.userDisplayName),
                  ),
                  _Section(
                    icon: Icons.double_arrow_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Çift Tık ile İletilen',
                    records: _ofType(TaskEvent.forwardedDouble),
                    forwardTarget: true,
                    onProfileTap: (r) => _openProfile(context, r.userId,
                        r.userDisplayName),
                    onTargetTap: (r) {
                      final tid = r.details?['targetUserId'] as String? ?? '';
                      final tn =
                          r.details?['targetUserName'] as String? ?? tid;
                      _openProfile(context, tid, tn);
                    },
                  ),
                  _Section(
                    icon: Icons.arrow_forward_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    title: 'Tek Tık ile İletilen',
                    records: _ofType(TaskEvent.forwardedSingle),
                    forwardTarget: true,
                    onProfileTap: (r) => _openProfile(context, r.userId,
                        r.userDisplayName),
                    onTargetTap: (r) {
                      final tid = r.details?['targetUserId'] as String? ?? '';
                      final tn =
                          r.details?['targetUserName'] as String? ?? tid;
                      _openProfile(context, tid, tn);
                    },
                  ),
                  _ViewSection(
                    views: _views,
                    onProfileTap: (v) =>
                        _openProfile(context, v.userId, v.userDisplayName),
                  ),
                  _Section(
                    icon: Icons.edit_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Düzenleyenler',
                    records: _ofType(TaskEvent.edited),
                    showChanges: true,
                    onProfileTap: (r) => _openProfile(context, r.userId,
                        r.userDisplayName),
                  ),
                  _Section(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Tamamlayanlar',
                    records: _ofType(TaskEvent.completed),
                    onProfileTap: (r) => _openProfile(context, r.userId,
                        r.userDisplayName),
                  ),
                  _Section(
                    icon: Icons.delete_outline_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Silenler',
                    records: _ofType(TaskEvent.deleted),
                    onProfileTap: (r) => _openProfile(context, r.userId,
                        r.userDisplayName),
                  ),
                  _Section(
                    icon: Icons.restore_rounded,
                    iconColor: const Color(0xFF14B8A6),
                    title: 'Geri Alanlar',
                    records: _ofType(TaskEvent.restored),
                    onProfileTap: (r) => _openProfile(context, r.userId,
                        r.userDisplayName),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _openProfile(BuildContext context, String userId, String displayName) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _UserProfileSheet(userId: userId, displayName: displayName),
    );
  }
}

// ─── Section widget ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.records,
    required this.onProfileTap,
    this.forwardTarget = false,
    this.onTargetTap,
    this.showChanges = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<TaskHistoryRecord> records;
  final void Function(TaskHistoryRecord) onProfileTap;
  final bool forwardTarget;
  final void Function(TaskHistoryRecord)? onTargetTap;
  final bool showChanges;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  if (records.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${records.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: iconColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  'Henüz kayıt yok',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ...records.map((r) => _RecordTile(
                    record: r,
                    forwardTarget: forwardTarget,
                    showChanges: showChanges,
                    onProfileTap: () => onProfileTap(r),
                    onTargetTap:
                        forwardTarget ? () => onTargetTap?.call(r) : null,
                  )),
          ],
        ),
      ),
    );
  }
}

// ─── View Section ─────────────────────────────────────────────────────────────

class _ViewSection extends StatelessWidget {
  const _ViewSection({
    required this.views,
    required this.onProfileTap,
  });

  final List<TaskViewRecord> views;
  final void Function(TaskViewRecord) onProfileTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const iconColor = Color(0xFF0EA5E9);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined,
                      size: 16, color: iconColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Görevi Görenler',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  if (views.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${views.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: iconColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (views.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  'Henüz kayıt yok',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ...views.map(
                (v) => _ViewTile(
                  view: v,
                  onProfileTap: () => onProfileTap(v),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Record tile ─────────────────────────────────────────────────────────────

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    required this.forwardTarget,
    required this.showChanges,
    required this.onProfileTap,
    this.onTargetTap,
  });

  final TaskHistoryRecord record;
  final bool forwardTarget;
  final bool showChanges;
  final VoidCallback onProfileTap;
  final VoidCallback? onTargetTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('d MMM yyyy, HH:mm', 'tr_TR')
        .format(record.timestamp.toLocal());
    final targetName =
        record.details?['targetUserName'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actor avatar
          _AvatarButton(
            name: record.userDisplayName,
            onTap: onProfileTap,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.userDisplayName.isEmpty ? 'Kullanıcı' : record.userDisplayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                // Forward target
                if (forwardTarget && targetName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onTargetTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: cs.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        _MiniAvatar(name: targetName),
                        const SizedBox(width: 6),
                        Text(
                          targetName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.primary,
                            decoration: TextDecoration.underline,
                            decorationColor:
                                cs.primary.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Edit changes
                if (showChanges) ..._buildChanges(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChanges(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rawChanges = record.details?['changes'];
    if (rawChanges == null) return [];
    final changes = (rawChanges as List).cast<Map<String, dynamic>>();
    if (changes.isEmpty) return [];
    return [
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: changes.map((c) {
            final field = _fieldLabel(c['field'] as String? ?? '');
            final from = c['from'] as String? ?? '';
            final to = c['to'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '$field: ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  if (from.isNotEmpty)
                    TextSpan(
                      text: '"$from" → ',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.error.withValues(alpha: 0.8),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  TextSpan(
                    text: '"$to"',
                    style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    ];
  }

  String _fieldLabel(String field) => switch (field) {
        'title' => 'Başlık',
        'notes' => 'Notlar',
        'dueAt' => 'Son Tarih',
        'reminderAt' => 'Hatırlatıcı',
        'priority' => 'Öncelik',
        'labels' => 'Etiketler',
        'recurrenceRule' => 'Tekrar',
        _ => field,
      };
}

// ─── View tile ────────────────────────────────────────────────────────────────

class _ViewTile extends StatelessWidget {
  const _ViewTile({required this.view, required this.onProfileTap});

  final TaskViewRecord view;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('d MMM yyyy, HH:mm', 'tr_TR')
        .format(view.viewedAt.toLocal());

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Row(
        children: [
          _AvatarButton(name: view.userDisplayName, onTap: onProfileTap),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  view.userDisplayName.isEmpty ? 'Kullanıcı' : view.userDisplayName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (view.userRole.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          view.userRole,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar button ────────────────────────────────────────────────────────────

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial =
        name.isNotEmpty ? name.runes.first.toString() == name[0] ? name[0].toUpperCase() : '?' : '?';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          shape: BoxShape.circle,
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 10,
      backgroundColor: cs.secondaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: cs.onSecondaryContainer,
        ),
      ),
    );
  }
}

// ─── User Profile Sheet ───────────────────────────────────────────────────────

class _UserProfileSheet extends StatelessWidget {
  const _UserProfileSheet({required this.userId, required this.displayName});

  final String userId;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.4),
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName.isEmpty ? 'Kullanıcı' : displayName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'ID: $userId',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Placeholder for future profile info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Text(
              'Profil bilgileri yakında eklenecek.',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Kapat'),
            ),
          ),
        ],
      ),
    );
  }
}
