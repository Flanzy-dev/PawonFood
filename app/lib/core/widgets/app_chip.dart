import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Filter chip: filled green when selected, white with a border otherwise. 40 tall (min touch size).
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.selected, required this.onTap, this.height = 40, this.accentWhenUnselected = false});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double height;

  /// Terracotta outline (used for the "Tawar lagi" quick reply).
  final bool accentWhenUnselected;

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppColors.primary : (accentWhenUnselected ? AppColors.accent : AppColors.border);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: border, width: accentWhenUnselected && !selected ? 1.5 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTypography.text(14, weight: 600, color: selected ? AppColors.background : (accentWhenUnselected ? AppColors.accentInk : AppColors.ink)),
            ),
          ),
        ),
      ),
    );
  }
}
