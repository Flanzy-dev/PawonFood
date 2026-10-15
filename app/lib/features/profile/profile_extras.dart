import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/history_repository.dart';
import '../../core/data/pickup_points_repository.dart';
import '../../core/data/rewards_repository.dart';
import '../../core/data/session_repository.dart';
import '../../core/models/claimed_voucher.dart';
import '../../core/motion/entrance.dart';
import '../../core/motion/motion.dart';
import '../../core/services/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/listing_photo.dart';
import '../../core/widgets/option_row.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/reward_card.dart';
import '../../core/widgets/top_bar.dart';

/// D18b Riwayat: what the user took and what they shared.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  var _taking = true;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    final entries = ref.watch(historyProvider(_taking));
    final summary = _taking ? 'Bulan ini · ${user?.portionsSaved ?? 0} porsi kamu selamatkan' : 'Bulan ini · ${user?.portionsShared ?? 0} porsi kamu bagikan';
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const TopBar(title: 'Riwayat', fallback: '/profile'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SegmentedControl(options: const ['Saya mengambil', 'Saya berbagi'], selected: _taking ? 0 : 1, onChanged: (i) => setState(() => _taking = i == 0)),
          ),
          Expanded(
            // A new EntranceScope per tab, so switching tabs replays the stagger.
            child: EntranceScope(
              key: ValueKey(_taking),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Text(summary, style: AppTypography.text(14, color: AppColors.inkMuted)),
                  const SizedBox(height: 10),
                  if (entries.isEmpty)
                    const Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(icon: LucideIcons.history, title: 'Belum ada riwayat', body: 'Makanan yang kamu ambil atau bagikan muncul di sini.'))
                  else
                    for (final (i, e) in entries.indexed) FadeSlideIn(index: i, child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _HistoryCard(entry: e))),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final date = '${e.at.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'][e.at.month - 1]}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        ListingPhoto(e.listing, width: 68, height: 68, radius: 12),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.listing.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.display(16, weight: 700, height: 21)),
            Text('${e.counterpart} · $date', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.text(13, color: AppColors.inkMuted)),
            const SizedBox(height: 6),
            e.done
                ? const Pill('Selesai', fill: AppColors.successTint, color: AppColors.primary, height: 24, weight: 700)
                : const Pill('Kedaluwarsa', color: AppColors.accentInk, height: 24, weight: 700),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (e.points != null) Text('+${e.points} poin', style: AppTypography.text(13, weight: 700, color: AppColors.primary)),
          const SizedBox(height: 2),
          e.amount == 0
              ? Text('Gratis', style: AppTypography.display(17, weight: 800, color: AppColors.primary))
              : Text(formatRupiah(e.amount), style: AppTypography.display(17, weight: 800)),
        ]),
      ]),
    );
  }
}

/// D18c Titik ambil tersimpan: the "Utama" point is used for new listings; tap a point to make it the default or
/// remove it; add new ones on the map.
class PickupPointsScreen extends ConsumerWidget {
  const PickupPointsScreen({super.key});

  void _actions(BuildContext context, WidgetRef ref, PickupPoint p) => showAppSheet<void>(
        context: context,
        builder: (ctx) => SheetBody(
          title: p.name,
          subtitle: p.address,
          children: [
            if (!p.primary)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppButton(
                  label: 'Jadikan utama',
                  onPressed: () {
                    ref.read(pickupPointsProvider.notifier).makePrimary(p.id);
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            AppButton(
              label: 'Hapus titik ini',
              variant: AppButtonVariant.accent,
              onPressed: ref.read(pickupPointsProvider).length < 2
                  ? null
                  : () {
                      ref.read(pickupPointsProvider.notifier).remove(p.id);
                      Navigator.of(ctx).pop();
                    },
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pickupPointsProvider);
    return Scaffold(
      body: SafeArea(
        child: EntranceScope(
          child: Column(children: [
            const TopBar(title: 'Titik ambil tersimpan', fallback: '/profile'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Text('Dipakai otomatis saat kamu membagikan makanan.', style: AppTypography.text(14, color: AppColors.inkMuted)),
                  const SizedBox(height: 12),
                  for (final (i, p) in points.indexed)
                    FadeSlideIn(
                      key: ValueKey(p.id),
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OptionRow(
                          title: p.name,
                          subtitle: p.address,
                          lead: OptionLead.badge,
                          tag: p.primary ? 'Utama' : null,
                          selected: p.primary,
                          onTap: () => _actions(context, ref, p),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Tambah titik ambil',
                    icon: LucideIcons.plus,
                    variant: AppButtonVariant.outline,
                    onPressed: () async {
                      final picked = await context.push<PickupPoint>('/share/pick-point');
                      // Points added from here are always saved.
                      if (picked != null && !ref.read(pickupPointsProvider).any((p) => p.id == picked.id)) ref.read(pickupPointsProvider.notifier).save(picked);
                    },
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// How many portions a month earn the certificate, and the minimum rating. Assumptions until the PRD open
/// question is decided (see app/README.md).
const certificatePortions = 30;
const certificateRating = '4,5';

/// D19b Detail sertifikat: the monthly "Sertifikat Resto Peduli Lingkungan" is not bought with points; it is issued
/// automatically to providers who share enough with good ratings.
class CertificateScreen extends ConsumerWidget {
  const CertificateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shared = ref.watch(sessionProvider.select((u) => u?.portionsShared ?? 0));
    final progress = (shared / certificatePortions).clamp(0.0, 1.0);
    return Scaffold(
      body: SafeArea(
        child: EntranceScope(
          child: Column(children: [
            const TopBar(title: 'Detail hadiah', fallback: '/rewards'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  FadeSlideIn(
                    child: Container(
                      height: 190,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
                      child: const Icon(LucideIcons.award, size: 56, color: AppColors.background),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(index: 1, child: Text('Sertifikat Resto Peduli Lingkungan', style: AppTypography.display(24, height: 30))),
                  const SizedBox(height: 10),
                  const FadeSlideIn(index: 2, child: Wrap(spacing: 8, children: [InfoTag('Bulanan'), InfoTag('Untuk warung dan resto')])),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    index: 3,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: AppColors.surfaceSand, borderRadius: BorderRadius.circular(20)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Syarat bulan ini', style: AppTypography.text(13, color: AppColors.inkMuted)),
                        Text('$shared dari $certificatePortions porsi dibagikan', style: AppTypography.display(18, weight: 700, height: 24)),
                        const SizedBox(height: 12),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: Motion.of(context, const Duration(milliseconds: 900)),
                          curve: Motion.enter,
                          builder: (_, v, _) => ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: v, minHeight: 8, color: AppColors.primary, backgroundColor: AppColors.border),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    index: 4,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Cara mendapat', style: AppTypography.titleM),
                      const SizedBox(height: 8),
                      for (final s in [
                        '1. Bagikan minimal $certificatePortions porsi dalam satu bulan.',
                        '2. Pertahankan rating rata-rata ≥ $certificateRating.',
                        '3. Sertifikat terbit otomatis di awal bulan berikutnya.',
                      ])
                        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(s, style: AppTypography.text(14, height: 21, color: AppColors.inkMuted))),
                    ]),
                  ),
                ],
              ),
            ),
            const StickyBottomBar(child: AppButton(label: 'Terbit otomatis awal bulan', onPressed: null)),
          ]),
        ),
      ),
    );
  }
}

/// D22b Voucher saya: claimed vouchers, active or used, with a copy button.
class MyVouchersScreen extends ConsumerStatefulWidget {
  const MyVouchersScreen({super.key});

  @override
  ConsumerState<MyVouchersScreen> createState() => _MyVouchersScreenState();
}

class _MyVouchersScreenState extends ConsumerState<MyVouchersScreen> {
  var _used = false;

  @override
  Widget build(BuildContext context) {
    final vouchers = [for (final v in ref.watch(myVouchersProvider)) if (v.used == _used) v];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const TopBar(title: 'Voucher saya', fallback: '/rewards'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              AppChip(label: 'Aktif', selected: !_used, onTap: () => setState(() => _used = false)),
              const SizedBox(width: 8),
              AppChip(label: 'Terpakai', selected: _used, onTap: () => setState(() => _used = true)),
            ]),
          ),
          Expanded(
            child: EntranceScope(
              key: ValueKey(_used),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (vouchers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: EmptyState(icon: LucideIcons.ticket, title: _used ? 'Belum ada voucher terpakai' : 'Belum ada voucher aktif', body: 'Tukar poinmu di Tukar poin.'),
                    )
                  else
                    for (final (i, v) in vouchers.indexed) FadeSlideIn(index: i, child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _VoucherCard(voucher: v))),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher});

  final ClaimedVoucher voucher;

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox.square(dimension: 58, child: RewardTile(v.reward, fontSize: 22)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Status tag top-right, next to the title (D22b).
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(v.reward.title, style: AppTypography.display(16, weight: 700, height: 21))),
              const SizedBox(width: 8),
              v.used
                  ? const Pill('Terpakai', height: 24, weight: 700, color: AppColors.inkMuted)
                  : const Pill('Aktif', fill: AppColors.successTint, color: AppColors.primary, height: 24, weight: 700),
            ]),
            // Code and validity on the left, "Salin" bottom-right beside them.
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Kode ${v.code}', style: AppTypography.text(14, weight: 700)),
                  Text('Berlaku s/d ${formatLongDate(v.validUntil)}', style: AppTypography.text(13, color: AppColors.inkMuted)),
                ]),
              ),
              if (!v.used)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: AppButton(
                    label: 'Salin',
                    variant: AppButtonVariant.outline,
                    expand: false,
                    height: 44,
                    textSize: 14,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: v.code));
                      showAppSnack(context, 'Kode ${v.code} disalin.');
                    },
                  ),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
