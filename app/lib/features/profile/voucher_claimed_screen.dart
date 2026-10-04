import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/rewards_repository.dart';
import '../../core/data/session_repository.dart';
import '../../core/services/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/reward_card.dart';

/// D22 Voucher berhasil diklaim: the code to show the partner, the validity and the remaining points.
class VoucherClaimedScreen extends ConsumerWidget {
  const VoucherClaimedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voucher = ref.watch(rewardsProvider);
    final points = ref.watch(sessionProvider.select((u) => u?.points ?? 0));
    return Scaffold(
      body: SafeArea(
        child: voucher == null
            ? Center(child: AppButton(label: 'Kembali ke Profil', expand: false, onPressed: () => context.go('/profile')))
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 48),
                            Container(width: 96, height: 96, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(LucideIcons.check, size: 48, color: AppColors.background)),
                            const SizedBox(height: 24),
                            Text('Voucher berhasil diklaim!', textAlign: TextAlign.center, style: AppTypography.display(26, height: 32)),
                            const SizedBox(height: 10),
                            Text('Tunjukkan kode ini ke mitra saat membayar.', textAlign: TextAlign.center, style: AppTypography.bodyMuted),
                            const SizedBox(height: 28),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 80, width: double.infinity, child: RewardTile(voucher.reward, radius: 14, fontSize: 28)),
                                  const SizedBox(height: 14),
                                  Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(voucher.reward.title, style: AppTypography.display(17, weight: 700, height: 22))),
                                  const Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4), child: Divider(height: 1, color: AppColors.border)),
                                  Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('Kode voucher', style: AppTypography.text(13, color: AppColors.inkMuted))),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                                    child: SelectableText(voucher.code, style: AppTypography.display(26).copyWith(letterSpacing: 1.5)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Berlaku sampai ${formatLongDate(voucher.validUntil)} · sisa poin kamu $points', textAlign: TextAlign.center, style: AppTypography.text(13, height: 18, color: AppColors.inkMuted)),
                          ],
                        ),
                      ),
                    ),
                    AppButton(
                      label: 'Salin kode',
                      variant: AppButtonVariant.outline,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: voucher.code));
                        if (context.mounted) showAppSnack(context, 'Kode disalin.');
                      },
                    ),
                    const SizedBox(height: 12),
                    AppButton(label: 'Kembali ke Profil', onPressed: () => context.go('/profile')),
                  ],
                ),
              ),
      ),
    );
  }
}
