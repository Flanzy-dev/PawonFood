import 'dart:async';

import 'package:flutter/material.dart';

/// Rebuilds every second with the time left until [until] (never negative) and calls [onDone] once at zero.
/// Used for the QRIS timer, the scanner's "Sisa 35 mnt" and the QR validity line.
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.until, required this.now, required this.builder, this.onDone});

  final DateTime until;

  /// Clock (the app's `clockProvider`), so tests and the demo agree on "now".
  final DateTime Function() now;
  final Widget Function(BuildContext context, Duration left) builder;
  final VoidCallback? onDone;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;
  var _done = false;

  Duration get _left {
    final d = widget.until.difference(widget.now());
    return d.isNegative ? Duration.zero : d;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_left == Duration.zero && !_done) {
        _done = true;
        _timer?.cancel();
        widget.onDone?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _left);
}

/// `14:59`
String formatMmSs(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// `35 mnt` (rounded up), or `1 j 5 mnt` past an hour.
String formatMinutesLeft(Duration d) {
  final m = (d.inSeconds / 60).ceil();
  return m >= 60 ? '${m ~/ 60} j ${m % 60} mnt' : '$m mnt';
}
