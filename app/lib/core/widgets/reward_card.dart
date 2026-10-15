import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/reward.dart';
import '../motion/entrance.dart';
import '../motion/pressable.dart';
import '../services/rewards.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Fill and text colors of a reward tile by tone (`sand`, `tint`, `green`).
(Color fill, Color fg) rewardTileColors(String tone) => switch (tone) {
      'tint' => (AppColors.successTint, AppColors.primary),
      'green' => (AppColors.primary, AppColors.background),
      _ => (AppColors.surfaceSand, AppColors.accentInk),
    };

/// Lucide icon for a reward tile (hi-fi D17): basket for shopping, bike for delivery, award for the certificate.
IconData rewardIcon(Reward r) => switch (r.tile) {
      'Ojek' => LucideIcons.bike,
      'Hijau' => LucideIcons.award,
      _ => LucideIcons.shoppingBasket,
    };

/// Big colored tile with the reward icon: the card image and the detail hero.
class RewardTile extends StatelessWidget {
  const RewardTile(this.reward, {super.key, this.radius = 14, this.fontSize = 28, this.faded = false});

  final Reward reward;
  final double radius;
  final double fontSize;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final (fill, fg) = rewardTileColors(reward.tone);
    return Opacity(
      opacity: faded ? 0.5 : 1,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(radius)),
        child: Icon(rewardIcon(reward), size: fontSize * 1.2, color: fg, semanticLabel: reward.tile),
      ),
    );
  }
}

/// Square reward card (Card Voucher): tile, title and the cost. When the balance is too low the tile is
/// dimmed and the cost reads "Kurang N poin".
class RewardCard extends StatelessWidget {
  const RewardCard({super.key, required this.reward, required this.points, required this.onTap});

  final Reward reward;
  final int points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final short = pointsShort(reward, points);
    final costText = short > 0 ? 'Kurang $short poin' : (reward.claimable ? '${reward.cost} poin' : 'Bulanan');
    return Semantics(
      button: true,
      label: '${reward.title}, $costText',
      child: Pressable(
        scale: 0.97,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SizedBox.expand(child: RewardTile(reward, faded: short > 0))),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Text(reward.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.display(15, weight: 700, height: 20)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, right: 2, bottom: 2),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        costText,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.text(13, weight: short > 0 ? 700 : 500, height: 16, color: short > 0 ? AppColors.accentInk : AppColors.inkMuted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-column grid of square [RewardCard]s (12 px gaps), sized from the available width.
class RewardGrid extends StatelessWidget {
  const RewardGrid({super.key, required this.rewards, required this.points, required this.onTap});

  final List<Reward> rewards;
  final int points;
  final ValueChanged<Reward> onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final side = (c.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (i, r) in rewards.indexed)
                FadeSlideIn(key: ValueKey('${r.id}#$i'), index: i, child: SizedBox(width: side, height: side, child: RewardCard(reward: r, points: points, onTap: () => onTap(r)))),
            ],
          );
        },
      );
}
