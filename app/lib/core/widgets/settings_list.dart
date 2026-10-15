import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../motion/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// White rounded group of [SettingsRow]s with an optional small heading above (D18, D18d, D18f, D18k).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(title!, style: AppTypography.text(14, weight: 600, color: AppColors.inkMuted))),
          Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (final (i, c) in children.indexed) ...[
                if (i > 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Divider(height: 1, thickness: 1, color: AppColors.border)),
                c,
              ],
            ]),
          ),
        ],
      );
}

/// One row: title, optional subtitle, and a chevron, a switch or nothing on the right. [destructive] is red.
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.title, this.subtitle, this.onTap, this.chevron = true, this.toggle, this.onToggle, this.destructive = false});

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool chevron;

  /// Switch value; when set, the row shows a switch instead of the chevron.
  final bool? toggle;
  final ValueChanged<bool>? onToggle;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final hasToggle = toggle != null;
    final tap = hasToggle ? () => onToggle?.call(!toggle!) : onTap;
    return Semantics(
      button: !hasToggle,
      toggled: toggle,
      label: [title, ?subtitle].join(', '),
      // excludeSemantics drops the InkWell's own tap action, so the row has to expose it here.
      onTap: tap,
      excludeSemantics: true,
      child: InkWell(
        onTap: tap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.display(16, weight: 600, height: 22, color: destructive ? AppColors.error : AppColors.ink)),
                    if (subtitle != null) Text(subtitle!, style: AppTypography.text(13, height: 18, color: AppColors.inkMuted)),
                  ],
                ),
              ),
              if (hasToggle)
                Switch(
                  value: toggle!,
                  onChanged: onToggle,
                  activeTrackColor: AppColors.primary,
                  activeThumbColor: AppColors.surface,
                  inactiveTrackColor: AppColors.surfaceSand,
                  inactiveThumbColor: AppColors.surface,
                  trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.borderStrong),
                )
              else if (chevron)
                const Icon(LucideIcons.chevronRight, size: 22, color: AppColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

/// FAQ-style row that opens to show [body]; the chevron turns as it opens (D18k).
class ExpandableRow extends StatefulWidget {
  const ExpandableRow({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  State<ExpandableRow> createState() => _ExpandableRowState();
}

class _ExpandableRowState extends State<ExpandableRow> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, Motion.base);
    return Semantics(
      button: true,
      expanded: _open,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(widget.title, style: AppTypography.display(16, weight: 600, height: 22))),
                AnimatedRotation(turns: _open ? 0.25 : 0, duration: d, curve: Motion.move, child: const Icon(LucideIcons.chevronRight, size: 22, color: AppColors.ink)),
              ]),
              AnimatedSize(
                duration: d,
                curve: Motion.move,
                alignment: Alignment.topCenter,
                child: _open
                    ? Padding(padding: const EdgeInsets.only(top: 8), child: Text(widget.body, style: AppTypography.text(14, height: 21, color: AppColors.inkMuted)))
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
