import 'package:flutter/material.dart';

import 'package:todo_note/features/tasks/providers/tasks_provider.dart';

// SwiftUI / ana arka plan ile uyumlu mor — koyu pembe — eflatun paleti
const _borderStart = Color(0xFF7C3AED); // mor
const _borderMid = Color(0xFFC026D3); // fuşya
const _borderEnd = Color(0xFFDB2777); // koyu pembe

const _fillPink = Color(0xFFFFE8F4); // açık pembe
const _fillLavender = Color(0xFFF0E7FF); // açık eflatun
const _fillLilac = Color(0xFFE9D5FF);

const _textPrimary = Color(0xFF4C1D95); // mor metin
const _textSecondary = Color(0xFF6B21A8);

const _borderStartDark = Color(0xFFA78BFA);
const _borderEndDark = Color(0xFFF472B6);
const _fillDarkTop = Color(0xFF2D1B4E);
const _fillDarkBottom = Color(0xFF3D2563);

double progressRatio(TaskProgressPair p) =>
    p.total <= 0 ? 0.0 : p.done / p.total;

Widget _loadingPadding({required bool compact}) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
    child: const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          color: Color(0xFFE879F9),
          strokeWidth: 2,
        ),
      ),
    ),
  );
}

/// Yalnızca Bugün ilerlemesi (Bugün sekmesi / bugün tarih filtresi).
class TaskProgressTodaySection extends StatelessWidget {
  const TaskProgressTodaySection({
    super.key,
    required this.snapshot,
    this.compact = false,
  });

  final TaskProgressSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (snapshot.loading) {
      return _loadingPadding(compact: compact);
    }
    return _TaskProgressMetricCard(
      title: 'Bugün',
      subtitle: 'Son tarihi bugün olanlar ve bugün tamamlananlar',
      pair: snapshot.today,
      compact: compact,
      icon: Icons.today_rounded,
      variant: _CardVariant.today,
    );
  }
}

/// Kişisel tüm görev ilerlemesi — başlık: Görevlerim.
class TaskProgressOngoingSection extends StatelessWidget {
  const TaskProgressOngoingSection({
    super.key,
    required this.snapshot,
    this.compact = false,
  });

  final TaskProgressSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (snapshot.loading) {
      return _loadingPadding(compact: compact);
    }
    return _TaskProgressMetricCard(
      title: 'Görevlerim',
      subtitle: 'Tüm aktif ve tamamlanan görevler',
      pair: snapshot.ongoing,
      compact: compact,
      icon: Icons.task_alt_rounded,
      variant: _CardVariant.myTasks,
    );
  }
}

enum _CardVariant { today, myTasks }

class _TaskProgressMetricCard extends StatefulWidget {
  const _TaskProgressMetricCard({
    required this.title,
    required this.subtitle,
    required this.pair,
    required this.compact,
    required this.icon,
    required this.variant,
  });

  final String title;
  final String subtitle;
  final TaskProgressPair pair;
  final bool compact;
  final IconData icon;
  final _CardVariant variant;

  @override
  State<_TaskProgressMetricCard> createState() =>
      _TaskProgressMetricCardState();
}

class _TaskProgressMetricCardState extends State<_TaskProgressMetricCard>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = progressRatio(widget.pair);
    final pct = (r * 100).round();
    final br = widget.compact ? 14.0 : 18.0;
    final innerBr = br - 2;

    final borderGrad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [_borderStartDark, _borderEndDark, const Color(0xFFEC4899)]
          : const [_borderStart, _borderMid, _borderEnd],
    );

    final innerGrad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: widget.variant == _CardVariant.today
          ? (isDark
              ? [
                  _fillDarkTop,
                  _fillDarkBottom.withValues(alpha: 0.92),
                  const Color(0xFF4C1D6E).withValues(alpha: 0.85),
                ]
              : [
                  _fillPink,
                  _fillLavender,
                  _fillLilac.withValues(alpha: 0.95),
                ])
          : (isDark
              ? [
                  _fillDarkBottom,
                  _fillDarkTop.withValues(alpha: 0.95),
                  const Color(0xFF3B2663).withValues(alpha: 0.9),
                ]
              : [
                  _fillLilac.withValues(alpha: 0.92),
                  _fillPink,
                  _fillLavender,
                ]),
    );

    final titleColor = isDark ? Colors.white.withValues(alpha: 0.95) : _textPrimary;
    final subColor =
        isDark ? Colors.white.withValues(alpha: 0.65) : _textSecondary.withValues(alpha: 0.85);
    final statColor =
        isDark ? Colors.white.withValues(alpha: 0.8) : _textSecondary;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final pulse = 0.92 + 0.08 * _pulseCtrl.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(br),
            gradient: borderGrad,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B40F0).withValues(alpha: 0.22 * pulse),
                blurRadius: 16 * pulse,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFFEC4899).withValues(alpha: 0.12 * pulse),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(2),
          child: Container(
            padding: EdgeInsets.all(widget.compact ? 11 : 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(innerBr),
              gradient: innerGrad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.icon,
                      color: isDark
                          ? const Color(0xFFE9D5FF)
                          : const Color(0xFF7C3AED),
                      size: widget.compact ? 18 : 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: widget.compact ? 13 : 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: subColor,
                              fontSize: widget.compact ? 10 : 11,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFFBCFE8)
                            : const Color(0xFF86198F),
                        fontSize: widget.compact ? 16 : 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.compact ? 8 : 10),
                TweenAnimationBuilder<double>(
                  key: ValueKey('${widget.pair.done}-${widget.pair.total}'),
                  tween: Tween(begin: 0, end: r.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (context, animated, _) {
                    return _SwiftUIStyleProgressBar(
                      value: animated,
                      compact: widget.compact,
                      shimmerAnimation: _shimmerCtrl,
                      isDark: isDark,
                    );
                  },
                ),
                SizedBox(height: widget.compact ? 6 : 8),
                Text(
                  'Tamamlanan ${widget.pair.done} · Toplam ${widget.pair.total}',
                  style: TextStyle(
                    color: statColor,
                    fontSize: widget.compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
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

/// SwiftUI benzeri: yumuşak dolgu animasyonu + üzerinde kayan parlama.
class _SwiftUIStyleProgressBar extends StatelessWidget {
  const _SwiftUIStyleProgressBar({
    required this.value,
    required this.compact,
    required this.shimmerAnimation,
    required this.isDark,
  });

  final double value;
  final bool compact;
  final Animation<double> shimmerAnimation;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final h = compact ? 9.0 : 11.0;
    final trackTop = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFFFFBFE).withValues(alpha: 0.85);
    final trackBot = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFFCE7F3).withValues(alpha: 0.9);

    return ClipRRect(
      borderRadius: BorderRadius.circular(h / 2 + 2),
      child: SizedBox(
        height: h + 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // İz — hafif gradient (SwiftUI track)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [trackTop, trackBot],
                ),
              ),
            ),
            // Dolgu
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value <= 0 ? 0.001 : value,
                heightFactor: 1,
                child: AnimatedBuilder(
                  animation: shimmerAnimation,
                  builder: (context, child) {
                    final t = shimmerAnimation.value;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1.0 + 2.4 * t, -0.5),
                          end: Alignment(0.2 + 2.4 * t, 0.5),
                          colors: isDark
                              ? const [
                                  Color(0xFFA78BFA),
                                  Color(0xFFC084FC),
                                  Color(0xFFF472B6),
                                  Color(0xFFE879F9),
                                ]
                              : const [
                                  Color(0xFF8B5CF6),
                                  Color(0xFFA855F7),
                                  Color(0xFFD946EF),
                                  Color(0xFFEC4899),
                                ],
                          stops: const [0.0, 0.35, 0.65, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEC4899).withValues(alpha: 0.45),
                            blurRadius: 8,
                            spreadRadius: -1,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: CustomPaint(
                    painter: _ShimmerOverlayPainter(
                      phase: shimmerAnimation.value,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// İnce parlama bandı (SwiftUI shimmer strip).
class _ShimmerOverlayPainter extends CustomPainter {
  _ShimmerOverlayPainter({required this.phase, required this.isDark});

  final double phase;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final band = w * 0.38;
    final x = -band + (w + band * 2) * phase;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, 0, band, size.height),
      const Radius.circular(4),
    );
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          (isDark ? Colors.white : Colors.white).withValues(alpha: 0.42),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(x, 0, band, size.height));
    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerOverlayPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.isDark != isDark;
}
