import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/task_entity.dart';
import '../../domain/entities/task_file_entity.dart';
import 'providers/tasks_provider.dart';
import 'widgets/home_background.dart';

enum _ChartMetric { created, completed }

enum _ChartPeriod { day, week, month, year }

enum _SeriesKind { folder, lateCompleted, deleted, onTimeCompleted }

// ─── Sabit renk paleti — aynı isim her zaman aynı renk ─────────────────────
const _kColorPalette = <Color>[
  Color(0xFF6366F1), Color(0xFF3B82F6), Color(0xFF10B981),
  Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFFF97316),
  Color(0xFF14B8A6), Color(0xFFEC4899), Color(0xFF06B6D4),
  Color(0xFF84CC16), Color(0xFFEAB308), Color(0xFF0EA5E9),
];

Color _colorForFolderName(String name) {
  if (name.isEmpty) return const Color(0xFFB0BEC5);
  var hash = 0;
  for (final c in name.codeUnits) {
    hash = (hash * 31 + c) & 0x7FFFFFFF;
  }
  return _kColorPalette[hash % _kColorPalette.length];
}

/// Tek grafik serisi (klasör veya özel kategori).
class _ChartSeries {
  const _ChartSeries({
    required this.key,
    required this.name,
    required this.color,
    required this.kind,
    this.folderId,
  });

  final String key;
  final String name;
  final Color color;
  final _SeriesKind kind;
  final String? folderId;
}

/// Kişisel görevler — pasta + yükselen çizgi.
class FolderChartsScreen extends ConsumerStatefulWidget {
  const FolderChartsScreen({super.key});

  @override
  ConsumerState<FolderChartsScreen> createState() => _FolderChartsScreenState();
}

class _FolderChartsScreenState extends ConsumerState<FolderChartsScreen>
    with SingleTickerProviderStateMixin {
  _ChartMetric _metric = _ChartMetric.created;
  _ChartPeriod _period = _ChartPeriod.week;
  bool _includeUncategorized = true;

  /// Klasör id → açık mı (varsayılan: açık).
  final Map<String, bool> _folderEnabled = {};

  bool _showLateCompleted = false;
  bool _showDeleted = false;
  bool _showOnTimeCompleted = false;
  final TransformationController _chartTransformCtrl = TransformationController();

  late final TabController _tabCtrl;

  static const _animDuration = Duration(milliseconds: 750);
  static const _animCurve = Curves.easeOutCubic;

  static const _kLateColor = Color(0xFFFF9800);
  static const _kDeletedColor = Color(0xFFEF4444);
  static const _kOnTimeColor = Color(0xFF43A047);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _chartTransformCtrl.dispose();
    super.dispose();
  }

  void _syncFolderKeys(List<TaskFileEntity> files) {
    final ids = files.map((f) => f.id).toSet();
    _folderEnabled.removeWhere((k, _) => k.isNotEmpty && !ids.contains(k));
    for (final f in files) {
      _folderEnabled.putIfAbsent(f.id, () => true);
    }
    _folderEnabled.putIfAbsent('', () => true);
  }

  List<_ChartSeries> _buildActiveSeries(List<TaskFileEntity> files) {
    _syncFolderKeys(files);
    final palette = _folderPalette(files);
    final out = <_ChartSeries>[];

    for (final f in files) {
      if (_folderEnabled[f.id] == false) continue;
      final col = palette[f.id] ?? const Color(0xFF6366F1);
      out.add(
        _ChartSeries(
          key: 'f_${f.id}',
          name: f.name,
          color: col,
          kind: _SeriesKind.folder,
          folderId: f.id,
        ),
      );
    }
    if (_includeUncategorized && (_folderEnabled[''] != false)) {
      out.add(
        const _ChartSeries(
          key: 'f_uncat',
          name: 'Klasörsüz',
          color: Color(0xFFB0BEC5),
          kind: _SeriesKind.folder,
          folderId: '',
        ),
      );
    }
    if (_showLateCompleted) {
      out.add(
        const _ChartSeries(
          key: 'late',
          name: 'Zamanında bitirilemeyen',
          color: _kLateColor,
          kind: _SeriesKind.lateCompleted,
        ),
      );
    }
    if (_showDeleted) {
      out.add(
        const _ChartSeries(
          key: 'deleted',
          name: 'Silinen Görevler',
          color: _kDeletedColor,
          kind: _SeriesKind.deleted,
        ),
      );
    }
    if (_showOnTimeCompleted) {
      out.add(
        const _ChartSeries(
          key: 'ontime',
          name: 'Zamanında tamamlanan',
          color: _kOnTimeColor,
          kind: _SeriesKind.onTimeCompleted,
        ),
      );
    }
    return out;
  }

  Map<String, Color> _folderPalette(List<TaskFileEntity> files) {
    final m = <String, Color>{};
    for (final f in files) {
      // Aynı isim her zaman aynı renk alır
      m[f.id] = _colorForFolderName(f.name);
    }
    return m;
  }

  Widget _analysisSelectionPanel(List<TaskFileEntity> files) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.white24,
          unselectedWidgetColor: Colors.white54,
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: Colors.white,
          collapsedIconColor: Colors.white70,
          title: Text(
            'Analiz seçimleri',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            'Aç/kapa — yalnızca seçtikleriniz grafikte yer alır.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Klasörler',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final f in files)
                    SwitchListTile.adaptive(
                      dense: true,
                      value: _folderEnabled[f.id] != false,
                      onChanged: (v) =>
                          setState(() => _folderEnabled[f.id] = v),
                      title: Text(
                        f.name,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  if (_includeUncategorized)
                    SwitchListTile.adaptive(
                      dense: true,
                      value: _folderEnabled[''] != false,
                      onChanged: (v) => setState(() => _folderEnabled[''] = v),
                      title: const Text(
                        'Klasörsüz',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  const Divider(color: Colors.white24),
                  Text(
                    'Durum analizleri',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SwitchListTile.adaptive(
                    dense: true,
                    value: _showLateCompleted,
                    onChanged: (v) =>
                        setState(() => _showLateCompleted = v),
                    activeThumbColor: _kLateColor,
                    title: const Text(
                      'Zamanında bitirilemeyen',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    subtitle: Text(
                      'Son tarihten sonra tamamlananlar',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    dense: true,
                    value: _showDeleted,
                    onChanged: (v) => setState(() => _showDeleted = v),
                    activeThumbColor: _kDeletedColor,
                    title: const Text(
                      'Silinen Görevler',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    subtitle: Text(
                      'Çöp kutusundaki silinen görevler',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    dense: true,
                    value: _showOnTimeCompleted,
                    onChanged: (v) =>
                        setState(() => _showOnTimeCompleted = v),
                    activeThumbColor: _kOnTimeColor,
                    title: const Text(
                      'Zamanında tamamlanan',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    subtitle: Text(
                      'Son tarih veya öncesinde tamamlananlar',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (_metric == _ChartMetric.created)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Not: «Oluşturulan» seçiliyken durum satırları genelde 0 olur; '
                        'bu satırlar için «Tamamlanan» kullanın.',
                        style: TextStyle(
                          color: Colors.amber.withValues(alpha: 0.85),
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(personalTasksAnalyticsProvider);
    final filesAsync = ref.watch(taskFilesProvider);

    return Stack(
      children: [
        const HomeBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              'Görev Analizi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.pie_chart_outline, size: 20),
                  text: 'Pasta',
                ),
                Tab(
                  icon: Icon(Icons.area_chart_rounded, size: 20),
                  text: 'Yükselen analiz',
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: tasksAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (e, _) => Center(
                child: Text('Hata: $e',
                    style: const TextStyle(color: Colors.white)),
              ),
              data: (tasks) => filesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                error: (e, _) => Center(
                  child: Text('Klasörler: $e',
                      style: const TextStyle(color: Colors.white)),
                ),
                data: (files) => TabBarView(
                  controller: _tabCtrl,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildPiePage(context, tasks, files),
                    _buildLinePage(context, tasks, files),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sharedControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_ChartMetric>(
          segments: const [
            ButtonSegment(
              value: _ChartMetric.created,
              label: Text('Oluşturulan'),
              icon: Icon(Icons.add_task_outlined, size: 18),
            ),
            ButtonSegment(
              value: _ChartMetric.completed,
              label: Text('Tamamlanan'),
              icon: Icon(Icons.check_circle_outline, size: 18),
            ),
          ],
          selected: {_metric},
          onSelectionChanged: (s) => setState(() => _metric = s.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white.withValues(alpha: 0.25);
              }
              return Colors.white.withValues(alpha: 0.08);
            }),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<_ChartPeriod>(
          segments: const [
            ButtonSegment(value: _ChartPeriod.day, label: Text('Günlük')),
            ButtonSegment(value: _ChartPeriod.week, label: Text('Haftalık')),
            ButtonSegment(value: _ChartPeriod.month, label: Text('Aylık')),
            ButtonSegment(value: _ChartPeriod.year, label: Text('Yıllık')),
          ],
          selected: {_period},
          onSelectionChanged: (s) => setState(() => _period = s.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white.withValues(alpha: 0.25);
              }
              return Colors.white.withValues(alpha: 0.08);
            }),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          child: SwitchListTile.adaptive(
            value: _includeUncategorized,
            onChanged: (v) => setState(() => _includeUncategorized = v),
            title: Text(
              'Klasörsüzü dahil et',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              _includeUncategorized
                  ? 'Listede «Klasörsüz» satırı gösterilir.'
                  : 'Klasörsüz satırı ve görevleri gizlenir.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
              ),
            ),
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white38,
          ),
        ),
      ],
    );
  }

  Widget _buildPiePage(
    BuildContext context,
    List<TaskEntity> tasks,
    List<TaskFileEntity> files,
  ) {
    final series = _buildActiveSeries(files);
    if (series.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _sharedControls(),
          const SizedBox(height: 12),
          _analysisSelectionPanel(files),
          const SizedBox(height: 24),
          Text(
            'Grafik için en az bir seçenek açın (klasör veya durum).',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
          ),
        ],
      );
    }

    final buckets = _bucketStarts(_period);
    final matrix = _countMatrixForSeries(
      tasks: tasks,
      series: series,
      buckets: buckets,
      period: _period,
      metric: _metric,
    );
    final totals = _sliceTotals(matrix, series.length, buckets.length);
    final sum = totals.fold<double>(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'Seçilen dönemde dağılım (pasta)',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _sharedControls(),
        const SizedBox(height: 10),
        _analysisSelectionPanel(files),
        const SizedBox(height: 20),
        if (sum <= 0)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Bu dönem ve seçimler için veri yok.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          )
        else
          LayoutBuilder(
            builder: (ctx, c) {
              final size = math.min(280.0, c.maxWidth * 0.85);
              return Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: _animDuration,
                  curve: _animCurve,
                  builder: (context, t, child) {
                    return Opacity(
                      opacity: t,
                      child: Transform.scale(
                        scale: 0.85 + 0.15 * t,
                        child: child,
                      ),
                    );
                  },
                  child: SizedBox(
                    height: size,
                    width: size,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: size * 0.22,
                        centerSpaceColor: Colors.black.withValues(alpha: 0.15),
                        sections: [
                          for (var i = 0; i < series.length; i++)
                            if (totals[i] > 0)
                              PieChartSectionData(
                                value: totals[i],
                                color: series[i].color,
                                radius: size * 0.36,
                                title:
                                    '${totals[i].toInt()}\n${series[i].name}',
                                titleStyle: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 4,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                                titlePositionPercentageOffset: 0.62,
                              ),
                        ],
                        pieTouchData: PieTouchData(),
                      ),
                      duration: _animDuration,
                      curve: _animCurve,
                    ),
                  ),
                ),
              );
            },
          ),
        if (sum > 0) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Toplam: ${sum.toInt()} (seçimlere göre)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _LegendSeries(series: series, totals: totals),
      ],
    );
  }

  Widget _buildLinePage(
    BuildContext context,
    List<TaskEntity> tasks,
    List<TaskFileEntity> files,
  ) {
    final series = _buildActiveSeries(files);
    if (series.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _sharedControls(),
          const SizedBox(height: 12),
          _analysisSelectionPanel(files),
          const SizedBox(height: 24),
          Text(
            'Grafik için en az bir seçenek açın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
          ),
        ],
      );
    }

    final buckets = _bucketStarts(_period);
    final labels = _bucketLabels(buckets, _period);
    final matrix = _countMatrixForSeries(
      tasks: tasks,
      series: series,
      buckets: buckets,
      period: _period,
      metric: _metric,
    );
    final maxY = _maxLineY(matrix, series.length, buckets.length);
    final cap = maxY <= 0 ? 4.0 : (maxY * 1.2).clamp(4.0, double.infinity);
    final totals = _sliceTotals(matrix, series.length, buckets.length);

    // Peak indeksleri — her seri için en yüksek bucket
    final peakIndices = List.generate(series.length, (s) {
      var best = 0;
      for (var i = 1; i < buckets.length; i++) {
        if (matrix[s][i] > matrix[s][best]) best = i;
      }
      return best;
    });

    final lineBars = <LineChartBarData>[];
    for (var s = 0; s < series.length; s++) {
      final spots = List<FlSpot>.generate(
        buckets.length,
        (i) => FlSpot(i.toDouble(), matrix[s][i]),
      );
      final c = series[s].color;
      final peakIdx = peakIndices[s];
      final serIndex = s; // capture for closure
      lineBars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.22,
          color: c,
          barWidth: 3.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (sp, p, bar, i) {
              // Peak noktasına "i" ikonu çiz
              if (i == peakIdx && matrix[serIndex][i] > 0) {
                return _IPeakDotPainter(color: c);
              }
              return FlDotCirclePainter(
                radius: 4.5,
                color: c,
                strokeWidth: 2.0,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c.withValues(alpha: 0.45),
                c.withValues(alpha: 0.02),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Zaman içinde trend',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Görünümü sıfırla
            IconButton(
              icon: const Icon(
                Icons.zoom_out_map_rounded,
                color: Colors.white70,
                size: 20,
              ),
              tooltip: 'Görünümü sıfırla',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: () => _chartTransformCtrl.value = Matrix4.identity(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _sharedControls(),
        const SizedBox(height: 10),
        _analysisSelectionPanel(files),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            return ClipRect(
              child: InteractiveViewer(
                transformationController: _chartTransformCtrl,
                minScale: 0.8,
                maxScale: 10.0,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                trackpadScrollCausesScale: true,
                child: SizedBox(
                  width: c.maxWidth,
                  height: 440,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(
                      '${series.map((e) => e.key).join('|')}_$_period$_metric',
                    ),
                    tween: Tween(begin: 0, end: 1),
                    duration: _animDuration,
                    curve: _animCurve,
                    builder: (context, t, _) {
                      return Opacity(
                        opacity: t,
                        child: LineChart(
                          LineChartData(
                            minX: 0,
                            maxX: (buckets.length - 1).toDouble(),
                            minY: 0,
                            maxY: cap,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: cap > 0 ? cap / 4 : 1,
                              getDrawingHorizontalLine: (v) => FlLine(
                                color: Colors.white.withValues(alpha: 0.12),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 34,
                                  getTitlesWidget: (v, m) => Text(
                                    v.toInt().toString(),
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.75),
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 30,
                                  getTitlesWidget: (v, m) {
                                    final i = v.toInt();
                                    if (i < 0 || i >= labels.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(top: 6),
                                      child: Text(
                                        labels[i],
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                          fontSize: 8.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            lineTouchData: LineTouchData(
                              handleBuiltInTouches: true,
                              touchCallback: (event, response) {
                                // "i" ikonuna tıklanınca peak detay sayfası aç
                                if (event is! FlTapUpEvent) return;
                                final spots = response?.lineBarSpots;
                                if (spots == null || spots.isEmpty) return;
                                for (final sp in spots) {
                                  if (sp.barIndex < series.length &&
                                      sp.spotIndex ==
                                          peakIndices[sp.barIndex] &&
                                      matrix[sp.barIndex]
                                              [sp.spotIndex] >
                                          0) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (!mounted) return;
                                      _showPeakDetail(
                                        context: context,
                                        series: series[sp.barIndex],
                                        bucketIndex: sp.spotIndex,
                                        buckets: buckets,
                                        period: _period,
                                        metric: _metric,
                                        tasks: tasks,
                                      );
                                    });
                                    break;
                                  }
                                }
                              },
                              touchTooltipData: LineTouchTooltipData(
                                maxContentWidth: 240,
                                getTooltipColor: (_) =>
                                    Colors.black.withValues(alpha: 0.9),
                                tooltipPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                getTooltipItems: (spots) {
                                  if (spots.isEmpty) return [];
                                  // Sadece en yüksek değerli seriyi göster
                                  var maxIdx = 0;
                                  for (var i = 1; i < spots.length; i++) {
                                    if (spots[i].y > spots[maxIdx].y) {
                                      maxIdx = i;
                                    }
                                  }
                                  final bx = spots[maxIdx].x.toInt();
                                  final range =
                                      (bx >= 0 && bx < buckets.length)
                                          ? _formatBucketRangeWithHours(
                                              buckets[bx], _period)
                                          : '';
                                  return spots
                                      .asMap()
                                      .entries
                                      .map((e) {
                                    if (e.key != maxIdx) return null;
                                    final sp = e.value;
                                    final n = series[sp.barIndex].name;
                                    return LineTooltipItem(
                                      '${range.isNotEmpty ? "$range\n" : ""}$n: ${sp.y.toInt()}',
                                      TextStyle(
                                        color: series[sp.barIndex].color,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            lineBarsData: lineBars,
                          ),
                          duration: _animDuration,
                          curve: _animCurve,
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // ── Rapor / Gösterge ──────────────────────────────────────────────
        _ReportCard(series: series, totals: totals),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'İpucu: Fare tekerleği veya dokunmatik ekranda çift parmak ile yaklaştır · Sürükle ile kaydır · ⓘ ikonuna tıkla detay gör',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  void _showPeakDetail({
    required BuildContext context,
    required _ChartSeries series,
    required int bucketIndex,
    required List<DateTime> buckets,
    required _ChartPeriod period,
    required _ChartMetric metric,
    required List<TaskEntity> tasks,
  }) {
    final start = buckets[bucketIndex];
    final end = _bucketEnd(start, period);
    final label = _formatBucketRangeWithHours(start, period);

    // Bu seri + bucket için görevleri filtrele
    final matchingTasks = tasks.where((t) {
      if (series.kind == _SeriesKind.deleted) {
        if (!t.isDeleted || t.deletedAt == null) return false;
        final ev = t.deletedAt!.toLocal();
        return _inBucket(ev, start, period);
      }
      if (t.isDeleted) return false;
      if (series.kind == _SeriesKind.folder) {
        final fid = t.fileId ?? '';
        if (fid != (series.folderId ?? '')) return false;
        final ev = metric == _ChartMetric.created
            ? t.createdAt.toLocal()
            : (t.completedAt?.toLocal());
        if (ev == null) return false;
        return _inBucket(ev, start, period);
      }
      if (series.kind == _SeriesKind.lateCompleted) {
        if (!t.isCompletedLate || t.completedAt == null) return false;
        return _inBucket(t.completedAt!.toLocal(), start, period);
      }
      if (series.kind == _SeriesKind.onTimeCompleted) {
        if (!_onTimeCompleted(t)) return false;
        return _inBucket(t.completedAt!.toLocal(), start, period);
      }
      return false;
    }).toList()
      ..sort((a, b) {
        final ta = _taskSortDate(a, series, metric);
        final tb = _taskSortDate(b, series, metric);
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return ta.compareTo(tb);
      });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PeakDetailSheet(
        series: series,
        label: label,
        tasks: matchingTasks,
        metric: metric,
      ),
    );
  }

  DateTime? _taskSortDate(
      TaskEntity t, _ChartSeries series, _ChartMetric metric) {
    if (series.kind == _SeriesKind.deleted) return t.deletedAt;
    if (series.kind == _SeriesKind.lateCompleted ||
        series.kind == _SeriesKind.onTimeCompleted) return t.completedAt;
    if (metric == _ChartMetric.created) return t.createdAt;
    return t.completedAt;
  }
}

bool _onTimeCompleted(TaskEntity t) {
  if (!t.isCompleted || t.completedAt == null) return false;
  // Son tarih belirtilmemişse, tamamlanan görev zamanında sayılır.
  if (t.dueAt == null) return true;
  return !t.completedAt!.isAfter(t.dueAt!);
}

List<List<double>> _countMatrixForSeries({
  required List<TaskEntity> tasks,
  required List<_ChartSeries> series,
  required List<DateTime> buckets,
  required _ChartPeriod period,
  required _ChartMetric metric,
}) {
  final n = buckets.length;
  final m = series.length;
  final matrix = List.generate(m, (_) => List<double>.filled(n, 0));

  for (var si = 0; si < m; si++) {
    final ser = series[si];
    // Deleted serisi için isDeleted=true, diğerleri için isDeleted=false
    final isDeletedSeries = ser.kind == _SeriesKind.deleted;
    for (final t in tasks) {
      if (t.isDeleted != isDeletedSeries) continue;

      switch (ser.kind) {
        case _SeriesKind.folder:
          final fid = t.fileId ?? '';
          if (fid != (ser.folderId ?? '')) continue;
          DateTime? ev;
          if (metric == _ChartMetric.created) {
            ev = t.createdAt.toLocal();
          } else {
            if (!t.isCompleted || t.completedAt == null) continue;
            ev = t.completedAt!.toLocal();
          }
          for (var i = 0; i < n; i++) {
            if (_inBucket(ev, buckets[i], period)) {
              matrix[si][i] += 1;
              break;
            }
          }
        case _SeriesKind.lateCompleted:
          if (metric == _ChartMetric.created) break;
          if (!t.isCompletedLate || t.completedAt == null) continue;
          if (!_taskInScope(t, series)) continue;
          final ev = t.completedAt!.toLocal();
          for (var i = 0; i < n; i++) {
            if (_inBucket(ev, buckets[i], period)) {
              matrix[si][i] += 1;
              break;
            }
          }
        case _SeriesKind.onTimeCompleted:
          if (metric == _ChartMetric.created) break;
          if (!_onTimeCompleted(t)) continue;
          if (!_taskInScope(t, series)) continue;
          final ev = t.completedAt!.toLocal();
          for (var i = 0; i < n; i++) {
            if (_inBucket(ev, buckets[i], period)) {
              matrix[si][i] += 1;
              break;
            }
          }
        case _SeriesKind.deleted:
          if (metric == _ChartMetric.created) break;
          if (t.deletedAt == null) continue;
          if (!_taskInScope(t, series)) continue;
          final ev = t.deletedAt!.toLocal();
          for (var i = 0; i < n; i++) {
            if (_inBucket(ev, buckets[i], period)) {
              matrix[si][i] += 1;
              break;
            }
          }
      }
    }
  }
  return matrix;
}

/// Kapsam filtresi — hangi klasorde oldugunu kontrol eder.
bool _taskInScope(TaskEntity t, List<_ChartSeries> allSeries) {
  final hasFolderSelection = allSeries.any((s) => s.kind == _SeriesKind.folder);
  if (!hasFolderSelection) return true;
  final fid = t.fileId ?? '';
  for (final s in allSeries) {
    if (s.kind != _SeriesKind.folder) continue;
    if (fid == (s.folderId ?? '')) return true;
  }
  return false;
}

Color _parseColor(String hex) {
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) {
    return Color(int.parse(h, radix: 16) + 0xFF000000);
  }
  return const Color(0xFF6366F1);
}

Color _distinctColor(Color base, int index, int total) {
  if (total <= 0) return base;
  final hsl = HSLColor.fromColor(base);
  final delta = (index * (360 / math.max(total, 1))) % 360;
  return hsl.withHue((hsl.hue + delta * 0.35) % 360).toColor();
}

List<DateTime> _bucketStarts(_ChartPeriod p) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (p) {
    case _ChartPeriod.day:
      return List.generate(
        7,
        (i) => today.subtract(Duration(days: 6 - i)),
      );
    case _ChartPeriod.week:
      final mon = _startOfWeek(today);
      return List.generate(
        8,
        (i) => mon.subtract(Duration(days: 7 * (7 - i))),
      );
    case _ChartPeriod.month:
      final first = DateTime(now.year, now.month, 1);
      return List.generate(12, (i) {
        var y = first.year;
        var m = first.month - 11 + i;
        while (m < 1) {
          m += 12;
          y--;
        }
        while (m > 12) {
          m -= 12;
          y++;
        }
        return DateTime(y, m, 1);
      });
    case _ChartPeriod.year:
      return List.generate(5, (i) => DateTime(now.year - 4 + i, 1, 1));
  }
}

DateTime _startOfWeek(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

DateTime _bucketEnd(DateTime start, _ChartPeriod p) {
  switch (p) {
    case _ChartPeriod.day:
      return DateTime(start.year, start.month, start.day + 1);
    case _ChartPeriod.week:
      return start.add(const Duration(days: 7));
    case _ChartPeriod.month:
      return DateTime(start.year, start.month + 1, 1);
    case _ChartPeriod.year:
      return DateTime(start.year + 1, 1, 1);
  }
}

String _formatBucketRangeWithHours(DateTime start, _ChartPeriod p) {
  final end = _bucketEnd(start, p);
  final loc = 'tr_TR';
  final df = DateFormat('d MMM yyyy, HH:mm', loc);
  return '${df.format(start)} → ${df.format(end)}';
}

bool _inBucket(DateTime t, DateTime start, _ChartPeriod p) {
  final end = _bucketEnd(start, p);
  return !t.isBefore(start) && t.isBefore(end);
}

List<String> _bucketLabels(List<DateTime> buckets, _ChartPeriod p) {
  final loc = 'tr_TR';
  switch (p) {
    case _ChartPeriod.day:
      return buckets
          .map((d) => DateFormat('EEE d/M', loc).format(d))
          .toList();
    case _ChartPeriod.week:
      return buckets
          .map((d) => DateFormat('d/M', loc).format(d))
          .toList();
    case _ChartPeriod.month:
      return buckets
          .map((d) => DateFormat('MMM yy', loc).format(d))
          .toList();
    case _ChartPeriod.year:
      return buckets.map((d) => '${d.year}').toList();
  }
}

List<double> _sliceTotals(
  List<List<double>> matrix,
  int sliceCount,
  int bucketCount,
) {
  return List.generate(sliceCount, (s) {
    var sum = 0.0;
    for (var i = 0; i < bucketCount; i++) {
      sum += matrix[s][i];
    }
    return sum;
  });
}

double _maxLineY(
  List<List<double>> matrix,
  int sliceCount,
  int bucketCount,
) {
  var max = 0.0;
  for (var i = 0; i < bucketCount; i++) {
    for (var s = 0; s < sliceCount; s++) {
      if (matrix[s][i] > max) max = matrix[s][i];
    }
  }
  return max;
}

class _LegendSeries extends StatelessWidget {
  const _LegendSeries({
    required this.series,
    required this.totals,
  });

  final List<_ChartSeries> series;
  final List<double> totals;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < series.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: series[i].color,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: series[i].color.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  '${series[i].name} (${totals[i].toInt()})',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ─── Zoom Control ─────────────────────────────────────────────────────────────

class _ZoomControl extends StatelessWidget {
  const _ZoomControl({
    required this.zoomLevel,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });
  final double zoomLevel;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 18, color: Colors.white),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: onZoomOut,
            tooltip: 'Uzaklaştır',
          ),
          GestureDetector(
            onTap: onReset,
            child: Text(
              '${(zoomLevel * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 18, color: Colors.white),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: onZoomIn,
            tooltip: 'Yaklaştır',
          ),
        ],
      ),
    );
  }
}

// ─── Report Card ──────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.series, required this.totals});
  final List<_ChartSeries> series;
  final List<double> totals;

  @override
  Widget build(BuildContext context) {
    final total = totals.fold<double>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Dönem Raporu',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Toplam: ${total.toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: [
              for (var i = 0; i < series.length; i++)
                _ReportChip(
                  color: series[i].color,
                  name: series[i].name,
                  count: totals[i].toInt(),
                  percent: total > 0
                      ? (totals[i] / total * 100).toStringAsFixed(1)
                      : '0.0',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportChip extends StatelessWidget {
  const _ReportChip({
    required this.color,
    required this.name,
    required this.count,
    required this.percent,
  });
  final Color color;
  final String name;
  final int count;
  final String percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count ($percent%)',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Peak "i" Dot Painter ─────────────────────────────────────────────────────

class _IPeakDotPainter extends FlDotPainter {
  const _IPeakDotPainter({required this.color});
  final Color color;

  @override
  void draw(Canvas canvas, FlSpot spot, Offset center) {
    // Arka plan daire
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(center, 10, fill);
    // Beyaz kenarlık
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 10, border);
    // "i" harfini elle çiz
    final dot = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(center + const Offset(0, -4), 1.5, dot);
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center + const Offset(0, -1),
      center + const Offset(0, 4.5),
      line,
    );
  }

  @override
  Size getSize(FlSpot spot) => const Size(20, 20);

  @override
  Color get mainColor => color;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) {
    if (a is _IPeakDotPainter && b is _IPeakDotPainter) {
      return _IPeakDotPainter(
        color: Color.lerp(a.color, b.color, t) ?? color,
      );
    }
    return b;
  }

  @override
  List<Object?> get props => [color];
}

// ─── Peak Detail Sheet ────────────────────────────────────────────────────────

class _PeakDetailSheet extends StatelessWidget {
  const _PeakDetailSheet({
    required this.series,
    required this.label,
    required this.tasks,
    required this.metric,
  });

  final _ChartSeries series;
  final String label;
  final List<TaskEntity> tasks;
  final _ChartMetric metric;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: series.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        series.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: series.color,
                                ),
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: series.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tasks.length} görev',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: series.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Bu dönemde görev bulunamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: tasks.length,
                itemBuilder: (ctx, idx) {
                  final t = tasks[idx];
                  return _PeakTaskTile(
                      task: t, series: series, metric: metric);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PeakTaskTile extends StatelessWidget {
  const _PeakTaskTile({
    required this.task,
    required this.series,
    required this.metric,
  });
  final TaskEntity task;
  final _ChartSeries series;
  final _ChartMetric metric;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat('d MMM yyyy, HH:mm', 'tr_TR');
    final createdStr = df.format(task.createdAt.toLocal());

    String? actionLabel;
    String? actionDate;
    if (series.kind == _SeriesKind.deleted && task.deletedAt != null) {
      actionLabel = 'Silindi';
      actionDate = df.format(task.deletedAt!.toLocal());
    } else if ((series.kind == _SeriesKind.lateCompleted ||
            series.kind == _SeriesKind.onTimeCompleted) &&
        task.completedAt != null) {
      actionLabel = 'Tamamlandı';
      actionDate = df.format(task.completedAt!.toLocal());
    } else if (metric == _ChartMetric.completed && task.completedAt != null) {
      actionLabel = 'Tamamlandı';
      actionDate = df.format(task.completedAt!.toLocal());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: series.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: series.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.add_circle_outline_rounded,
                  size: 12, color: cs.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text(
                'Oluşturuldu: $createdStr',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          if (actionLabel != null && actionDate != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  series.kind == _SeriesKind.deleted
                      ? Icons.delete_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 12,
                  color: series.color,
                ),
                const SizedBox(width: 4),
                Text(
                  '$actionLabel: $actionDate',
                  style: TextStyle(
                    fontSize: 11,
                    color: series.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
