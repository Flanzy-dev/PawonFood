import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// The check mark inside a success circle of radius [r] centred on [c] (shared with CheckBurst).
Path successCheckPath(Offset c, double r) => Path()
  ..moveTo(c.dx - r * 0.38, c.dy + r * 0.02)
  ..lineTo(c.dx - r * 0.1, c.dy + r * 0.3)
  ..lineTo(c.dx + r * 0.4, c.dy - r * 0.26);

/// Success flood: green grows out of [origin] (global) until it covers the screen, a large check draws itself, then
/// the green shrinks into [landOn] (the success badge, measured when the shrink starts) or back to [origin].
///
/// [whileCovered] runs while the screen is hidden (the QR scan swaps to the review screen there); the green then
/// waits for the new page's transition before it recedes. It is awaited, so don't return a push's future from it
/// (that completes only when the pushed page pops). The flood lives in the root overlay, so it survives the
/// route that started it. Taps are absorbed until it is gone. Skipped entirely when motion is reduced.
Future<void> playSuccessFlood(BuildContext context, {required Offset origin, Rect? Function()? landOn, FutureOr<void> Function()? whileCovered}) async {
  if (Motion.reduced(context)) {
    await whileCovered?.call();
    return;
  }
  final done = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Flood(
      origin: origin,
      landOn: landOn,
      whileCovered: whileCovered,
      onDone: (remove) {
        if (remove) entry.remove();
        if (!done.isCompleted) done.complete();
      },
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  return done.future;
}

class _Flood extends StatefulWidget {
  const _Flood({required this.origin, required this.landOn, required this.whileCovered, required this.onDone});

  final Offset origin;
  final Rect? Function()? landOn;
  final FutureOr<void> Function()? whileCovered;

  /// Called once; `remove` is false when the overlay itself is being torn down.
  final void Function(bool remove) onDone;

  @override
  State<_Flood> createState() => _FloodState();
}

class _FloodState extends State<_Flood> with TickerProviderStateMixin {
  late final _grow = AnimationController(vsync: this, duration: Motion.floodGrow);
  late final _check = AnimationController(vsync: this, duration: Motion.floodHold);
  late final _recede = AnimationController(vsync: this, duration: Motion.floodRecede);
  late final _all = Listenable.merge([_grow, _check, _recede]);
  Rect? _target;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      await _grow.forward().orCancel;
      final hold = _check.forward().orCancel;
      final covered = widget.whileCovered;
      if (covered != null) {
        try {
          await covered();
        } catch (e, s) {
          // Never leave the screen stuck under the green.
          FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s, library: 'success flood'));
        }
        await Future<void>.delayed(Motion.slow); // the new page finishes its transition behind the green
      }
      await hold;
      if (!mounted) return widget.onDone(false);
      setState(() => _target = widget.landOn?.call());
      await _recede.forward().orCancel;
      widget.onDone(true);
    } on TickerCanceled {
      widget.onDone(false);
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    _check.dispose();
    _recede.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AbsorbPointer(
      child: LayoutBuilder(
        builder: (_, box) => AnimatedBuilder(
          animation: _all,
          builder: (_, _) {
            final size = box.biggest;
            // exit, not move: the shrink keeps speeding up and stops dead at the badge (or at 0), never easing to a halt.
            final r = Motion.exit.transform(_recede.value);
            final center = Offset.lerp(widget.origin, _target?.center ?? widget.origin, r)!;
            final radius = _recede.value == 0
                ? _reach(widget.origin, size) * Motion.enter.transform(_grow.value)
                : lerpDouble(_reach(center, size), (_target?.shortestSide ?? 0) / 2, r)!;
            // Light status-bar icons only while the green is behind them.
            final coversTop = (center - Offset.zero).distance < radius && (center - Offset(size.width, 0)).distance < radius;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: coversTop ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
              child: CustomPaint(
                size: size,
                painter: _FloodPainter(
                  center: center,
                  radius: radius,
                  check: Motion.enter.transform(_check.value),
                  checkRadius: lerpDouble(48, (_target?.shortestSide ?? 0) / 2, r)!,
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  /// Distance from [c] to the farthest screen corner: the radius that covers everything.
  static double _reach(Offset c, Size s) =>
      [Offset.zero, Offset(s.width, 0), Offset(0, s.height), Offset(s.width, s.height)].map((p) => (p - c).distance).reduce(math.max);
}

class _FloodPainter extends CustomPainter {
  _FloodPainter({required this.center, required this.radius, required this.check, required this.checkRadius});

  final Offset center;
  final double radius, check, checkRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;
    canvas.drawCircle(center, radius, Paint()..color = AppColors.primary);
    if (check <= 0 || checkRadius <= 0) return;
    final metric = successCheckPath(center, checkRadius).computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * check),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.5, checkRadius * 2 * 0.035)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.background,
    );
  }

  @override
  bool shouldRepaint(_FloodPainter o) => o.center != center || o.radius != radius || o.check != check || o.checkRadius != checkRadius;
}
