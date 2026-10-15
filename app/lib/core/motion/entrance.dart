import 'dart:async';

import 'package:flutter/material.dart';

import 'motion.dart';

/// Marks a screen whose content enters with a stagger. Items built later than [window] after the screen opened
/// (for example while scrolling, or after a filter change) appear without animation, so the list only
/// choreographs its first appearance.
class EntranceScope extends StatefulWidget {
  const EntranceScope({super.key, required this.child, this.window = const Duration(milliseconds: 600)});

  final Widget child;
  final Duration window;

  static _EntranceScopeState? _of(BuildContext context) => context.findAncestorStateOfType<_EntranceScopeState>();

  @override
  State<EntranceScope> createState() => _EntranceScopeState();
}

class _EntranceScopeState extends State<EntranceScope> {
  final _opened = Stopwatch()..start();

  bool get open => _opened.elapsed < widget.window;

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Fades the child in while it rises [offset] px. [index] staggers siblings by [Motion.stagger] (capped at 8, so
/// long lists never wait). Inside an [EntranceScope] it only plays during the scope's opening window.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.delay = Duration.zero, this.offset = 12, this.duration = Motion.slow});

  final Widget child;
  final int index;
  final Duration delay;
  final double offset;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Motion.enter);
  bool _started = false;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final scope = EntranceScope._of(context);
    if (Motion.reduced(context) || (scope != null && !scope.open)) {
      _c.value = 1;
      return;
    }
    final wait = widget.delay + Motion.stagger * widget.index.clamp(0, 8);
    if (wait == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(wait, _c.forward);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  // FadeTransition updates its layer's opacity without rebuilding; only the cheap translate is rebuilt per frame.
  Widget build(BuildContext context) => FadeTransition(
    opacity: _t,
    child: AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (_, child) => _t.value == 1 ? child! : Transform.translate(offset: Offset(0, widget.offset * (1 - _t.value)), child: child),
    ),
  );
}

/// Swaps [child] with a short cross-fade + slight rise whenever its key changes (status text, prices, states).
class FadeSwitch extends StatelessWidget {
  const FadeSwitch({super.key, required this.child, this.duration = Motion.base, this.alignment = Alignment.topLeft});

  final Widget child;
  final Duration duration;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.of(context, duration),
    switchInCurve: Motion.enter,
    switchOutCurve: Motion.exit,
    layoutBuilder: (current, previous) => Stack(alignment: alignment, children: [...previous, ?current]),
    transitionBuilder: (child, a) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
        child: child,
      ),
    ),
    child: child,
  );
}
