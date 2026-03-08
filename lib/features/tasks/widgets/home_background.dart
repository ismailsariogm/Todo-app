import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Animated pink/purple background — SwiftUI `AnimatedPinkBackground` equivalent.
/// Combines a breathing gradient, drifting blurred blobs, a sine-wave layer
/// and a twinkling sparkle field — all driven by independent AnimationControllers.
class HomeBackground extends StatefulWidget {
  const HomeBackground({super.key});

  @override
  State<HomeBackground> createState() => _HomeBackgroundState();
}

class _HomeBackgroundState extends State<HomeBackground>
    with TickerProviderStateMixin {
  // SwiftUI: @State private var breathe / drift / sparkle
  late final AnimationController _breathCtrl;
  late final AnimationController _driftCtrl;
  late final AnimationController _sparkleCtrl;
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    // 6-second breathing gradient (autoreverses)
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    // 8-second blob drift (autoreverses)
    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    // 2.2-second sparkle twinkle (autoreverses)
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Continuous wave scroll (60-second cycle)
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _driftCtrl.dispose();
    _sparkleCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _breathCtrl,
        _driftCtrl,
        _sparkleCtrl,
        _waveCtrl,
      ]),
      builder: (_, __) {
        final b = _breathCtrl.value;
        final d = _driftCtrl.value;
        final sparkBright = 0.6 + 0.4 * _sparkleCtrl.value;
        final wavePhase = _waveCtrl.value * 60;

        // ── Koyu mod renk paleti ─────────────────────────────────────
        final gradientColors = isDark
            ? const [
                Color(0xFF0D0622), // çok koyu mor-siyah
                Color(0xFF1A0A40), // koyu lacivert-mor
                Color(0xFF0A0E30), // koyu gece mavisi
              ]
            : const [
                Color(0xFF8540E0), // canlı mor
                Color(0xFFED5BBD), // pembe
                Color(0xFF9A72E8), // lavanta
              ];

        final blob1Color = isDark
            ? const Color(0xFF3B0D8F).withValues(alpha: 0.70)
            : Colors.pink.withValues(alpha: 0.55);
        final blob2Color = isDark
            ? const Color(0xFF1A0A5E).withValues(alpha: 0.65)
            : Colors.purple.withValues(alpha: 0.50);
        final blob3Color = isDark
            ? const Color(0xFF2D1070).withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.22);

        return Stack(
          fit: StackFit.expand,
          children: [
            // ── 1. Nefes alan gradient ───────────────────────────────
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.lerp(
                      Alignment.bottomLeft, Alignment.topLeft, b)!,
                  end: Alignment.lerp(
                      Alignment.topRight, Alignment.bottomRight, b)!,
                ),
              ),
            ),

            // ── 2. Bulanık blob'lar ──────────────────────────────────
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: 90 + d * 50,
                    top: 90 + d * 50,
                    child: _Blob(blob1Color, 260),
                  ),
                  Positioned(
                    right: 90 - d * 30,
                    bottom: 60 + d * 60,
                    child: _Blob(blob2Color, 320),
                  ),
                  Positioned(
                    left: -40 + d * 80,
                    top: 40 + d * 80,
                    child: _Blob(blob3Color, 220),
                  ),
                ],
              ),
            ),

            // ── 3. Dalga katmanı ─────────────────────────────────────
            CustomPaint(painter: _WavePainter(phase: wavePhase, isDark: isDark)),

            // ── 4. Yıldız parıltıları ────────────────────────────────
            CustomPaint(
                painter: _SparklePainter(
                    brightness: sparkBright,
                    dimmed: isDark)),

            // ── 5. Vignette ──────────────────────────────────────────
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: isDark ? 0.35 : 0.18),
                  ],
                  radius: 1.0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Blob helper ────────────────────────────────────────────────────────────

class _Blob extends StatelessWidget {
  const _Blob(this.color, this.size);
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

// ── Wave CustomPainter (SwiftUI WaveLayer) ─────────────────────────────────

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.phase, required this.isDark});
  final double phase;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height * 0.58;
    const amp = 26.0;
    const waveLen = 220.0;

    final path = Path()..moveTo(0, midY);
    for (double x = 0; x <= size.width; x += 4) {
      path.lineTo(x, midY + amp * math.sin((x / waveLen) + phase * 0.6));
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Koyu modda mor/mavi dalga, açık modda beyaz dalga
    final waveColor = isDark ? const Color(0xFF6B2FD9) : Colors.white;

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            waveColor.withValues(alpha: isDark ? 0.14 : 0.08),
            waveColor.withValues(alpha: isDark ? 0.05 : 0.02),
            waveColor.withValues(alpha: isDark ? 0.12 : 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.phase != phase || old.isDark != isDark;
}

// ── Sparkle CustomPainter (SwiftUI SparkleField) ───────────────────────────

class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.brightness, this.dimmed = false});
  final double brightness;
  final bool dimmed;

  static double _f(double v) => v - v.floorToDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    // Koyu modda parıltılar daha soluk
    final mult = dimmed ? 0.55 : 1.0;
    for (int i = 0; i < 90; i++) {
      final s = i / 90.0;
      final x = size.width * (0.08 + 0.84 * _f(math.sin(s * 999) * 9999));
      final y = size.height * (0.10 + 0.80 * _f(math.cos(s * 777) * 7777));
      final r = 1.2 + 2.8 * _f(math.sin(s * 333) * 3333);
      final a = (0.10 + 0.25 * _f(math.cos(s * 111) * 1111)) * brightness * mult;
      paint.color = Colors.white.withValues(alpha: a.clamp(0.0, 1.0));
      canvas.drawOval(Rect.fromLTWH(x, y, r, r), paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) =>
      old.brightness != brightness || old.dimmed != dimmed;
}
