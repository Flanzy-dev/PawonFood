import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/rewards_repository.dart';
import '../../core/data/session_repository.dart';
import '../../core/models/reward.dart';
import '../../core/services/rewards.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/reward_card.dart';

/// D19 Detail hadiah, and D20 when the balance is too low: cost vs. balance, how to use, terms, and the claim button.
class RewardDetailScreen extends ConsumerWidget {
  const RewardDetailScreen({super.key, required this.rewardId});

  final String rewardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reward = ref.watch(rewardByIdProvider(rewardId));
    final points = ref.watch(sessionProvider.select((u) => u?.points ?? 0));
    if (reward == null) return const Scaffold(body: SizedBox.shrink());
    final short = pointsShort(reward, points);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  RoundIconButton(icon: LucideIcons.arrowLeft, semanticLabel: 'Kembali', onTap: () => context.canPop() ? context.pop() : context.go('/profile')),
                  Expanded(child: Text('Detail hadiah', textAlign: TextAlign.center, style: AppTypography.text(17, weight: 700))),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  SizedBox(height: 190, child: RewardTile(reward, radius: 20, fontSize: 40)),
                  const SizedBox(height: 18),
                  Text(reward.title, style: AppTypography.display(24, height: 30)),
                  const SizedBox(height: 10),
                  Row(children: [InfoTag(reward.category.label), const SizedBox(width: 8), InfoTag('Berlaku ${reward.validDays} hari')]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                    decoration: BoxDecoration(color: AppColors.surfaceSand, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        Expanded(child: _CostColumn(label: 'Biaya', value: '${reward.cost} poin')),
                        Expanded(child: _CostColumn(label: 'Poin kamu', value: '$points poin')),
                      ],
                    ),
                  ),
                  if (short > 0) ...[
                    const SizedBox(height: 14),
                    Text('Kurang $short poin lagi untuk klaim voucher ini', style: AppTypography.text(14, weight: 600, color: AppColors.accentInk)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: (points / reward.cost).clamp(0.0, 1.0), minHeight: 8, backgroundColor: AppColors.border, color: AppColors.primary),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('Cara pakai', style: AppTypography.display(18, height: 24)),
                  const SizedBox(height: 8),
                  for (final t in const ['1. Klaim voucher dan simpan kodenya.', '2. Tunjukkan kode ke mitra saat membayar.', '3. Potongan harga otomatis terhitung.'])
                    Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(t, style: AppTypography.text(14, height: 20, color: AppColors.inkMuted))),
                  const SizedBox(height: 20),
                  Text('Syarat dan ketentuan', style: AppTypography.display(18, height: 24)),
                  const SizedBox(height: 8),
                  for (final t in ['• Berlaku ${reward.validDays} hari sejak diklaim.', '• Satu kode untuk satu kali pakai.', '• Tidak dapat diuangkan atau dikembalikan jadi poin.'])
                    Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(t, style: AppTypography.text(14, height: 20, color: AppColors.inkMuted))),
                ],
              ),
            ),
            StickyBottomBar(
              child: AppButton(
                label: short > 0 ? 'Poin belum cukup' : 'Klaim voucher · ${reward.cost} poin',
                onPressed: short > 0 ? null : () => _confirm(context, ref, reward, points),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// D21: confirmation sheet before the points are deducted.
  Future<void> _confirm(BuildContext context, WidgetRef ref, Reward reward, int points) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      barrierColor: AppColors.cameraBg.withValues(alpha: 0.45),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _ConfirmSheet(reward: reward, points: points),
    );
    if (confirmed != true || !context.mounted) return;
    final result = ref.read(rewardsProvider.notifier).claim(reward.id);
    if (result.error != null) {
      showAppSnack(context, result.error!);
      return;
    }
    context.pushReplacement('/reward/claimed');
  }
}

class _CostColumn extends StatelessWidget {
  const _CostColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.text(13, color: AppColors.inkMuted)),
          const SizedBox(height: 2),
          Text(value, style: AppTypography.display(22, height: 28)),
        ],
      );
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.reward, required this.points});

  final Reward reward;
  final int points;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: Text(label, style: AppTypography.text(14, weight: bold ? 700 : 400, color: bold ? AppColors.ink : AppColors.inkMuted))),
            Text(value, style: AppTypography.text(14, weight: bold ? 700 : 600)),
          ]),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Klaim voucher ini?', style: AppTypography.display(22, height: 28)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  SizedBox(width: 56, height: 56, child: RewardTile(reward, radius: 12, fontSize: 14)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reward.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.display(16, weight: 700, height: 20)),
                        const SizedBox(height: 2),
                        Text('${reward.cost} poin · berlaku ${reward.validDays} hari', style: AppTypography.text(13, color: AppColors.inkMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            row('Poin kamu sekarang', '$points poin'),
            row('Biaya voucher', '-${reward.cost} poin'),
            row('Sisa poin', '${points - reward.cost} poin', bold: true),
            const SizedBox(height: 12),
            AppButton(label: 'Klaim sekarang', onPressed: () => Navigator.of(context).pop(true)),
            const SizedBox(height: 12),
            AppButton(label: 'Batal', variant: AppButtonVariant.outline, onPressed: () => Navigator.of(context).pop(false)),
          ],
        ),
      ),
    );
  }
}
