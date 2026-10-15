import 'package:flutter/material.dart';

import '../motion/entrance.dart';
import '../motion/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Every bottom sheet in the app goes through here, so they share the root navigator (the shell nav bar would
/// cover them otherwise), the drag handle and the sheet motion from [Motion.sheet].
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true, // sheets wrap their content; this only lifts the 9/16 screen-height cap so long content can scroll
  bool showDragHandle = true,
  bool useRootNavigator = true,
  Color? backgroundColor,
  Color? barrierColor,
  ShapeBorder? shape,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: useRootNavigator,
  isScrollControlled: isScrollControlled,
  showDragHandle: showDragHandle,
  backgroundColor: backgroundColor,
  barrierColor: barrierColor ?? AppColors.cameraBg.withValues(alpha: 0.45),
  shape: shape,
  sheetAnimationStyle: Motion.reduced(context) ? AnimationStyle.noAnimation : Motion.sheet,
  builder: builder,
);

/// Closes the sheet once. A double tap on a sheet button used to pop a second time, which closed the screen underneath too.
void closeSheet<T>(BuildContext context, [T? result]) {
  final route = ModalRoute.of(context);
  if (route != null && !route.isCurrent) return;
  Navigator.of(context).pop(result);
}

/// Asks before something that cannot be undone (logout, cancelling or rejecting an offer). Resolves true only when the
/// user confirms; dismissing the sheet or tapping "Batal" resolves false.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
  String cancelLabel = 'Batal',
}) async {
  final ok = await showAppSheet<bool>(
    context: context,
    builder: (ctx) => SheetBody(
      title: title,
      subtitle: message,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(label: confirmLabel, variant: destructive ? AppButtonVariant.danger : AppButtonVariant.primary, onPressed: () => closeSheet(ctx, true)),
          const SizedBox(height: 12),
          AppButton(label: cancelLabel, variant: AppButtonVariant.outline, onPressed: () => closeSheet(ctx, false)),
        ],
      ),
      children: const [],
    ),
  );
  return ok ?? false;
}

/// Standard sheet content: title, optional subtitle, then [children], padded and safe-area aware. The rows rise in
/// with a short stagger after the sheet lands.
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.title, this.subtitle, required this.children, this.footer, this.scroll = true});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Pinned under the content (a primary button).
  final Widget? footer;

  /// Lets long content scroll when it is taller than the screen (large text sizes).
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.titleL),
        if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: AppTypography.text(14, height: 20, color: AppColors.inkMuted))],
        const SizedBox(height: 12),
        for (var i = 0; i < children.length; i++) FadeSlideIn(index: i, delay: const Duration(milliseconds: 80), offset: 8, child: children[i]),
      ],
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (scroll) Flexible(child: SingleChildScrollView(child: body)) else body,
            if (footer != null) ...[const SizedBox(height: 16), footer!],
          ],
        ),
      ),
    );
  }
}
