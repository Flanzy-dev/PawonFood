import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../motion/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'top_bar.dart';

/// Section heading with an optional trailing action ("Pilihan untukmu di sekitar" ... "Semua").
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

/// Search field: white, rounded, search icon, and an ✕ at the right end while there is text ("Hapus pencarian").
/// Pass [value] to let the screen clear or set the text from outside; typing keeps working through [onChanged].
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.value,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
    this.heroTag,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final String? value;

  /// Keyboard "search" action.
  final ValueChanged<String>? onSubmitted;

  /// With [readOnly] the field is a button that opens a search page (Beranda); the ✕ still clears the text.
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;

  /// Shares the field between two routes: it flies from one position to the other (off when motion is reduced).
  final Object? heroTag;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _own = TextEditingController(text: widget.value);
  TextEditingController get _c => widget.controller ?? _own;

  @override
  void didUpdateWidget(SearchField old) {
    super.didUpdateWidget(old);
    final v = widget.value;
    if (v != null && v != _c.text) _c.text = v;
  }

  void _clear() {
    _c.clear();
    widget.onChanged('');
  }

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = SizedBox(
      // 52 at normal text size; taller when the system font is larger, so the typed text isn't clipped.
      height: math.max(52, 28 + 24 * textScaleOf(context)),
      child: TextField(
        controller: _c,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        onTap: widget.onTap,
        readOnly: widget.readOnly,
        // A button-like field must not keep a caret when the search page closes again.
        canRequestFocus: !widget.readOnly,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        style: AppTypography.text(16),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppTypography.text(16, color: AppColors.inkMuted),
          prefixIcon: const Icon(LucideIcons.search, size: 22, color: AppColors.inkMuted),
          // Rebuilt by the controller, so the ✕ shows as soon as there is something to clear.
          suffixIcon: ListenableBuilder(
            listenable: _c,
            builder: (_, _) => _c.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(icon: const Icon(LucideIcons.x, size: 20, color: AppColors.inkMuted), tooltip: 'Hapus pencarian', onPressed: _clear),
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        ),
      ),
    );
    final tag = widget.heroTag;
    if (tag == null) return field;
    return HeroMode(
      enabled: !Motion.reduced(context),
      child: Hero(
        tag: tag,
        // A look-alike instead of a second live TextField, so the flight never fights over focus or the controller.
        flightShuttleBuilder: (_, _, _, _, _) => _SearchShuttle(text: _c.text, hint: widget.hint),
        child: field,
      ),
    );
  }
}

/// The search field as drawn during a [Hero] flight: same look, no editing.
class _SearchShuttle extends StatelessWidget {
  const _SearchShuttle({required this.text, required this.hint});

  final String text;
  final String hint;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: DecoratedBox(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(LucideIcons.search, size: 22, color: AppColors.inkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text.isEmpty ? hint : text,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: AppTypography.text(16, color: text.isEmpty ? AppColors.inkMuted : AppColors.ink),
            ),
          ),
        ],
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
void showAppSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: actionLabel == null || onAction == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction),
    ));
}

/// Primary action pinned above the bottom edge with a top border and soft shadow (sticky bottom bar).
/// [compact] drops the padding to 8 above and 8 below (plus the system gesture inset), so the action sits close to the
/// gesture area but not against the screen edge.
class StickyBottomBar extends StatelessWidget {
  const StickyBottomBar({super.key, required this.child, this.compact = false});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(16, compact ? 8 : 16, 16, (compact ? 8 : 16) + MediaQuery.paddingOf(context).bottom),
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

/// Shown when a screen's data is gone (a deleted chat, a reservation that no longer exists): a way back instead of a bare
/// message on a blank page.
class NotFoundScaffold extends StatelessWidget {
  const NotFoundScaffold({super.key, this.title = 'Reservasi tidak ditemukan', this.fallback = '/messages', this.actionLabel = 'Ke Pesan'});

  final String title;
  final String fallback;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              TopBar(fallback: fallback),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      icon: LucideIcons.searchX,
                      title: title,
                      body: 'Mungkin sudah dihapus atau tidak tersedia lagi.',
                      actions: [AppButton(label: actionLabel, onPressed: () => context.go(fallback))],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
