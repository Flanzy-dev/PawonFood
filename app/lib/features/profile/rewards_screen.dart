import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/rewards_repository.dart';
import '../../core/data/session_repository.dart';
import '../../core/models/reward.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/reward_card.dart';

/// Opens the detail of a reward. The monthly certificate is not bought with points: it has its own detail (D19b).
void openReward(BuildContext context, Reward reward) => context.push(reward.claimable ? '/reward/${reward.id}' : '/certificate');

/// Semua / Belanja / Antar / Sertifikat chips; the selection is shared by Profil and the full catalog.
class RewardFilterChips extends ConsumerWidget {
  const RewardFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(rewardFilterProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in RewardFilter.values) ...[
            AppChip(label: f.label, selected: f == selected, onTap: () => ref.read(rewardFilterProvider.notifier).state = f),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// D17b "Tukar poin": the full reward catalog (opened from "Lihat semua" on Profil).
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(sessionProvider.select((u) => u?.points ?? 0));
    final rewards = ref.watch(filteredRewardsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  RoundIconButton(icon: LucideIcons.arrowLeft, semanticLabel: 'Kembali', onTap: () => context.canPop() ? context.pop() : context.go('/profile')),
                  Expanded(child: Text('Tukar poin', textAlign: TextAlign.center, style: AppTypography.text(17, weight: 700))),
                  // Entry to D22b "Voucher saya" (the hi-fi has no slot for it yet).
                  RoundIconButton(icon: LucideIcons.ticket, semanticLabel: 'Voucher saya', onTap: () => context.push('/vouchers')),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Row(children: [
                    Expanded(child: Text('Saldo kamu', style: AppTypography.text(14, weight: 500, color: AppColors.inkMuted))),
                    PointsPill(points),
                  ]),
                  const SizedBox(height: 16),
                  const RewardFilterChips(),
                  const SizedBox(height: 16),
                  RewardGrid(rewards: rewards, points: points, onTap: (r) => openReward(context, r)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
