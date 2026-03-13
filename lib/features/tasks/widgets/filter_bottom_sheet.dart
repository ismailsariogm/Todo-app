import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/filter_entity.dart';
import '../providers/filter_provider.dart';
import '../../../domain/entities/task_file_entity.dart';
import '../providers/tasks_provider.dart';
import '../../../data/repositories/project_repository.dart';
import '../../auth/auth_provider.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late TaskFilter _local;
  final _saveNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _local = ref.read(taskFilterProvider);
  }

  @override
  void dispose() {
    _saveNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final projects = ref.watch(projectsProvider).valueOrNull ?? [];
    final filesAsync = ref.watch(taskFilesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // ── Handle ──────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Filtreler',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() => _local = const TaskFilter());
                  },
                  child: const Text('Sıfırla'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                // ── Date filter ──────────────────────────────────
                _SectionLabel('Tarih'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DateFilter.values
                      .where((d) => d != DateFilter.none)
                      .map(
                        (df) => ChoiceChip(
                          label: Text(_dateLabel(df)),
                          selected: _local.dateFilter == df,
                          onSelected: (_) => setState(
                            () => _local = _local.copyWith(
                              dateFilter: _local.dateFilter == df
                                  ? DateFilter.none
                                  : df,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),

                // ── Priority ─────────────────────────────────────
                _SectionLabel('Öncelik'),
                Wrap(
                  spacing: 8,
                  children: List.generate(4, (i) {
                    final p = i + 1;
                    final color = PriorityColor.of(p);
                    return ChoiceChip(
                      label: Text(PriorityColor.label(p)),
                      selected: _local.priority == p,
                      selectedColor: color.withOpacity(0.2),
                      onSelected: (_) => setState(
                        () => _local = _local.copyWith(
                          priority: _local.priority == p ? null : p,
                          clearPriority: _local.priority == p,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // ── Status ───────────────────────────────────────
                _SectionLabel('Durum'),
                Wrap(
                  spacing: 8,
                  children: StatusFilter.values
                      .map(
                        (s) => ChoiceChip(
                          label: Text(_statusLabel(s)),
                          selected: _local.statusFilter == s,
                          onSelected: (_) => setState(
                            () => _local =
                                _local.copyWith(statusFilter: s),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),

                // ── Project ──────────────────────────────────────
                if (projects.isNotEmpty) ...[
                  _SectionLabel('Proje / Liste'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Tümü'),
                        selected: _local.projectId == null,
                        onSelected: (_) => setState(
                          () => _local =
                              _local.copyWith(clearProject: true),
                        ),
                      ),
                      ...projects.map(
                        (p) => ChoiceChip(
                          label: Text(p.name),
                          selected: _local.projectId == p.id,
                          onSelected: (_) => setState(
                            () => _local = _local.copyWith(
                              projectId: _local.projectId == p.id
                                  ? null
                                  : p.id,
                              clearProject: _local.projectId == p.id,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Klasör (kişisel görev kategorileri) ───────────
                filesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (files) {
                    if (files.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('Klasör'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Tümü'),
                              selected: _local.fileId == null,
                              onSelected: (_) => setState(
                                () => _local =
                                    _local.copyWith(clearFileId: true),
                              ),
                            ),
                            ...files.map(
                              (f) => ChoiceChip(
                                label: Text(f.name),
                                selected: _local.fileId == f.id,
                                onSelected: (_) => setState(
                                  () => _local = _local.copyWith(
                                    fileId: _local.fileId == f.id ? null : f.id,
                                    clearFileId: _local.fileId == f.id,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),

                // ── Save filter ──────────────────────────────────
                _SectionLabel('Filtreri Kaydet'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _saveNameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Filtre adı...',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      onPressed: () => _saveFilter(),
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          // ── Apply button ─────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _apply,
                  child: const Text('Uygula'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _apply() {
    ref.read(taskFilterProvider.notifier).applyFilter(_local);
    Navigator.of(context).pop();
  }

  Future<void> _saveFilter() async {
    final name = _saveNameCtrl.text.trim();
    if (name.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final repo = ref.read(projectRepositoryProvider);
    await repo.upsertSavedFilter(
      userId: user.uid,
      name: name,
      filterJson: _local.toJsonString(),
    );
    _saveNameCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" filtresi kaydedildi')),
      );
    }
  }

  String _dateLabel(DateFilter df) => switch (df) {
    DateFilter.today => 'Bugün',
    DateFilter.tomorrow => 'Yarın',
    DateFilter.overdue => 'Geciken',
    DateFilter.next7days => 'Bu Hafta',
    DateFilter.none => '',
  };

  String _statusLabel(StatusFilter s) => switch (s) {
    StatusFilter.active => 'Devam Eden',
    StatusFilter.completed => 'Tamamlanan',
    StatusFilter.deleted => 'Silinen',
    StatusFilter.all => 'Tümü',
  };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
