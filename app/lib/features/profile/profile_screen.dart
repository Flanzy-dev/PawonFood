import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/pickup_points_repository.dart';
import '../../core/data/rewards_repository.dart';
import '../../core/data/session_repository.dart';
import '../../core/models/app_user.dart';
import '../../core/models/enums.dart';
import '../../core/motion/entrance.dart';
import '../../core/motion/motion.dart';
import '../../core/motion/motion_widgets.dart';
import '../../core/services/formatters.dart';
import '../../core/services/points.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/logout_confirm.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/reward_card.dart';
import '../../core/widgets/settings_list.dart';
import 'rewards_screen.dart';

/// D17 + D18 Profil: level and progress, impact, redeemable rewards and the settings links.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    if (user == null) return const SizedBox.shrink();
    final rewards = ref.watch(filteredRewardsProvider);
    final area = user.pickupPoint.contains(',') ? user.pickupPoint.split(',').last.trim() : user.pickupPoint;
    final primaryPoint = ref.watch(pickupPointsProvider.select((ps) => ps.where((p) => p.primary).firstOrNull?.name ?? user.pickupPoint));

    return SafeArea(
      bottom: false,
      child: EntranceScope(
        child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, navContentInset(context)),
        children: [
          Row(
            children: [
              Container(width: 64, height: 64, decoration: const BoxDecoration(color: AppColors.successTint, shape: BoxShape.circle), child: const Icon(LucideIcons.user, size: 30, color: AppColors.primary)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.display(22, height: 28)),
                    Text('${user.roleLabel} · $area, Sleman', maxLines: 2, style: AppTypography.text(13, height: 18, color: AppColors.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LevelCard(user: user),
          const SizedBox(height: 24),
          Text('Dampak kamu', style: AppTypography.display(20, height: 26)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: FadeSlideIn(index: 0, child: _ImpactTile(value: user.portionsShared, label: 'porsi dibagikan'))),
              const SizedBox(width: 8),
              Expanded(child: FadeSlideIn(index: 1, child: _ImpactTile(value: user.portionsSaved, label: 'porsi kamu selamatkan'))),
              const SizedBox(width: 8),
              Expanded(child: FadeSlideIn(index: 2, child: _ImpactTile(value: user.kgSaved, label: 'batal jadi sampah', format: (v) => formatKg(v.toDouble())))),
            ],
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: Text('Tukar poin', style: AppTypography.display(20, height: 26))),
            TextButton(
              onPressed: () => context.push('/rewards'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text('Lihat semua', style: AppTypography.text(15, weight: 700, color: AppColors.primary)),
            ),
          ]),
          const SizedBox(height: 4),
          const RewardFilterChips(),
          const SizedBox(height: 12),
          RewardGrid(rewards: rewards.take(2).toList(), points: user.points, onTap: (r) => openReward(context, r)),
          const SizedBox(height: 16),
          Text(
            'Penyedia dapat poin dampak saat QR pengambilan dipindai. Penerima dapat poin saat mengambil dan memberi ulasan. Makanan gratis memberi poin lebih banyak.',
            style: AppTypography.text(14, height: 20, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 20),
          SettingsGroup(children: [
            SettingsRow(title: 'Riwayat berbagi dan mengambil', onTap: () => context.push('/profile/history')),
            SettingsRow(title: 'Titik ambil tersimpan', subtitle: primaryPoint, onTap: () => context.push('/profile/points')),
            SettingsRow(title: 'Keamanan pangan dan persetujuan', onTap: () => _showFoodSafety(context)),
            SettingsRow(title: 'Pengaturan', onTap: () => context.push('/settings')),
          ]),
          const SizedBox(height: 24),
          AppButton(label: 'Keluar', variant: AppButtonVariant.accent, onPressed: () => confirmLogout(context, ref)),
        ],
      ),
      ),
    );
  }

  /// D18e Keamanan pangan.
  void _showFoodSafety(BuildContext context) {
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SheetBody(
        title: 'Keamanan pangan',
        children: [
          for (final t in const [
            'PawonFood adalah perantara, bukan produsen makanan. Penyedia bertanggung jawab atas makanan yang dibagikan.',
            'Foto makanan hanya dari kamera langsung dan dicek AI sebelum tayang.',
            'Penyedia menjamin makanan masih layak makan. Penerima memeriksa kondisi makanan sebelum mengambil.',
            'Ambil dengan memindai QR di HP penyedia, lalu bayar tunai di tempat atau lewat QRIS di aplikasi. Jangan transfer uang di luar aplikasi.',
            'Penyedia dengan ulasan buruk berulang akan di-suspend dulu, lalu diblokir jika berlanjut.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 2), child: Icon(LucideIcons.shieldCheck, size: 18, color: AppColors.primary)),
                const SizedBox(width: 10),
                Expanded(child: Text(t, style: AppTypography.body)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final tier = user.tier;
    final next = nextTier(tier);
    final remaining = pointsToNext(user.points);
    final idx = Tier.values.indexOf(tier);
    String caption(int i) => i < idx ? 'Tercapai' : (i == idx ? 'Sekarang' : (i == idx + 1 ? 'Berikutnya' : 'Top Impact'));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Level kamu', style: AppTypography.text(13, color: AppColors.onGreenMuted)),
                    Text(tier.label, style: AppTypography.display(32, height: 38, color: AppColors.background)),
                  ],
                ),
              ),
              PointsPill(user.points),
            ],
          ),
          const SizedBox(height: 14),
          // The bar fills to the current progress each time the tab opens.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: tierProgress(user.points)),
            duration: Motion.of(context, const Duration(milliseconds: 900)),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: AppColors.onGreenTrack, color: AppColors.background),
            ),
          ),
          const SizedBox(height: 8),
          Text(next == null ? 'Kamu sudah di level tertinggi.' : '$remaining poin lagi untuk naik ke ${next.label}', style: AppTypography.text(14, weight: 500, color: AppColors.background)),
          const SizedBox(height: 16),
          _TierStepper(current: idx, caption: caption),
        ],
      ),
    );
  }
}

/// Tier stepper (D17): a line through one dot per tier, with the caption and the tier name centred under each dot.
class _TierStepper extends StatelessWidget {
  const _TierStepper({required this.current, required this.caption});

  final int current;
  final String Function(int i) caption;

  static const _dot = 24.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, box) {
          final col = box.maxWidth / Tier.values.length;
          return Stack(
            children: [
              Positioned(
                left: col / 2,
                right: col / 2,
                top: _dot / 2 - 1,
                child: Container(height: 2, color: AppColors.onGreenTrack),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, t) in Tier.values.indexed)
                    Expanded(
                      child: Semantics(
                        label: '${caption(i)}: ${t.label}',
                        excludeSemantics: true,
                        child: Column(children: [
                          _TierDot(reached: i < current, current: i == current),
                          const SizedBox(height: 8),
                          Text(caption(i), textAlign: TextAlign.center, style: AppTypography.text(12, weight: 600, color: AppColors.onGreenMuted)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(t.label, maxLines: 1, style: AppTypography.display(14, weight: 700, height: 18, color: AppColors.background)),
                          ),
                        ]),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      );
}

class _TierDot extends StatelessWidget {
  const _TierDot({required this.reached, required this.current});

  final bool reached;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final filled = reached || current;
    return Container(
      width: _TierStepper._dot,
      height: _TierStepper._dot,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.background : AppColors.primary,
        border: filled ? null : Border.all(color: AppColors.onGreenMuted, width: 2),
      ),
      child: current
          ? Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary))
          : (reached ? const Icon(LucideIcons.check, size: 14, color: AppColors.primary) : null),
    );
  }
}

class _ImpactTile extends StatelessWidget {
  const _ImpactTile({required this.value, required this.label, this.format});

  final num value;
  final String label;
  final String Function(num v)? format;

  @override
  Widget build(BuildContext context) => Container(
        // 98 at normal text size; the tiles in a row stay equal because the height follows the font scale, not the content.
        height: math.max(98, 66 * textScaleOf(context) + 30),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: AnimatedCount(value: value, from: 0, format: format, style: AppTypography.display(26, height: 32))),
            const SizedBox(height: 4),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.text(13, height: 17, color: AppColors.inkMuted)),
          ],
        ),
      );
}
