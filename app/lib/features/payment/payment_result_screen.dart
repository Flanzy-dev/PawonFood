import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/models/enums.dart';
import '../../core/services/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/info_box.dart';
import '../../core/widgets/listing_summary.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/status_layout.dart';

/// B10g Pembayaran berhasil / B10h Pembayaran belum berhasil.
class PaymentResultScreen extends ConsumerWidget {
  const PaymentResultScreen({super.key, required this.conversationId, required this.success});

  final String conversationId;
  final bool success;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(reservationProvider(conversationId));
    if (r == null) return const NotFoundScaffold();
    final deadline = formatTime(r.pickup.deadline);
    void toChat() => context.go('/chat/$conversationId');

    if (!success) {
      return StatusLayout(
        kind: StatusKind.failure,
        back: true,
        fallback: '/chat/$conversationId',
        title: 'Pembayaran belum berhasil',
        body: 'QRIS kedaluwarsa sebelum dibayar. Reservasi masih aman sampai $deadline.',
        content: const [InfoBox('Saldo kamu tidak terpotong. Kalau sudah terpotong, dana kembali otomatis.', icon: LucideIcons.info)],
        actions: [
          AppButton(label: 'Coba lagi', onPressed: () => context.pushReplacement('/pay/$conversationId/qris')),
          AppButton(
            label: 'Pakai tunai di tempat',
            variant: AppButtonVariant.outline,
            onPressed: () {
              ref.read(chatProvider.notifier).choosePayment(conversationId, PayMethod.cash);
              toChat();
            },
          ),
        ],
      );
    }
    final paidAt = r.pickup.paidAt;
    final delivered = r.delivery != null;
    // Back from the success screen goes to the chat, not to the payment form of an order that is already paid.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) toChat();
      },
      child: StatusLayout(
      kind: StatusKind.success,
      title: 'Pembayaran berhasil',
      body: '${formatRupiah(r.payable)} · QRIS${r.discount > 0 ? ' · voucher −${formatRupiah(r.discount)}' : ''}${paidAt == null ? '' : ' · ${formatTime(paidAt)}'}',
      content: [
        ListingSummaryCard(listing: r.listing, subtitle: '${r.provider.name} · ${r.portions} porsi · ${delivered ? 'diantar' : 'ambil'} s/d $deadline'),
        InfoBox('Dana ditahan PawonFood dan diteruskan ke ${r.provider.name} setelah kamu memindai QR ambil. Kalau reservasi kedaluwarsa, dana kembali penuh.'),
        Pill('${delivered ? 'Diantar' : 'Ambil'} sebelum $deadline', color: AppColors.accentInk, height: 34, size: 14, weight: 700, hPad: 16),
      ],
      // A delivery comes to the receiver, so there is no walking route to open.
      actions: delivered
          ? [AppButton(label: 'Kembali ke chat', onPressed: toChat)]
          : [
              AppButton(label: 'Lihat rute', icon: LucideIcons.personStanding, onPressed: () => context.pushReplacement('/route/$conversationId')),
              AppButton(label: 'Kembali ke chat', variant: AppButtonVariant.outline, onPressed: toChat),
            ],
    ),
    );
  }
}
