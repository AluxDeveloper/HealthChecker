import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../theme/health.dart';
import '../widgets/heartbeat.dart';

/// Ecranul de intrare: inima bate de două ori, undele pornesc din ea,
/// linia EKG se desenează, apoi aplicația apare cu o tranziție lină.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});

  final WidgetBuilder next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2600);

  /// Cronologia întregului intro (0 → 1).
  late final AnimationController _timeline = AnimationController(
    vsync: this,
    duration: _total,
  );

  /// Bătăile inimii (se repetă).
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  late final Animation<double> _heartIn = CurvedAnimation(
    parent: _timeline,
    curve: const Interval(0.0, 0.22, curve: Curves.easeOutBack),
  );
  late final Animation<double> _ecg = CurvedAnimation(
    parent: _timeline,
    curve: const Interval(0.15, 0.75, curve: Curves.easeInOut),
  );
  late final Animation<double> _textIn = CurvedAnimation(
    parent: _timeline,
    curve: const Interval(0.35, 0.6, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _beat.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.lightImpact();
        _beat.forward(from: 0);
      }
    });
    _timeline.forward().whenComplete(_goNext);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _beat.forward();
    });
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (context, _, _) => widget.next(context),
        transitionsBuilder: (context, anim, _, child) {
          final t = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: t,
            child: ScaleTransition(
              scale: Tween(begin: 1.06, end: 1.0).animate(t),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _timeline.dispose();
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const crimson = HealthColors.heartTop;
    const white = CupertinoColors.white;

    // fundal bleumarin în ambele moduri → text alb în bara de stare
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: HealthColors.navy,
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // gradient bleumarin + strălucire roșie difuză în spatele inimii
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: HealthColors.navyGradient,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.15),
                      radius: 0.75,
                      colors: [
                        crimson.withValues(alpha: 0.18),
                        crimson.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _Ripple(beat: _beat, color: white, delay: 0),
                        _Ripple(beat: _beat, color: crimson, delay: 0.25),
                        ScaleTransition(
                          scale: _heartIn,
                          child: ScaleTransition(
                            scale: heartbeatCurve.animate(_beat),
                            child: const _HeartBadge(color: crimson),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    height: 56,
                    child: AnimatedBuilder(
                      animation: _ecg,
                      builder: (context, _) => CustomPaint(
                        painter: EcgPainter(
                          progress: _ecg.value,
                          color: HealthColors.ecgBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _textIn,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(_textIn),
                      child: Column(
                        children: [
                          Text(
                            'Sarcini',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Grijă de tine, la timp.',
                            style: TextStyle(
                              fontSize: 17,
                              color: white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inima albă pe un pătrat rotunjit roz, ca pictograma aplicației Sănătate.
class _HeartBadge extends StatelessWidget {
  const _HeartBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        gradient: HealthColors.crimsonGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(
        CupertinoIcons.heart_fill,
        size: 62,
        color: CupertinoColors.white,
      ),
    );
  }
}

/// Undă circulară care pornește din inimă la fiecare bătaie.
class _Ripple extends StatelessWidget {
  const _Ripple({required this.beat, required this.color, required this.delay});

  final Animation<double> beat;
  final Color color;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: beat,
      builder: (context, _) {
        final t = ((beat.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        if (t == 0) return const SizedBox.shrink();
        final eased = Curves.easeOut.transform(t);
        return Container(
          width: 112 + 108 * eased,
          height: 112 + 108 * eased,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.5 * (1 - eased)),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
