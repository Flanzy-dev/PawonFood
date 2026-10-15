import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../motion/entrance.dart';
import '../motion/motion.dart';
import '../motion/motion_widgets.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'top_bar.dart';

enum StatusKind { success, failure, clock }

/// The round mark on top of a result screen. Success draws its check, failure and clock pop in.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.kind, {super.key, this.size = 104});

  final StatusKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (kind == StatusKind.success) return CheckBurst(size: size, flood: true);
    final circle = kind == StatusKind.failure
        ? Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface, border: Border.all(color: AppColors.error, width: 3)),
            child: Icon(LucideIcons.x, size: size * 0.42, color: AppColors.error),
          )
        : Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceSand),
            child: Icon(LucideIcons.clock, size: size * 0.46, color: AppColors.accentInk),
          );
    return SizedBox.square(
      dimension: size * 1.5,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: Motion.reduced(context) ? 1 : 0.6, end: 1),
          duration: Motion.of(context, Motion.slow),
          curve: Motion.pop,
          builder: (_, s, child) => Opacity(opacity: ((s - 0.6) / 0.4).clamp(0.0, 1.0), child: Transform.scale(scale: s, child: child)),
          child: circle,
        ),
      ),
    );
  }
}

/// Result screen (payment done or failed, food picked up, reservation or QR expired): optional back button,
/// a [StatusBadge], title, body, extra content, and the actions pinned at the bottom. Content rises in after the
/// badge lands.
class StatusLayout extends StatelessWidget {
  const StatusLayout({
    super.key,
    required this.kind,
    required this.title,
    this.body,
    this.content = const [],
    this.actions = const [],
    this.back = false,
    this.fallback = '/',
  });

  final StatusKind kind;
  final String title;
  final String? body;
  final List<Widget> content;
  final List<Widget> actions;
  final bool back;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    // On success the text rises in while the green flood uncovers it, not hidden under it.
    final wait = kind == StatusKind.success && !Motion.reduced(context) ? Motion.floodGrow + Motion.floodHold : Duration.zero;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (back) TopBar(fallback: fallback) else const SizedBox(height: 52),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  children: [
                    StatusBadge(kind),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 180) + wait,
                      child: Column(children: [
                        Text(title, textAlign: TextAlign.center, style: AppTypography.display(27, height: 33)),
                        if (body != null) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(body!, textAlign: TextAlign.center, style: AppTypography.text(15, height: 22, color: AppColors.inkMuted)),
                          ),
                        ],
                      ]),
                    ),
                    for (final (i, c) in content.indexed)
                      FadeSlideIn(
                        index: i,
                        delay: const Duration(milliseconds: 260) + wait,
                        child: Padding(padding: const EdgeInsets.only(top: 20), child: c),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: [for (final (i, a) in actions.indexed) ...[if (i > 0) const SizedBox(height: 12), a]]),
            ),
          ],
        ),
      ),
    );
  }
}
