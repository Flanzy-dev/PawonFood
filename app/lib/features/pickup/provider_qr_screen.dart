import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/data/providers.dart';
import '../../core/models/enums.dart';
import '../../core/motion/entrance.dart';
import '../../core/motion/motion_widgets.dart';
import '../../core/services/formatters.dart';
import '../../core/services/points.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/countdown.dart';
import '../../core/widgets/info_blocks.dart';
import '../../core/widgets/listing_summary.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/qr_box.dart';
import '../../core/widgets/status_layout.dart';
import '../../core/widgets/top_bar.dart';

/// C17 QR ambil (provider). One QR per reservation. The receiver's scan is simulated: it lands after twice
/// [simulatedScanDelayProvider] (tap the QR to scan right away), then the screen moves on to C17b / C17d.
class ProviderQrScreen extends ConsumerStatefulWidget {
  const ProviderQrScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ProviderQrScreen> createState() => _ProviderQrScreenState();
}

class _ProviderQrScreenState extends ConsumerState<ProviderQrScreen> {
  Timer? _timer;

  String get _id => widget.conversationId;

  @override
  void initState() {
    super.initState();
    _timer = Timer(ref.read(simulatedScanDelayProvider) * 2, _receiverScanned);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(chatProvider.notifier).expireIfLate(_id)) _leave('/expired/$_id');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _leave(String to) {
    _timer?.cancel();
    if (mounted) context.pushReplacement(to);
  }

  void _receiverScanned() {
    if (!mounted) return;
    switch (ref.read(chatProvider.notifier).scanQr(_id)) {
      case ScanOutcome.ok || ScanOutcome.alreadyUsed:
        unawaited(HapticFeedback.mediumImpact());
        _leave('/qr/$_id/done');
      case ScanOutcome.expired:
        _leave('/expired/$_id');
      case ScanOutcome.invalid:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(reservationProvider(_id));
    if (r == null) return const NotFoundScaffold();
    final who = r.receiver.name.split(' ').first;
    final deadline = formatTime(r.pickup.deadline);
    final payPill = r.amount == 0
        ? 'Gratis, tanpa bayar'
        : r.pickup.paid
            ? 'Sudah dibayar via QRIS'
            : 'Terima ${formatRupiah(r.payable)} di tempat';
    return Scaffold(
      body: SafeArea(
        child: EntranceScope(
          child: Column(
            children: [
              TopBar(fallback: '/chat/$_id'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    FadeSlideIn(child: Text('QR ambil', style: AppTypography.titleXl)),
                    const SizedBox(height: 12),
                    FadeSlideIn(index: 1, child: ListingSummaryCard(listing: r.listing, subtitle: '$who · ${r.portions} porsi')),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      index: 2,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))],
                        ),
                        child: Column(children: [
                          GestureDetector(
                            onTap: _receiverScanned,
                            child: QrBox(data: r.pickup.qrPayload, size: 236, semanticLabel: 'QR ambil untuk $who'),
                          ),
                          const SizedBox(height: 16),
                          Countdown(
                            until: r.pickup.deadline,
                            now: ref.read(clockProvider),
                            onDone: () {
                              if (ref.read(chatProvider.notifier).expireIfLate(_id)) _leave('/expired/$_id');
                            },
                            builder: (_, left) => Text('Berlaku s/d $deadline · sisa ${formatMinutesLeft(left)}', style: AppTypography.display(17, weight: 700, height: 22)),
                          ),
                          const SizedBox(height: 4),
                          Text('Tunjukkan ke $who saat mengambil.', style: AppTypography.text(14, color: AppColors.inkMuted)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      index: 3,
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        Pulse(child:Pill('Menunggu $who memindai', fill: AppColors.successTint, color: AppColors.primaryDark, height: 34, size: 14, weight: 700, hPad: 14)),
                        Pill(payPill, color: AppColors.accentInk, height: 34, size: 14, weight: 700, hPad: 14),
                      ]),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: AppButton(label: 'Chat dengan $who', icon: LucideIcons.messageSquare, variant: AppButtonVariant.outline, onPressed: () => context.go('/chat/$_id')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// C17b Makanan terselamatkan! (cash or free) and C17d (paid in the app, money goes to the provider's balance).
class ProviderPickupDoneScreen extends ConsumerWidget {
  const ProviderPickupDoneScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(reservationProvider(conversationId));
    if (r == null) return const NotFoundScaffold();
    final who = r.receiver.name.split(' ').first;
    final points = pickupPoints(portions: r.portions, isFree: r.amount == 0);
    final paidInApp = r.pickup.paid || r.pickup.payMethod == PayMethod.qris;
    return StatusLayout(
      kind: StatusKind.success,
      title: 'Makanan terselamatkan!',
      body: '${r.portions} porsi ${r.listing.name} sudah diambil $who.',
      content: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            Text('Poin dampak', style: AppTypography.text(14, color: AppColors.onGreenMuted)),
            AnimatedCount(value: points, from: 0, format: (v) => '+${v.round()} poin', style: AppTypography.display(38, height: 46, color: AppColors.background)),
            Text('Gratis memberi poin lebih banyak', style: AppTypography.text(13, color: AppColors.onGreenMuted)),
          ]),
        ),
        if (paidInApp)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pembayaran', style: AppTypography.display(16, weight: 700)),
              const SizedBox(height: 6),
              AmountRow('Dibayar $who via QRIS', formatRupiah(r.payable)),
              if (r.discount > 0) AmountRow('Voucher PawonFood (ditanggung PawonFood)', formatRupiah(r.discount)),
              const Divider(height: 16),
              AmountRow('Masuk ke saldo kamu', formatRupiah(r.amount), strong: true),
            ]),
          )
        else if (r.amount > 0)
          Pill('Terima ${formatRupiah(r.payable)} di tempat', color: AppColors.accentInk, height: 36, size: 15, weight: 700, hPad: 18),
        if (paidInApp) Text('Pencairan saldo ke rekening: segera hadir.', style: AppTypography.text(13, color: AppColors.inkMuted)),
      ],
      actions: [AppButton(label: 'Kembali', onPressed: () => context.go('/messages'))],
    );
  }
}
