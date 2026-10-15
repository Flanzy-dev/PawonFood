import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'navigation_widgets.dart';

/// Back button (white circle), centred title and an optional action (DESIGN_SYSTEM.md → Top bar).
/// Back pops the route, or goes to [fallback] when there is nothing to pop.
class TopBar extends StatelessWidget {
  const TopBar({super.key, this.title, this.fallback = '/', this.onBack, this.action, this.close = false, this.dark = false, this.onTitleLongPress});

  final String? title;
  final String fallback;
  final VoidCallback? onBack;
  final Widget? action;

  /// Shows an X instead of the arrow (full-screen tasks such as the scanner).
  final bool close;
  final bool dark;

  /// Hidden demo switch (like the camera's AI mode).
  final VoidCallback? onTitleLongPress;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          RoundIconButton(
            icon: close ? LucideIcons.x : LucideIcons.arrowLeft,
            semanticLabel: close ? 'Tutup' : 'Kembali',
            fill: dark ? AppColors.cameraControl : AppColors.surface,
            borderColor: dark ? null : AppColors.border,
            iconColor: dark ? AppColors.background : AppColors.ink,
            onTap: onBack ?? () => context.canPop() ? context.pop() : context.go(fallback),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: onTitleLongPress,
              child: Text(title ?? '', textAlign: TextAlign.center, style: AppTypography.text(17, weight: 700, color: dark ? AppColors.background : AppColors.ink)),
            ),
          ),
          SizedBox(width: 44, child: action),
        ]),
      );
}
