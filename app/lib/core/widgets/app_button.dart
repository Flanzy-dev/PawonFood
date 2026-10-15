import 'package:flutter/material.dart';

import '../motion/entrance.dart';
import '../motion/pressable.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { primary, outline, accent, ghost, light, danger }

/// Buttons from DESIGN_SYSTEM.md: primary (filled green), outline (green), accent outline (terracotta),
/// ghost (sand), light (cream, for dark screens) and danger (filled red, for destructive confirmations). 16 radius, 52–56 tall.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.leading,
    this.height = 54,
    this.loading = false,
    this.expand = true,
    this.textSize = 16,
    this.iconOnly = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  /// Custom widget before the label (a brand logo); takes the place of [icon].
  final Widget? leading;
  final double height;
  final bool loading;
  final bool expand;
  final double textSize;

  /// Shows only [icon]; [label] stays as the accessible name.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (Color bg, Color fg, Color? border) = !enabled && !loading
        ? (AppColors.surfaceSand, AppColors.inkMuted, null)
        : switch (variant) {
            AppButtonVariant.primary => (AppColors.primary, AppColors.background, null),
            AppButtonVariant.outline => (AppColors.surface, AppColors.primary, AppColors.primary),
            AppButtonVariant.accent => (AppColors.surface, AppColors.accentInk, AppColors.accent),
            AppButtonVariant.ghost => (AppColors.surfaceSand, AppColors.ink, null),
            AppButtonVariant.light => (AppColors.background, AppColors.cameraBg, null),
            AppButtonVariant.danger => (AppColors.error, AppColors.surface, null),
          };
    final Widget content = loading
        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
        : iconOnly && icon != null
            ? Icon(icon, size: 22, color: fg)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 8)] else if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.text(textSize, weight: 700, color: fg))),
                ],
              );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Pressable(
        enabled: enabled,
        child: SizedBox(
          width: expand ? double.infinity : null,
          height: height,
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: border == null ? BorderSide.none : BorderSide(color: border, width: 1.5)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                // The label cross-fades to the spinner (and back) instead of snapping.
                child: Center(child: FadeSwitch(alignment: Alignment.center, child: KeyedSubtree(key: ValueKey(loading), child: content))),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
