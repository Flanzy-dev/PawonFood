import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Section heading with an optional trailing action ("Segera habis di sekitarmu" ... "Semua").
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.display(20, height: 26))),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text(actionLabel!, style: AppTypography.text(15, weight: 700, color: AppColors.primary)),
            ),
        ],
      );
}

/// Search field: white, rounded, search icon.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged, this.controller});

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: AppTypography.text(16),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.text(16, color: AppColors.inkMuted),
            prefixIcon: const Icon(LucideIcons.search, size: 22, color: AppColors.inkMuted),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      );
}

/// Centered illustration + title + body + actions (empty states and permission screens).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.body, this.image, this.actions = const [], this.icon});

  final String title;
  final String body;
  final String? image;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null) ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.asset(image!, width: 112, height: 112, fit: BoxFit.cover, excludeFromSemantics: true)),
            if (icon != null)
              Container(width: 88, height: 88, decoration: const BoxDecoration(color: AppColors.surfaceSand, shape: BoxShape.circle), child: Icon(icon, size: 40, color: AppColors.inkMuted)),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: AppTypography.display(20, weight: 800, height: 26)),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: AppTypography.bodyMuted),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              for (final (i, a) in actions.indexed) ...[if (i > 0) const SizedBox(height: 10), a],
            ],
          ],
        ),
      );
}

/// Muted banner with a shield (safety note on Pesan).
class SafetyBanner extends StatelessWidget {
  const SafetyBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surfaceSand, borderRadius: BorderRadius.circular(18)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.shield, size: 24, color: AppColors.accentInk),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: AppTypography.text(14, height: 21))),
          ],
        ),
      );
}

/// Shows an Indonesian snackbar message ("Segera hadir" etc.).
void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Primary action pinned above the bottom edge with a top border and soft shadow (sticky bottom bar).
class StickyBottomBar extends StatelessWidget {
  const StickyBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, -4))],
        ),
        child: child,
      );
}

/// An icon-only outline button (named by [secondaryLabel] for screen readers) + primary CTA pair used on the detail screen.
class ActionPair extends StatelessWidget {
  const ActionPair({super.key, required this.secondaryLabel, required this.onSecondary, required this.primaryLabel, required this.onPrimary, this.secondaryIcon});

  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData? secondaryIcon;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          AppButton(label: secondaryLabel, onPressed: onSecondary, variant: AppButtonVariant.outline, icon: secondaryIcon, iconOnly: secondaryIcon != null, expand: false),
          const SizedBox(width: 12),
          Expanded(child: AppButton(label: primaryLabel, onPressed: onPrimary)),
        ],
      );
}
