import 'package:flutter/material.dart';

/// Shared gradient FAB used across all screens.
/// [pulse] = true adds a repeating ring animation (for home screen).
class PinkFab extends StatefulWidget {
  const PinkFab({
    super.key,
    required this.onTap,
    required this.heroTag,
    this.pulse = false,
    this.label = 'Görev Ekle',
  });

  final VoidCallback onTap;
  final String heroTag;
  final bool pulse;
  final String label;

  @override
  State<PinkFab> createState() => _PinkFabState();
}

class _PinkFabState extends State<PinkFab> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.pulse) _ctrl.repeat();

    _scaleAnim = Tween<double>(begin: 0.98, end: 1.18)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacityAnim = Tween<double>(begin: 0.55, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: Hero(
        tag: widget.heroTag,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse ring (only when pulse=true) — IgnorePointer ile tıklamaları engellemez
                  if (widget.pulse)
                    IgnorePointer(
                      child: Transform.scale(
                        scale: _scaleAnim.value,
                        child: Opacity(
                          opacity: _opacityAnim.value,
                          child: Container(
                            width: 148,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  child!,
                ],
              );
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B40F0), Color(0xFFCF4DA6)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B40F0).withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
