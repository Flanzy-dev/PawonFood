import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/session_repository.dart';
import '../../core/models/app_user.dart';
import '../../core/models/enums.dart';
import '../../core/data/rewards_repository.dart';
import '../../core/services/formatters.dart';
import '../../core/services/points.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/reward_card.dart';
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
    void soon() => showAppSnack(context, 'Segera hadir.');

    return SafeArea(
      bottom: false,
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
              Expanded(child: _ImpactTile(value: '${user.portionsShared}', label: 'porsi dibagikan')),
              const SizedBox(width: 8),
              Expanded(child: _ImpactTile(value: '${user.portionsSaved}', label: 'porsi kamu selamatkan')),
              const SizedBox(width: 8),
              Expanded(child: _ImpactTile(value: formatKg(user.kgSaved), label: 'batal jadi sampah')),
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
          Text('Poin didapat setiap kali makananmu diambil dan dinilai baik. Makanan gratis memberi poin lebih banyak.', style: AppTypography.text(14, height: 20, color: AppColors.inkMuted)),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _SettingRow(title: 'Riwayat berbagi dan mengambil', onTap: soon),
                _SettingRow(title: 'Titik ambil tersimpan', subtitle: user.pickupPoint, onTap: soon),
                _SettingRow(title: 'Keamanan pangan dan persetujuan', onTap: () => _showFoodSafety(context)),
                _SettingRow(title: 'Pengaturan', onTap: soon, last: true),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppButton(label: 'Keluar', variant: AppButtonVariant.accent, onPressed: () => ref.read(sessionProvider.notifier).logout()),
        ],
      ),
    );
  }

  void _showFoodSafety(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Keamanan pangan', style: AppTypography.titleL),
              const SizedBox(height: 12),
              for (final t in const [
                'PawonFood adalah perantara, bukan produsen makanan. Penyedia bertanggung jawab atas makanan yang dibagikan.',
                'Foto makanan hanya dari kamera langsung dan dicek AI sebelum tayang.',
                'Penyedia menjamin makanan masih layak makan. Penerima memeriksa kondisi makanan sebelum mengambil.',
                'Bayar tunai di tempat dengan kode ambil. Jangan transfer uang di luar aplikasi.',
                'Penyedia dengan ulasan buruk berulang akan diblokir otomatis.',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 2), child: Icon(LucideIcons.shieldCheck, size: 18, color: AppColors.primary)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t, style: AppTypography.body)),
                  ]),
                ),
            ],
          ),
        ),
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
    String caption(int i) => i < idx ? 'Tercapai' : (i == idx ? 'Sekarang' : (i == idx + 1 ? 'Berikutnya' : 'Puncak'));
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
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: tierProgress(user.points), minHeight: 8, backgroundColor: AppColors.onGreenTrack, color: AppColors.background),
          ),
          const SizedBox(height: 8),
          Text(next == null ? 'Kamu sudah di level tertinggi.' : '$remaining poin lagi untuk naik ke ${next.label}', style: AppTypography.text(14, weight: 500, color: AppColors.background)),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (i, t) in Tier.values.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 80,
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                    decoration: BoxDecoration(
                      color: i == idx ? AppColors.background : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: i == idx ? null : Border.all(color: AppColors.onGreenMuted.withValues(alpha: 0.7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(caption(i), style: AppTypography.text(12, weight: 600, color: i == idx ? AppColors.ink : AppColors.onGreenMuted)),
                        const SizedBox(height: 2),
                        Text(t.label, style: AppTypography.display(15, weight: 700, height: 19, color: i == idx ? AppColors.ink : AppColors.background)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactTile extends StatelessWidget {
  const _ImpactTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        height: 98,
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppTypography.display(26, height: 32))),
            const SizedBox(height: 4),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.text(13, height: 17, color: AppColors.inkMuted)),
          ],
        ),
      );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.title, required this.onTap, this.subtitle, this.last = false});

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.display(16, weight: 600, height: 22)),
                    if (subtitle != null) Text(subtitle!, style: AppTypography.text(13, height: 18, color: AppColors.inkMuted)),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 22, color: AppColors.inkMuted),
            ],
          ),
        ),
      );
}
