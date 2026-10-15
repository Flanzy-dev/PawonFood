import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/recipe.dart';
import '../../core/motion/pressable.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/info_box.dart';
import '../../core/widgets/pills.dart';

/// "25 mnt · 3 porsi"
String recipeMeta(Recipe r) => '${r.minutes} mnt · ${r.servings} porsi';

/// Caption on the "Ide resep" card. A recipe the seller chose in the share form counts as verified by them; without
/// one the buyer still gets an automatic suggestion, labelled as not verified.
const recipeVerifiedCaption = 'Diverifikasi pemberi';
const recipeUnverifiedCaption = 'Belum diverifikasi pemberi';

/// Full recipe: ingredients and steps. A recipe is only an idea, never a claim about the food.
Future<void> showRecipeSheet(BuildContext context, Recipe r, {required bool verified}) => showAppSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SheetBody(
        title: r.title,
        subtitle: recipeMeta(r),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Icon(verified ? LucideIcons.badgeCheck : LucideIcons.info, size: 18, color: verified ? AppColors.primary : AppColors.inkMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  verified ? 'Dicek dan dipilih oleh pemberi' : 'Saran otomatis, belum dicek pemberi',
                  style: AppTypography.text(13, weight: 600, color: verified ? AppColors.primary : AppColors.inkMuted),
                ),
              ),
            ]),
          ),
          if (r.fromAi || r.healthTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Wrap(spacing: 8, runSpacing: 6, children: [
                if (r.fromAi) const InfoTag('Ide AI'),
                for (final t in r.healthTags) InfoTag(t.label),
              ]),
            ),
          Text('Bahan', style: AppTypography.titleM),
          const SizedBox(height: 8),
          for (final line in r.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 8), child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))),
                const SizedBox(width: 10),
                Expanded(child: Text(line, style: AppTypography.body)),
              ]),
            ),
          const SizedBox(height: 14),
          Text('Cara masak', style: AppTypography.titleM),
          const SizedBox(height: 8),
          for (final (i, step) in r.steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.successTint, shape: BoxShape.circle),
                  child: Text('${i + 1}', style: AppTypography.text(13, weight: 700, color: AppColors.primary)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(step, style: AppTypography.body))),
              ]),
            ),
          const SizedBox(height: 8),
          const InfoBox('Resep hanya ide. Cek kondisi bahan sebelum dimasak.', icon: LucideIcons.chefHat),
        ],
      ),
    );

/// "Ide resep" card on the listing detail: tap opens [showRecipeSheet].
class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.recipe, required this.verified});

  final Recipe recipe;

  /// The seller attached this recipe (verified) rather than the app suggesting it.
  final bool verified;

  String get _caption => verified ? recipeVerifiedCaption : recipeUnverifiedCaption;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Ide resep: ${recipe.title}, ${recipeMeta(recipe)}. $_caption. Ketuk untuk melihat resep.',
        excludeSemantics: true,
        child: Pressable(
          scale: 0.98,
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showRecipeSheet(context, recipe, verified: verified),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.successTint, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(LucideIcons.chefHat, size: 22, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(recipe.title, style: AppTypography.text(16, weight: 700, height: 22)),
                      const SizedBox(height: 2),
                      Text('${recipeMeta(recipe)} · $_caption', style: AppTypography.text(13, height: 18, color: AppColors.inkMuted)),
                    ]),
                  ),
                  const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.inkMuted),
                ]),
              ),
            ),
          ),
        ),
      );
}
