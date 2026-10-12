import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import 'motion.dart';

/// Press feedback: the child shrinks to [scale] while a finger is down and springs back on release.
/// Wraps buttons, chips and cards so a tap feels physical. Does nothing when [enabled] is false.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true, this.scale = 0.97});

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  Offset _start = Offset.zero;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || Motion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (e) {
        _start = e.position;
        _set(true);
      },
      // A finger that travels past the touch slop is scrolling, not pressing: let go of the shrink.
      onPointerMove: (e) {
        if (_down && (e.position - _start).distance > kTouchSlop) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        // Quick to press in, a touch slower to release, so the release reads as the "answer".
        duration: _down ? Motion.press : Motion.fast,
        curve: _down ? Curves.easeOut : Motion.enter,
        child: widget.child,
      ),
    );
  }
}
