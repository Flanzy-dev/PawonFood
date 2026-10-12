import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';
import 'success_flood.dart';

/// Counts from the previous value (or [from] on first build) to [value]. For points and impact numbers.
class AnimatedCount extends StatefulWidget {
  const AnimatedCount({super.key, required this.value, required this.style, this.from, this.format, this.duration = Motion.count});

  final num value;
  final TextStyle style;

  /// Start value on first build. Null shows [value] straight away and animates only later changes.
  final num? from;
  final String Function(num v)? format;
  final Duration duration;

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount> {
  late num _begin = widget.from ?? widget.value;

  @override
  void didUpdateWidget(AnimatedCount old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _begin = old.value;
  }

  String _fmt(num v) => widget.format?.call(v) ?? (widget.value is int ? '${v.round()}' : v.toStringAsFixed(1).replaceAll('.', ','));

  @override
  Widget build(BuildContext context) {
    // The final text is the semantic value, so screen readers never hear the in-between numbers.
    return Semantics(
      label: _fmt(widget.value),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(widget.value),
        tween: Tween(begin: _begin.toDouble(), end: widget.value.toDouble()),
        duration: Motion.of(context, widget.duration),
        curve: Curves.easeOutQuart,
        builder: (_, v, _) => Text(_fmt(widget.value is int ? v.round() : v), style: widget.style),
      ),
    );
  }
}

/// Success mark: a filled circle pops in, then the check draws itself, with one soft ring expanding behind.
///
/// With [flood] (full success screens) the green first covers the whole screen and settles into this badge
/// ([playSuccessFlood]); the badge then only plays its ring.
class CheckBurst extends StatefulWidget {
  const CheckBurst({super.key, this.size = 88, this.color = AppColors.primary, this.checkColor = AppColors.background, this.delay = Duration.zero, this.flood = false});

  final double size;
  final Color color;
  final Color checkColor;
  final Duration delay;
  final bool flood;

  @override
  State<CheckBurst> createState() => _CheckBurstState();
}

class _CheckBurstState extends State<CheckBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  Timer? _timer;
  bool _flooding = false;

  /// The flood has settled into the badge: circle and check are complete, [_c] drives the ring only.
  bool _landed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timer != null || _flooding || _c.isAnimating || _c.isCompleted) return;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else if (widget.flood) {
      _flooding = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startFlood());
    } else {
      _timer = Timer(widget.delay, _c.forward);
    }
  }

  /// The badge's circle in global coordinates, or null once it is gone.
  Rect? _badge() {
    final box = mounted ? context.findRenderObject() as RenderBox? : null;
    if (box == null || !box.attached || !box.hasSize) return null;
    return Rect.fromCircle(center: box.localToGlobal(box.size.center(Offset.zero)), radius: widget.size / 2);
  }

  void _startFlood() {
    final badge = _badge();
    if (badge == null) {
      if (mounted) _c.forward();
      return;
    }
    unawaited(
      playSuccessFlood(context, origin: badge.center, landOn: _badge).then((_) {
        if (!mounted) return;
        setState(() => _landed = true);
        _c.forward(from: 0);
      }),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size * 1.5,
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        double seg(double a, double b, [Curve c = Curves.linear]) => c.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));
        return CustomPaint(
          painter: _CheckPainter(
            circle: _landed ? 1 : 0.6 + 0.4 * seg(0, 0.4, Motion.pop),
            circleAlpha: _landed ? 1 : seg(0, 0.15),
            check: _landed ? 1 : seg(0.3, 0.7, Motion.enter),
            ring: _landed ? seg(0, 0.7, Curves.easeOut) : seg(0.35, 1, Curves.easeOut),
            size: widget.size,
            color: widget.color,
            checkColor: widget.checkColor,
          ),
        );
      },
    ),
  );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.circle, required this.circleAlpha, required this.check, required this.ring, required this.size, required this.color, required this.checkColor});

  final double circle, circleAlpha, check, ring, size;
  final Color color, checkColor;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = size / 2;
    if (ring > 0 && ring < 1) {
      canvas.drawCircle(
        c,
        r * (1 + 0.45 * ring),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color.withValues(alpha: 0.35 * (1 - ring)),
      );
    }
    // The circle starts at 60 % and fades in: nothing appears from a point.
    canvas.drawCircle(c, r * circle, Paint()..color = color.withValues(alpha: color.a * circleAlpha));
    if (check <= 0) return;
    final metric = successCheckPath(c, r).computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * check),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.5, size * 0.035)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = checkColor,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter o) => o.circle != circle || o.circleAlpha != circleAlpha || o.check != check || o.ring != ring;
}

/// Runs [builder] with a 0..1 value that loops (reverse = ping-pong). Stops at [rest] when motion is reduced or
/// the ticker is muted (an inactive tab), so tests can settle.
class LoopAnimation extends StatefulWidget {
  const LoopAnimation({
    super.key,
    required this.duration,
    required this.builder,
    this.reverse = true,
    this.rest = 0.5,
    this.curve = Curves.easeInOut,
    this.child,
  });

  final Duration duration;
  final bool reverse;
  final double rest;
  final Curve curve;
  final Widget? child;
  final Widget Function(BuildContext context, double t, Widget? child) builder;

  @override
  State<LoopAnimation> createState() => _LoopAnimationState();
}

class _LoopAnimationState extends State<LoopAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
      _c.value = widget.rest;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: widget.reverse);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _c, child: widget.child, builder: (context, child) => widget.builder(context, widget.curve.transform(_c.value), child));
}

/// A horizontal glowing line sweeping up and down over [child] (AI scan, QR scan).
class ScanLine extends StatelessWidget {
  const ScanLine({super.key, required this.child, this.color = AppColors.detectBox, this.top = 0.08, this.bottom = 0.92});

  final Widget child;
  final Color color;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) => Stack(
      children: [
        Positioned.fill(child: child),
        // Positioned stays put; only a translate moves, so the sweep never re-lays-out the stack.
        Positioned(
          left: 12,
          right: 12,
          top: c.maxHeight * top,
          child: LoopAnimation(
            duration: const Duration(milliseconds: 1500),
            builder: (_, t, child) => Transform.translate(offset: Offset(0, c.maxHeight * (bottom - top) * t), child: child),
            child: IgnorePointer(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 1)],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Four static viewfinder corners for the QR scanner. The scan line already says "live", so they don't move.
class ScanFrame extends StatelessWidget {
  const ScanFrame({super.key, this.size = 240, this.color = AppColors.background, this.stroke = 4, this.corner = 36});

  final double size;
  final Color color;
  final double stroke;
  final double corner;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _CornersPainter(color: color, stroke: stroke, corner: corner),
  );
}

class _CornersPainter extends CustomPainter {
  _CornersPainter({required this.color, required this.stroke, required this.corner});

  final Color color;
  final double stroke;
  final double corner;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final w = s.width, h = s.height, k = corner, i = stroke / 2;
    for (final path in [
      Path()
        ..moveTo(i, k)
        ..lineTo(i, i)
        ..lineTo(k, i),
      Path()
        ..moveTo(w - k, i)
        ..lineTo(w - i, i)
        ..lineTo(w - i, k),
      Path()
        ..moveTo(w - i, h - k)
        ..lineTo(w - i, h - i)
        ..lineTo(w - k, h - i),
      Path()
        ..moveTo(k, h - i)
        ..lineTo(i, h - i)
        ..lineTo(i, h - k),
    ]) {
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_CornersPainter o) => o.color != color;
}

/// Three dots bouncing in turn: "the other side is typing".
class TypingDots extends StatelessWidget {
  const TypingDots({super.key, this.color = AppColors.inkMuted, this.dot = 7});

  final Color color;
  final double dot;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Sedang mengetik',
    child: LoopAnimation(
      duration: const Duration(milliseconds: 1000),
      reverse: false,
      curve: Curves.linear,
      rest: 0,
      builder: (_, t, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : dot * 0.6),
              child: Transform.translate(
                offset: Offset(0, -dot * 0.6 * math.max(0, math.sin((t - i * 0.15) * 2 * math.pi))),
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Gentle pulse for "waiting" states (a status dot, a pin, a "Menunggu..." pill). It breathes in opacity, not size,
/// so text inside never shimmers.
class Pulse extends StatelessWidget {
  const Pulse({super.key, required this.child, this.min = 0.55});

  final Widget child;

  /// Opacity at the dimmest point of the pulse.
  final double min;

  @override
  Widget build(BuildContext context) => LoopAnimation(
    duration: const Duration(milliseconds: 900),
    rest: 0,
    child: child,
    builder: (_, t, child) => Opacity(opacity: 1 - (1 - min) * t, child: child),
  );
}
