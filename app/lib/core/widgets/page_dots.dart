import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/app_colors.dart';

/// Page dots under a carousel (Welcome photos, onboarding): the current one stretches into a pill. [label] is what a
/// screen reader says instead of the dots, e.g. "Gambar 1 dari 3".
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index, required this.label});

  final int count;
  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: Motion.of(context, Motion.base),
                curve: Motion.move,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == index ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(color: i == index ? AppColors.primary : AppColors.border, borderRadius: BorderRadius.circular(4)),
              ),
          ],
        ),
      ),
    );
  }
}
