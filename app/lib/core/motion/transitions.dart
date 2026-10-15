import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'motion.dart';

/// How a route enters (DESIGN_SYSTEM.md → Motion).
enum PageMotion {
  /// Drill-in screens (detail, chat, rewards): fade in while sliding 6% from the right.
  push,

  /// Full-screen flows that feel like a task (camera, scanner, payment, ads): rise from below.
  rise,

  /// Auth screens and result screens: plain cross-fade.
  fade,
}

/// go_router page with the app's transition. Use it in `pageBuilder:` instead of `builder:`.
Page<void> motionPage(GoRouterState state, Widget child, {PageMotion motion = PageMotion.push}) => CustomTransitionPage<void>(
  key: state.pageKey,
  name: state.name,
  child: child,
  transitionDuration: Motion.slow,
  reverseTransitionDuration: Motion.base,
  transitionsBuilder: (context, animation, secondary, child) {
    if (Motion.reduced(context)) return child;
    final a = CurvedAnimation(parent: animation, curve: Motion.enter, reverseCurve: Motion.exit);
    // The page underneath drifts a little the other way, so the stack reads as layers.
    final under = CurvedAnimation(parent: secondary, curve: Motion.move);
    final Widget entering = switch (motion) {
      PageMotion.push => SlideTransition(
        position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a),
        child: FadeTransition(opacity: a, child: child),
      ),
      PageMotion.rise => SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(a),
        child: FadeTransition(opacity: a, child: child),
      ),
      PageMotion.fade => FadeTransition(opacity: a, child: child),
    };
    return SlideTransition(
      position: Tween(begin: Offset.zero, end: const Offset(-0.03, 0)).animate(under),
      child: entering,
    );
  },
);

/// Tab container for `StatefulShellRoute`: keeps every branch alive (like IndexedStack) and fades the new tab in
/// quickly when the index changes. Fade only: tabs are persistent, so nothing should "arrive".
class FadeIndexedStack extends StatefulWidget {
  const FadeIndexedStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.fast, value: 1);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Motion.enter);

  @override
  void didUpdateWidget(FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && !Motion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _t,
    child: IndexedStack(
      index: widget.index,
      children: [for (var i = 0; i < widget.children.length; i++) TickerMode(enabled: i == widget.index, child: widget.children[i])],
    ),
  );
}
