import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../motion/pressable.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// One tappable line of a search list: icon, text, an optional second line and an optional ✕ ("Hapus dari riwayat").
/// Shared by the Beranda search page and the pickup-point search on the map picker.
class TermRow extends StatelessWidget {
  const TermRow({super.key, required this.icon, required this.label, required this.onTap, this.subtitle, this.onRemove});

  final IconData icon;
  final String label;

  /// Muted second line, e.g. the address of a place.
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: subtitle == null ? label : '$label, $subtitle',
    excludeSemantics: true,
    onTap: onTap,
    customSemanticsActions: onRemove == null ? null : {const CustomSemanticsAction(label: 'Hapus dari riwayat'): onRemove!},
    child: Pressable(
      scale: 0.98,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.inkMuted),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: subtitle == null ? 0 : 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.text(16)),
                      if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.text(13, color: AppColors.inkMuted)),
                    ],
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18, color: AppColors.inkMuted),
                  tooltip: 'Hapus dari riwayat',
                  onPressed: onRemove,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
