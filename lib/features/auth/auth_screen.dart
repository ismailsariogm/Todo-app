import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/router.dart';
import 'auth_provider.dart';

// ─── Palette ───────────────────────────────────────────────────────────────────
const _ink      = Color(0xFF05000C);
const _magenta  = Color(0xFFD4006A);
const _magentaB = Color(0xFFFF2D9B);
const _purple   = Color(0xFF5C0F8B);
const _redTab   = Color(0xFFBB0022);
const _gold     = Color(0xFFFFD700);

double _h(double x) {
  final v = math.sin(x * 12.9898) * 43758.5453;
  return v - v.floorToDouble();
}

// ─── Auth Screen ───────────────────────────────────────────────────────────────
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  int _tab = 0;

  // ── Auto-dismiss error state ───────────────────────────────────────────────
  String? _errorMsg;       // null = no error shown
  bool    _errorIsNoAcct = false; // true when "not registered" error
  Timer?  _errorTimer;

  void _showError(String msg, {bool isNoAcct = false}) {
    _errorTimer?.cancel();
    setState(() {
      _errorMsg      = msg;
      _errorIsNoAcct = isNoAcct;
    });
    _errorTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() { _errorMsg = null; _errorIsNoAcct = false; });
    });
  }

  void _clearError() {
    _errorTimer?.cancel();
    _errorMsg      = null;
    _errorIsNoAcct = false;
  }
  // ──────────────────────────────────────────────────────────────────────────

  late final AnimationController _bgCtrl;
  late final AnimationController _shimCtrl;

  final _siEmail = TextEditingController();
  final _siPass  = TextEditingController();
  bool  _siObs   = true;

  final _suName    = TextEditingController();
  final _suEmail   = TextEditingController();
  final _suPass    = TextEditingController();
  final _suConf    = TextEditingController();
  final _suPhone   = TextEditingController();
  bool  _suPObs    = true;
  bool  _suCObs    = true;
  bool  _privacyAccepted   = false;
  String _selectedCountryCode = '+90'; // default Turkey

  @override
  void initState() {
    super.initState();
    _bgCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
    _shimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    // Auto-fill last signed-in email
    AuthNotifier.getLastEmail().then((email) {
      if (email != null && mounted) {
        setState(() => _siEmail.text = email);
      }
    });
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _bgCtrl.dispose(); _shimCtrl.dispose();
    _siEmail.dispose(); _siPass.dispose();
    _suName.dispose();  _suEmail.dispose();
    _suPass.dispose();  _suConf.dispose();
    _suPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    ref.listen(authStateProvider, (_, next) {
      if (next.valueOrNull != null && mounted) context.go(AppRoutes.home);
    });

    // React to auth state changes → manage inline error banner
    ref.listen(authNotifierProvider, (prev, next) {
      if (!mounted) return;
      if (next.isLoading) {
        // Clear error while loading
        setState(_clearError);
        return;
      }
      if (next.hasError) {
        final raw = next.error.toString().replaceAll('Exception: ', '');
        final isNoAcct = raw.contains('kayıtlı değil');
        _showError(raw, isNoAcct: isNoAcct);
      } else if (!next.hasError) {
        // Successful action → clear error immediately
        setState(_clearError);
      }
    });

    final sw   = MediaQuery.sizeOf(context).width;
    final maxW = sw > 520 ? 440.0 : double.infinity;

    return Scaffold(
      backgroundColor: _ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Animated background ─────────────────────────────────────────
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              painter: _BgPainter(t: _bgCtrl.value * 60),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildLogo(),
                      const SizedBox(height: 14),
                      _buildCard(auth),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Text(
          'TO-DO',
          style: GoogleFonts.bangers(
            fontSize: 58,
            letterSpacing: 4,
            color: Colors.white,
            shadows: [
              Shadow(color: _magenta.withOpacity(0.9), blurRadius: 20),
              Shadow(color: _magentaB.withOpacity(0.5), blurRadius: 45),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const _ShieldLogo(),
        const SizedBox(height: 6),
        Text(
          'TO-DO NOTE',
          style: GoogleFonts.bangers(
            fontSize: 30,
            letterSpacing: 2.5,
            color: Colors.white,
            shadows: [
              Shadow(color: _magenta.withOpacity(0.9), blurRadius: 18),
              Shadow(color: _magentaB.withOpacity(0.5), blurRadius: 36),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(AsyncValue<void> auth) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _magentaB.withOpacity(0.75), width: 1.8),
        color: Colors.black.withOpacity(0.50),
        boxShadow: [
          BoxShadow(color: _magenta.withOpacity(0.35), blurRadius: 35),
          BoxShadow(color: _magentaB.withOpacity(0.18), blurRadius: 70, spreadRadius: 8),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Tab bar
          _TabBar(selected: _tab, onChanged: (t) => setState(() => _tab = t)),
          const SizedBox(height: 14),

          // Auto-dismiss error banner (5 seconds)
          if (_errorMsg != null) ...[
            _ErrBanner(
              msg: _errorMsg!,
              isNoAccount: _errorIsNoAcct,
              onRegister: _errorIsNoAcct
                  ? () {
                      _suEmail.text = _siEmail.text.contains('@')
                          ? _siEmail.text
                          : '';
                      setState(() {
                        _tab = 1;
                        _clearError();
                      });
                    }
                  : null,
              onClose: () => setState(_clearError),
            ),
            const SizedBox(height: 10),
          ],

          // Animated form
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(_tab == 0 ? -0.08 : 0.08, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
            child: _tab == 0
                ? _SignInForm(
                    key: const ValueKey(0),
                    email:    _siEmail,
                    pass:     _siPass,
                    obs:      _siObs,
                    onToggle: () => setState(() => _siObs = !_siObs),
                    onForgot: _showForgotPassword,
                  )
                : _SignUpForm(
                    key: const ValueKey(1),
                    name:            _suName,
                    email:           _suEmail,
                    pass:            _suPass,
                    conf:            _suConf,
                    phone:           _suPhone,
                    selectedCountry: _selectedCountryCode,
                    onCountryChanged:(c) => setState(() => _selectedCountryCode = c),
                    pObs:            _suPObs,
                    cObs:            _suCObs,
                    onTP:            () => setState(() => _suPObs = !_suPObs),
                    onTC:            () => setState(() => _suCObs = !_suCObs),
                    privacyAccepted: _privacyAccepted,
                    onPrivacyToggle: (val) => setState(() => _privacyAccepted = val),
                    onPrivacyTap:    _showPrivacyPolicy,
                  ),
          ),

          const SizedBox(height: 16),

          // Action button
          auth.isLoading
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: CircularProgressIndicator(color: _magentaB),
                )
              : _ActionBtn(
                  label:   _tab == 0 ? 'SIGN IN' : 'SIGN UP',
                  shimmer: _shimCtrl,
                  onTap:   _tab == 1 && !_privacyAccepted ? _showPrivacyRequired : _submit,
                ),

          const SizedBox(height: 12),
          const _OrRow(),
          const SizedBox(height: 12),

          _SocialBtn(
            label: 'Continue with Google',
            dark: false,
            isApple: false,
            onTap: auth.isLoading ? null
                : () => ref.read(authNotifierProvider.notifier).signInWithGoogle(),
          ),
          const SizedBox(height: 10),
          _SocialBtn(
            label: 'Continue with Apple',
            dark: true,
            isApple: true,
            onTap: auth.isLoading ? null
                : () => ref.read(authNotifierProvider.notifier).signInWithApple(),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_tab == 0) {
      await ref.read(authNotifierProvider.notifier)
          .signInWithEmail(_siEmail.text.trim(), _siPass.text);
    } else {
      if (!_privacyAccepted) { _showPrivacyRequired(); return; }
      if (_suPass.text != _suConf.text) {
        ref.read(authNotifierProvider.notifier).state =
            AsyncValue.error(Exception('Şifreler eşleşmiyor'), StackTrace.current);
        return;
      }
      await ref.read(authNotifierProvider.notifier).signUpWithEmail(
            _suEmail.text.trim(), _suPass.text,
            name: _suName.text.trim(),
            phone: _suPhone.text.trim(),
            countryCode: _selectedCountryCode);
      if (!ref.read(authNotifierProvider).hasError && mounted) {
        final registeredEmail = _suEmail.text.trim();
        _suName.clear(); _suPass.clear(); _suConf.clear(); _suPhone.clear();
        // Pre-fill sign-in email with just-registered address
        _siEmail.text = registeredEmail;
        setState(() { _tab = 0; _privacyAccepted = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Kayıt başarılı! Şimdi giriş yapabilirsiniz.'),
          backgroundColor: Colors.green.shade800,
        ));
      }
    }
  }

  void _showPrivacyRequired() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Devam etmek için Gizlilik İlkesi\'ni kabul etmeniz gerekiyor.'),
      backgroundColor: Color(0xFF7B1FA2),
    ));
    _showPrivacyPolicy();
  }

  Future<void> _showPrivacyPolicy() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PrivacyPolicyDialog(),
    );
    if (accepted == true && mounted) {
      setState(() => _privacyAccepted = true);
    }
  }

  Future<void> _showForgotPassword() async {
    await showDialog(
      context: context,
      builder: (_) => _ForgotPasswordDialog(ref: ref),
    );
  }
}

// ─── Background Painter ────────────────────────────────────────────────────────
class _BgPainter extends CustomPainter {
  const _BgPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.3;
    final center = Offset(cx, cy);

    // 1. Deep purple radial gradient
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.42),
          radius: 1.1,
          colors: [
            const Color(0xFF3D0058),
            const Color(0xFF160028),
            Colors.black,
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(Offset.zero & size),
    );

    // 2. Rotating burst speed lines
    final rot = (t / 8.0) * math.pi * 2;
    final maxR = size.longestSide * 1.15;
    const nLines = 28;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rot);
    for (int i = 0; i < nLines; i++) {
      final angle = (i / nLines) * math.pi * 2;
      final phase = (t * 0.42 + i / nLines) % 1.0;
      final fade  = (0.55 * math.sin(phase * math.pi)).clamp(0.0, 1.0);
      final startR = maxR * (0.04 + 0.07 * (1 - phase));
      final endR   = maxR * (0.18 + 0.80 * phase).clamp(0.0, 1.0);
      final sw     = 1.2 + 3.2 * (1 - phase);
      canvas.drawLine(
        Offset(math.cos(angle) * startR, math.sin(angle) * startR),
        Offset(math.cos(angle) * endR,   math.sin(angle) * endR),
        Paint()
          ..color      = _magentaB.withOpacity(fade * 0.6)
          ..strokeWidth = sw
          ..strokeCap  = StrokeCap.round,
      );
    }
    canvas.restore();

    // 3. Center radial glow
    canvas.drawCircle(
      center,
      size.width * 0.38,
      Paint()
        ..shader = RadialGradient(
          colors: [_magenta.withOpacity(0.28), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.38)),
    );

    // 4. Floating particles + confetti (screen blend)
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.screen);
    _drawParticles(canvas, size);
    canvas.restore();

    // 5. Vignette
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withOpacity(0.08),
            Colors.transparent,
            Colors.black.withOpacity(0.65),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(bounds),
    );
  }

  void _drawParticles(Canvas canvas, Size size) {
    final paint = Paint();
    const count = 60;
    for (int i = 0; i < count; i++) {
      final s  = i.toDouble();
      final bx = _h(s * 11.3) * size.width;
      final by = _h(s * 7.7)  * size.height;
      final sp = 0.04 + _h(s * 3.5) * 0.13;
      final ph = (t * sp + _h(s * 4.9)) % 1.0;
      final al = (math.sin(ph * math.pi) * 0.9).clamp(0.0, 1.0);
      final x  = bx + math.sin(t * 0.9 + s * 1.8) * 26;
      final y  = by - ((ph * 260) % (size.height + 60));

      if (i % 4 == 0) {
        // Confetti square
        final sz  = 4.0 + _h(s * 2.2) * 10;
        final rot = t * 2.1 + s * 2.9;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rot);
        paint
          ..color      = _magenta.withOpacity(al * 0.9)
          ..style      = PaintingStyle.fill
          ..maskFilter = null;
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: sz, height: sz * 0.5),
          paint,
        );
        canvas.restore();
      } else {
        final r   = 1.5 + _h(s * 9.3) * 3.5;
        paint
          ..color      = _magentaB.withOpacity(al * 0.80)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 2.5);
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
    paint.maskFilter = null;
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── Shield Logo ───────────────────────────────────────────────────────────────
class _ShieldLogo extends StatelessWidget {
  const _ShieldLogo();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 155,
    height: 135,
    child: CustomPaint(painter: _ShieldPainter()),
  );
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;

    // Shield path
    final path = Path()
      ..moveTo(w * 0.13, 0)
      ..lineTo(w * 0.87, 0)
      ..quadraticBezierTo(w, 0, w, h * 0.14)
      ..lineTo(w, h * 0.56)
      ..cubicTo(w, h * 0.73, w * 0.65, h * 0.89, w / 2, h)
      ..cubicTo(w * 0.35, h * 0.89, 0, h * 0.73, 0, h * 0.56)
      ..lineTo(0, h * 0.14)
      ..quadraticBezierTo(0, 0, w * 0.13, 0)
      ..close();

    // Glow
    canvas.drawShadow(path, _magenta.withOpacity(0.85), 22, true);
    canvas.drawShadow(path, _magentaB.withOpacity(0.35), 44, true);

    // Fill gradient
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF7B1FA2),
            const Color(0xFF3D0065),
            const Color(0xFF18002A),
          ],
          stops: const [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Gradient border
    canvas.drawPath(
      path,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..shader = LinearGradient(
          colors: [_magentaB, _magenta, _purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Inner highlight
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.20, h * 0.06)
        ..lineTo(w * 0.80, h * 0.06)
        ..quadraticBezierTo(w * 0.91, h * 0.06, w * 0.91, h * 0.18)
        ..lineTo(w * 0.91, h * 0.38),
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap   = StrokeCap.round
        ..color       = Colors.white.withOpacity(0.22),
    );

    // Checkmark glow
    final ck = Path()
      ..moveTo(w * 0.22, h * 0.44)
      ..lineTo(w * 0.41, h * 0.62)
      ..lineTo(w * 0.73, h * 0.24);
    canvas.drawPath(
      ck,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round
        ..color       = const Color(0x334CAF50),
    );
    canvas.drawPath(
      ck,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round
        ..color       = const Color(0xFF4CAF50),
    );

    // Lightning bolt glow
    final bolt = Path()
      ..moveTo(w * 0.60, h * 0.20)
      ..lineTo(w * 0.44, h * 0.47)
      ..lineTo(w * 0.54, h * 0.47)
      ..lineTo(w * 0.37, h * 0.76)
      ..lineTo(w * 0.68, h * 0.44)
      ..lineTo(w * 0.58, h * 0.44)
      ..close();
    canvas.drawPath(
      bolt,
      Paint()
        ..color      = Colors.yellow.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawPath(
      bolt,
      Paint()
        ..color      = const Color(0xFFFFB300)
        ..style      = PaintingStyle.fill
        ..maskFilter = null,
    );
    canvas.drawPath(
      bolt,
      Paint()
        ..color       = const Color(0xFFFFF176)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Tab Bar ───────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final half = constraints.maxWidth / 2;
        return Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _magenta.withOpacity(0.45), width: 1.2),
          ),
          child: Stack(
            children: [
              // Sliding red indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
                left:   selected == 0 ? 0 : half,
                width:  half,
                top:    0,
                bottom: 0,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: _redTab,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: _redTab.withOpacity(0.55), blurRadius: 10),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _TabItem('SIGN IN', selected == 0, () => onChanged(0)),
                  _TabItem('SIGN UP', selected == 1, () => onChanged(1)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem(this.label, this.sel, this.onTap);
  final String label;
  final bool sel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: sel ? Colors.white : Colors.white.withOpacity(0.45),
          ),
          child: Text(label),
        ),
      ),
    ),
  );
}

// ─── Sign In Form ──────────────────────────────────────────────────────────────
class _SignInForm extends StatelessWidget {
  const _SignInForm({
    super.key,
    required this.email,
    required this.pass,
    required this.obs,
    required this.onToggle,
    required this.onForgot,
  });
  final TextEditingController email, pass;
  final bool obs;
  final VoidCallback onToggle;
  final VoidCallback onForgot;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      _NeonField(ctrl: email, icon: Icons.person_search_rounded, hint: 'E-posta veya Kullanıcı Adı', type: TextInputType.emailAddress),
      const SizedBox(height: 11),
      _PassField(ctrl: pass, hint: 'Şifre', obs: obs, onToggle: onToggle),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: onForgot,
        child: Text(
          'Şifremi Unuttum?',
          style: TextStyle(
            color: _magentaB.withOpacity(0.85),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: _magentaB.withOpacity(0.60),
          ),
        ),
      ),
    ],
  );
}

// ─── Sign Up Form ──────────────────────────────────────────────────────────────
class _SignUpForm extends StatelessWidget {
  const _SignUpForm({
    super.key,
    required this.name, required this.email, required this.pass, required this.conf,
    required this.phone, required this.selectedCountry, required this.onCountryChanged,
    required this.pObs, required this.cObs,
    required this.onTP, required this.onTC,
    required this.privacyAccepted,
    required this.onPrivacyToggle,
    required this.onPrivacyTap,
  });
  final TextEditingController name, email, pass, conf, phone;
  final String selectedCountry;
  final ValueChanged<String> onCountryChanged;
  final bool pObs, cObs;
  final VoidCallback onTP, onTC;
  final bool privacyAccepted;
  final ValueChanged<bool> onPrivacyToggle;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _NeonField(ctrl: name,  icon: Icons.person_outline_rounded, hint: 'Full Name'),
      const SizedBox(height: 11),
      _NeonField(ctrl: email, icon: Icons.email_outlined, hint: 'Email Address', type: TextInputType.emailAddress),
      const SizedBox(height: 11),
      _PassField(ctrl: pass, hint: 'Password',         obs: pObs, onToggle: onTP),
      const SizedBox(height: 11),
      _PassField(ctrl: conf, hint: 'Confirm Password', obs: cObs, onToggle: onTC),
      const SizedBox(height: 11),
      _PhoneField(ctrl: phone, selectedCountry: selectedCountry, onCountryChanged: onCountryChanged),
      const SizedBox(height: 14),
      // ── Privacy policy checkbox ────────────────────────────────────────
      GestureDetector(
        onTap: () => onPrivacyToggle(!privacyAccepted),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22, height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: privacyAccepted
                    ? _magentaB
                    : Colors.transparent,
                border: Border.all(
                  color: privacyAccepted ? _magentaB : _magenta.withOpacity(0.65),
                  width: 2,
                ),
                boxShadow: privacyAccepted
                    ? [BoxShadow(color: _magentaB.withOpacity(0.40), blurRadius: 8)]
                    : null,
              ),
              child: privacyAccepted
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: onPrivacyTap,
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                    children: [
                      const TextSpan(text: 'Okudum ve '),
                      TextSpan(
                        text: 'Gizlilik İlkesi',
                        style: TextStyle(
                          color: _magentaB,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: _magentaB,
                        ),
                      ),
                      const TextSpan(text: '\'ni kabul ediyorum.'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// ─── Neon Text Field ───────────────────────────────────────────────────────────
class _NeonField extends StatefulWidget {
  const _NeonField({
    required this.ctrl,
    required this.icon,
    required this.hint,
    this.type = TextInputType.text,
  });
  final TextEditingController ctrl;
  final IconData icon;
  final String hint;
  final TextInputType type;

  @override
  State<_NeonField> createState() => _NeonFieldState();
}

class _NeonFieldState extends State<_NeonField> {
  final _fn = FocusNode();
  bool _hov = false;

  @override
  void initState() {
    super.initState();
    _fn.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _fn.hasFocus;
    final active  = focused || _hov;

    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hov && !focused
                ? _gold
                : focused ? _magentaB : _magenta.withOpacity(0.55),
            width: _hov && !focused ? 2.8 : (focused ? 2.0 : 1.4),
          ),
          color: Colors.black.withOpacity(0.30),
          boxShadow: focused
              ? [BoxShadow(color: _magenta.withOpacity(0.35), blurRadius: 14)]
              : _hov
                  ? [BoxShadow(color: _gold.withOpacity(0.22), blurRadius: 12)]
                  : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(widget.icon, color: Colors.white.withOpacity(active ? 0.8 : 0.55), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller:  widget.ctrl,
                focusNode:   _fn,
                keyboardType: widget.type,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText:   widget.hint,
                  hintStyle:  TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Password Field ────────────────────────────────────────────────────────────
class _PassField extends StatefulWidget {
  const _PassField({
    required this.ctrl,
    required this.hint,
    required this.obs,
    required this.onToggle,
  });
  final TextEditingController ctrl;
  final String hint;
  final bool obs;
  final VoidCallback onToggle;

  @override
  State<_PassField> createState() => _PassFieldState();
}

class _PassFieldState extends State<_PassField> {
  final _fn  = FocusNode();
  bool  _hov = false;

  @override
  void initState() {
    super.initState();
    _fn.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _fn.hasFocus;
    final active  = focused || _hov;

    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hov && !focused
                ? _gold
                : focused ? _magentaB : _magenta.withOpacity(0.55),
            width: _hov && !focused ? 2.8 : (focused ? 2.0 : 1.4),
          ),
          color: Colors.black.withOpacity(0.30),
          boxShadow: focused
              ? [BoxShadow(color: _magenta.withOpacity(0.35), blurRadius: 14)]
              : _hov
                  ? [BoxShadow(color: _gold.withOpacity(0.22), blurRadius: 12)]
                  : null,
        ),
        padding: const EdgeInsets.only(left: 14, right: 4, top: 11, bottom: 11),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Colors.white.withOpacity(active ? 0.8 : 0.55), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller:  widget.ctrl,
                focusNode:   _fn,
                obscureText: widget.obs,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText:   widget.hint,
                  hintStyle:  TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            // Eye icon (göz ikonu)
            GestureDetector(
              onTap: widget.onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    widget.obs
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    key: ValueKey(widget.obs),
                    color: Colors.white.withOpacity(0.70),
                    size: 21,
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

// ─── Action Button (SIGN IN / SIGN UP) ────────────────────────────────────────
class _ActionBtn extends StatefulWidget {
  const _ActionBtn({
    required this.label,
    required this.shimmer,
    required this.onTap,
  });
  final String label;
  final AnimationController shimmer;
  final VoidCallback onTap;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hov  = false;
  bool _press = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTapDown:   (_) => setState(() => _press = true),
        onTapCancel: ()  => setState(() => _press = false),
        onTapUp:     (_) { setState(() => _press = false); widget.onTap(); },
        child: AnimatedScale(
          scale: _press ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 54,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: const LinearGradient(
                colors: [Color(0xFFAA0022), _magenta, _magentaB],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: _hov
                  ? Border.all(color: _gold, width: 3.0)
                  : Border.all(color: Colors.transparent, width: 3.0),
              boxShadow: [
                BoxShadow(color: _magenta.withOpacity(0.52), blurRadius: 22, offset: const Offset(0, 8)),
                if (_hov)
                  BoxShadow(color: _gold.withOpacity(0.45), blurRadius: 24, spreadRadius: 2),
              ],
            ),
            child: AnimatedBuilder(
              animation: widget.shimmer,
              builder: (_, __) => Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(27),
                    child: CustomPaint(
                      painter: _ShimmerPainter(progress: widget.shimmer.value),
                    ),
                  ),
                  Center(
                    child: Text(
                      widget.label,
                      style: GoogleFonts.nunito(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: Colors.white,
                        shadows: const [Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  const _ShimmerPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final x = (progress * 1.8 - 0.4) * size.width;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.transparent, Colors.white.withOpacity(0.40), Colors.transparent],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(x - 55, 0, 110, size.height));
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(18 * math.pi / 180);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRect(Offset.zero & size, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

// ─── OR Row ────────────────────────────────────────────────────────────────────
class _OrRow extends StatelessWidget {
  const _OrRow();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.18))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'OR',
          style: GoogleFonts.nunito(
            fontSize: 13, fontWeight: FontWeight.w900,
            color: Colors.white.withOpacity(0.80), letterSpacing: 2,
          ),
        ),
      ),
      Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.18))),
    ],
  );
}

// ─── Social Button ─────────────────────────────────────────────────────────────
class _SocialBtn extends StatefulWidget {
  const _SocialBtn({
    required this.label,
    required this.dark,
    required this.isApple,
    required this.onTap,
  });
  final String label;
  final bool dark, isApple;
  final VoidCallback? onTap;

  @override
  State<_SocialBtn> createState() => _SocialBtnState();
}

class _SocialBtnState extends State<_SocialBtn> {
  bool _hov  = false;
  bool _press = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTapDown:   widget.onTap == null ? null : (_) => setState(() => _press = true),
        onTapCancel: () => setState(() => _press = false),
        onTapUp:     (_) { setState(() => _press = false); widget.onTap?.call(); },
        child: AnimatedScale(
          scale: _press ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 50,
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.dark
                  ? Colors.black.withOpacity(0.72)
                  : Colors.white.withOpacity(0.93),
              borderRadius: BorderRadius.circular(14),
              border: _hov
                  ? Border.all(color: _gold, width: 2.8)
                  : Border.all(
                      color: widget.dark
                          ? Colors.white.withOpacity(0.18)
                          : _magenta.withOpacity(0.42),
                      width: 1.2,
                    ),
              boxShadow: _hov
                  ? [BoxShadow(color: _gold.withOpacity(0.35), blurRadius: 18, spreadRadius: 1)]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isApple)
                  Icon(Icons.apple_rounded, size: 22,
                      color: widget.dark ? Colors.white : Colors.black87)
                else
                  Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: Center(
                      child: Text('G',
                        style: GoogleFonts.roboto(
                          color: const Color(0xFF4285F4),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        )),
                    ),
                  ),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: widget.dark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Phone Field ────────────────────────────────────────────────────────────────

/// Common country codes for the picker dropdown.
const _kCountryCodes = [
  (code: '+90',  flag: '🇹🇷', name: 'Türkiye'),
  (code: '+1',   flag: '🇺🇸', name: 'ABD'),
  (code: '+44',  flag: '🇬🇧', name: 'Birleşik Krallık'),
  (code: '+49',  flag: '🇩🇪', name: 'Almanya'),
  (code: '+33',  flag: '🇫🇷', name: 'Fransa'),
  (code: '+39',  flag: '🇮🇹', name: 'İtalya'),
  (code: '+34',  flag: '🇪🇸', name: 'İspanya'),
  (code: '+31',  flag: '🇳🇱', name: 'Hollanda'),
  (code: '+7',   flag: '🇷🇺', name: 'Rusya'),
  (code: '+86',  flag: '🇨🇳', name: 'Çin'),
  (code: '+81',  flag: '🇯🇵', name: 'Japonya'),
  (code: '+82',  flag: '🇰🇷', name: 'Güney Kore'),
  (code: '+91',  flag: '🇮🇳', name: 'Hindistan'),
  (code: '+55',  flag: '🇧🇷', name: 'Brezilya'),
  (code: '+52',  flag: '🇲🇽', name: 'Meksika'),
  (code: '+61',  flag: '🇦🇺', name: 'Avustralya'),
  (code: '+20',  flag: '🇪🇬', name: 'Mısır'),
  (code: '+966', flag: '🇸🇦', name: 'Suudi Arabistan'),
  (code: '+971', flag: '🇦🇪', name: 'BAE'),
  (code: '+212', flag: '🇲🇦', name: 'Fas'),
];

class _PhoneField extends StatefulWidget {
  const _PhoneField({
    required this.ctrl,
    required this.selectedCountry,
    required this.onCountryChanged,
  });
  final TextEditingController ctrl;
  final String selectedCountry;
  final ValueChanged<String> onCountryChanged;

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  final _fn  = FocusNode();
  bool _hov  = false;

  @override
  void initState() {
    super.initState();
    _fn.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _fn.hasFocus;

    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hov && !focused
                ? _gold
                : focused ? _magentaB : _magenta.withOpacity(0.55),
            width: _hov && !focused ? 2.8 : (focused ? 2.0 : 1.4),
          ),
          color: Colors.black.withOpacity(0.30),
          boxShadow: focused
              ? [BoxShadow(color: _magenta.withOpacity(0.35), blurRadius: 14)]
              : _hov
                  ? [BoxShadow(color: _gold.withOpacity(0.22), blurRadius: 12)]
                  : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Country code dropdown
            GestureDetector(
              onTap: () => _showCountryPicker(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _flagFor(widget.selectedCountry),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.selectedCountry,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down,
                        color: Colors.white.withOpacity(0.65), size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Divider
            Container(width: 1, height: 22, color: Colors.white.withOpacity(0.25)),
            const SizedBox(width: 10),
            // Phone number input
            Expanded(
              child: TextField(
                controller: widget.ctrl,
                focusNode: _fn,
                keyboardType: TextInputType.phone,
                autocorrect: false,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Telefon numarası',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.42), fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Icon(Icons.phone_outlined,
                color: Colors.white.withOpacity(0.55), size: 20),
          ],
        ),
      ),
    );
  }

  String _flagFor(String code) {
    try {
      return _kCountryCodes.firstWhere((c) => c.code == code).flag;
    } catch (_) {
      return '🌍';
    }
  }

  Future<void> _showCountryPicker(BuildContext context) async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF1A0030),
        child: SizedBox(
          width: 320,
          height: 420,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    const Text('Ülke Seç',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close,
                          color: Colors.white.withOpacity(0.60)),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.15)),
              Expanded(
                child: ListView(
                  children: _kCountryCodes.map((c) {
                    final active = c.code == widget.selectedCountry;
                    return ListTile(
                      leading: Text(c.flag,
                          style: const TextStyle(fontSize: 22)),
                      title: Text(c.name,
                          style: TextStyle(
                              color: active ? _magentaB : Colors.white,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w400)),
                      trailing: Text(c.code,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.60),
                              fontSize: 13)),
                      onTap: () => Navigator.pop(context, c.code),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) widget.onCountryChanged(chosen);
  }
}

// ─── Error Banner (auto-dismiss, with optional "Kayıt Ol" action) ─────────────
class _ErrBanner extends StatefulWidget {
  const _ErrBanner({
    required this.msg,
    this.isNoAccount = false,
    this.onRegister,
    this.onClose,
  });
  final String msg;
  final bool isNoAccount;
  final VoidCallback? onRegister;
  final VoidCallback? onClose;

  @override
  State<_ErrBanner> createState() => _ErrBannerState();
}

class _ErrBannerState extends State<_ErrBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300))
      ..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isNoAccount
        ? const Color(0xFF7B1FA2)
        : Colors.red.shade900;
    final border = widget.isNoAccount
        ? const Color(0xFFCE93D8)
        : Colors.red.shade400;

    return FadeTransition(
      opacity: _fade,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: bg.withOpacity(0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border.withOpacity(0.70)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.isNoAccount
                      ? Icons.person_search_rounded
                      : Icons.error_outline,
                  color: Colors.white70,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.msg,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                // X close button
                GestureDetector(
                  onTap: widget.onClose,
                  child: const Icon(Icons.close, color: Colors.white54, size: 16),
                ),
              ],
            ),
            if (widget.isNoAccount && widget.onRegister != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: widget.onRegister,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                  ),
                  child: const Text(
                    'Kayıt Ol →',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Privacy Policy Dialog ─────────────────────────────────────────────────────
class _PrivacyPolicyDialog extends StatelessWidget {
  const _PrivacyPolicyDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF1A0030),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _magentaB.withOpacity(0.60), width: 1.5),
          boxShadow: [
            BoxShadow(color: _magenta.withOpacity(0.30), blurRadius: 30),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                gradient: LinearGradient(
                  colors: [_purple.withOpacity(0.80), _magenta.withOpacity(0.60)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Gizlilik İlkesi',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Icon(Icons.close,
                        color: Colors.white.withOpacity(0.70), size: 20),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Text(
                  '''TO-DO NOTE Gizlilik İlkesi

Son güncelleme: Mart 2026

1. Toplanan Veriler
Uygulamamız yalnızca hesap oluşturma ve hizmet sunmak amacıyla ad, e-posta adresi ve şifre bilgilerinizi toplar. Görevleriniz, gruplarınız ve mesajlarınız yalnızca cihazınızda yerel olarak saklanır.

2. Veri Kullanımı
Toplanan veriler; hesabınızı doğrulamak, kişiselleştirilmiş deneyim sunmak ve uygulama güvenliğini sağlamak için kullanılır. Verileriniz üçüncü şahıslarla paylaşılmaz.

3. Veri Güvenliği
Şifreleriniz yerel depolama alanında tutulur. Güvenliğiniz için güçlü ve benzersiz bir şifre kullanmanızı tavsiye ederiz.

4. Çerezler ve Yerel Depolama
Uygulama, oturum bilgilerinizi hatırlamak için tarayıcı yerel depolama alanını (localStorage) kullanır. Bu verileri tarayıcı ayarlarından temizleyebilirsiniz.

5. Haklarınız
Hesabınızı ve verilerinizi istediğiniz zaman silebilirsiniz. Sorularınız için destek ekibimizle iletişime geçebilirsiniz.

6. Değişiklikler
Bu gizlilik ilkesi zaman zaman güncellenebilir. Önemli değişikliklerde kullanıcılar bilgilendirilecektir.

Bu uygulamayı kullanarak bu gizlilik ilkesini kabul etmiş sayılırsınız.''',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.80),
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.30)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Kabul Etmiyorum',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _magenta,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Kabul Ediyorum',
                          style: TextStyle(fontWeight: FontWeight.w700)),
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
}

// ─── Forgot Password Dialog ────────────────────────────────────────────────────
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _emailCtrl   = TextEditingController();
  final _pass1Ctrl   = TextEditingController();
  final _pass2Ctrl   = TextEditingController();
  int  _step         = 0; // 0=email, 1=new password
  bool _loading      = false;
  bool _p1Obs        = true;
  bool _p2Obs        = true;
  String? _error;
  String? _foundName;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pass1Ctrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF1A0030),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _magentaB.withOpacity(0.60), width: 1.5),
          boxShadow: [
            BoxShadow(color: _magenta.withOpacity(0.30), blurRadius: 30),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                const Icon(Icons.lock_reset_rounded, color: _magentaB, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _step == 0 ? 'Şifremi Unuttum' : 'Yeni Şifre Oluştur',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close,
                      color: Colors.white.withOpacity(0.60), size: 20),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.70),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(color: Colors.white, fontSize: 12))),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            if (_step == 0) ...[
              Text(
                'Kayıtlı e-posta adresinizi girin. Sisteminiz doğrulandıktan sonra yeni şifrenizi oluşturabilirsiniz.',
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              _DialogField(
                ctrl: _emailCtrl,
                hint: 'E-posta adresiniz',
                icon: Icons.email_outlined,
                type: TextInputType.emailAddress,
              ),
            ] else ...[
              Text(
                'Merhaba $_foundName! Yeni şifrenizi belirleyin.',
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
              ),
              const SizedBox(height: 14),
              _DialogPassField(ctrl: _pass1Ctrl, hint: 'Yeni şifre', obs: _p1Obs,
                  onToggle: () => setState(() => _p1Obs = !_p1Obs)),
              const SizedBox(height: 10),
              _DialogPassField(ctrl: _pass2Ctrl, hint: 'Yeni şifre (tekrar)', obs: _p2Obs,
                  onToggle: () => setState(() => _p2Obs = !_p2Obs)),
            ],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : (_step == 0 ? _checkEmail : _resetPassword),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _magenta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _step == 0 ? 'Devam Et' : 'Şifreyi Kaydet',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkEmail() async {
    setState(() { _loading = true; _error = null; });
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() { _error = 'E-posta adresinizi girin.'; _loading = false; });
      return;
    }
    final name = await widget.ref
        .read(authNotifierProvider.notifier)
        .findRegisteredEmail(email);
    if (name == null) {
      setState(() {
        _error = 'Bu e-posta kayıtlı değil. Lütfen önce kayıt olunuz.';
        _loading = false;
      });
      return;
    }
    setState(() { _foundName = name; _step = 1; _loading = false; });
  }

  Future<void> _resetPassword() async {
    setState(() { _loading = true; _error = null; });
    final p1 = _pass1Ctrl.text;
    final p2 = _pass2Ctrl.text;
    if (p1.length < 6) {
      setState(() { _error = 'Şifre en az 6 karakter olmalıdır.'; _loading = false; });
      return;
    }
    if (p1 != p2) {
      setState(() { _error = 'Şifreler eşleşmiyor.'; _loading = false; });
      return;
    }
    await widget.ref
        .read(authNotifierProvider.notifier)
        .resetPasswordWithNew(_emailCtrl.text.trim(), p1);

    final hasError = widget.ref.read(authNotifierProvider).hasError;
    if (hasError) {
      setState(() {
        _error = widget.ref.read(authNotifierProvider).error.toString()
            .replaceAll('Exception: ', '');
        _loading = false;
      });
      return;
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Şifreniz başarıyla güncellendi! Yeni şifrenizle giriş yapabilirsiniz.'),
        backgroundColor: Color(0xFF1B5E20),
        duration: Duration(seconds: 4),
      ));
    }
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.ctrl,
    required this.hint,
    required this.icon,
    this.type = TextInputType.text,
  });
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final TextInputType type;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.30),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _magenta.withOpacity(0.55)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Icon(icon, color: Colors.white54, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: type,
            autocorrect: false,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 14),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DialogPassField extends StatelessWidget {
  const _DialogPassField({
    required this.ctrl,
    required this.hint,
    required this.obs,
    required this.onToggle,
  });
  final TextEditingController ctrl;
  final String hint;
  final bool obs;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.30),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _magenta.withOpacity(0.55)),
    ),
    padding: const EdgeInsets.only(left: 14, right: 4, top: 12, bottom: 12),
    child: Row(
      children: [
        Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctrl,
            obscureText: obs,
            autocorrect: false,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 14),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        GestureDetector(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              obs ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.white.withOpacity(0.60),
              size: 19,
            ),
          ),
        ),
      ],
    ),
  );
}
