import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';

import '../theme/health.dart';

/// Curba unei bătăi de inimă: două contracții rapide („lub-dub”), apoi pauză.
final Animatable<double> heartbeatCurve = TweenSequence<double>([
  TweenSequenceItem(
    tween: Tween(begin: 1.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)),
    weight: 12,
  ),
  TweenSequenceItem(
    tween: Tween(begin: 1.2, end: 0.97).chain(CurveTween(curve: Curves.easeIn)),
    weight: 12,
  ),
  TweenSequenceItem(
    tween: Tween(
      begin: 0.97,
      end: 1.12,
    ).chain(CurveTween(curve: Curves.easeOut)),
    weight: 10,
  ),
  TweenSequenceItem(
    tween: Tween(
      begin: 1.12,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeInOut)),
    weight: 18,
  ),
  TweenSequenceItem(tween: ConstantTween(1.0), weight: 48),
]);

/// Inimă cu gradient care pulsează continuu (se oprește dacă sistemul
/// cere reducerea mișcării).
class BeatingHeart extends StatefulWidget {
  const BeatingHeart({
    super.key,
    this.size = 28,
    this.color,
    this.period = const Duration(milliseconds: 1100),
  });

  final double size;

  /// Culoare plină; dacă lipsește se folosește gradientul roz.
  final Color? color;
  final Duration period;

  @override
  State<BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<BeatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      CupertinoIcons.heart_fill,
      size: widget.size,
      color: widget.color ?? CupertinoColors.white,
    );
    return ScaleTransition(
      scale: heartbeatCurve.animate(_c),
      child: widget.color != null
          ? icon
          : ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [HealthColors.heartTop, HealthColors.heartBottom],
              ).createShader(r),
              child: icon,
            ),
    );
  }
}

/// Linie EKG desenată progresiv: [progress] 0→1 parcurge traseul de la
/// stânga la dreapta, cu un punct luminos în vârf.
class EcgPainter extends CustomPainter {
  EcgPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  /// Puncte normalizate (x, y) ale unui complex PQRST, repetat de două ori.
  static const _beat = <Offset>[
    Offset(0.00, 0.5),
    Offset(0.10, 0.5),
    Offset(0.13, 0.42),
    Offset(0.16, 0.5),
    Offset(0.20, 0.5),
    Offset(0.22, 0.6),
    Offset(0.25, 0.05),
    Offset(0.28, 0.85),
    Offset(0.31, 0.5),
    Offset(0.37, 0.5),
    Offset(0.41, 0.36),
    Offset(0.45, 0.5),
    Offset(0.50, 0.5),
  ];

  Path _path(Size size) {
    final path = Path();
    var first = true;
    for (var rep = 0; rep < 2; rep++) {
      for (final p in _beat) {
        final x = (p.dx + rep * 0.5) * size.width;
        final y = p.dy * size.height;
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final metric = _path(size).computeMetrics().first;
    final length = metric.length * progress.clamp(0.0, 1.0);
    final drawn = metric.extractPath(0, length);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(colors: [color.withValues(alpha: 0.1), color])
          .createShader(Offset.zero & size);
    canvas.drawPath(drawn, stroke);

    final tip = metric.getTangentForOffset(length)?.position;
    if (tip != null && progress < 1) {
      canvas.drawCircle(
        tip,
        7,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(tip, 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(EcgPainter old) =>
      old.progress != progress || old.color != color;
}

/// Inel de progres în stilul inelelor de activitate Apple.
class ProgressRingPainter extends CustomPainter {
  ProgressRingPainter({
    required this.progress,
    this.strokeWidth = 10,
    this.color = CupertinoColors.white,
  });

  final Color color;

  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = CupertinoColors.white.withValues(alpha: 0.16),
    );

    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(ProgressRingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Apariție cu fade + glisare în sus, decalată după [index].
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  static const _duration = 520;
  late final int _delay = 70 * widget.index.clamp(0, 8);

  // Întârzierea face parte din aceeași animație (fără temporizatoare separate).
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _delay + _duration),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      _delay / (_delay + _duration),
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (_c.isDismissed) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - _t.value)),
          child: child,
        ),
      ),
    );
  }
}
