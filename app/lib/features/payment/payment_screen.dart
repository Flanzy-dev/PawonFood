import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/data/rewards_repository.dart';
import '../../core/models/enums.dart';
import '../../core/motion/entrance.dart';
import '../../core/services/formatters.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/info_blocks.dart';
import '../../core/widgets/info_box.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/listing_summary.dart';
import '../../core/widgets/option_row.dart';
import '../../core/widgets/top_bar.dart';
import 'payment_guard.dart';
import 'voucher_sheet.dart';

/// B10d-B10e Pembayaran: breakdown (no fee), cash or QRIS, and the food-condition consent right above the button.
/// The button stays off until the consent is checked (PRD Trust & Food Safety).
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  var _method = PayMethod.cash;
  var _consent = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) redirectIfReservationOver(context, ref, widget.conversationId);
    });
  }

  void _confirm(ReservationInfo r) {
    // Two quick taps used to pop the chat as well, or push two QRIS screens.
    if (_busy) return;
    if (redirectIfReservationOver(context, ref, widget.conversationId)) return;
    _busy = true;
    if (_method == PayMethod.cash) {
      ref.read(chatProvider.notifier).choosePayment(widget.conversationId, PayMethod.cash);
      context.canPop() ? context.pop() : context.go('/chat/${widget.conversationId}');
    } else {
      context.push('/pay/${widget.conversationId}/qris').whenComplete(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(reservationProvider(widget.conversationId));
    if (r == null) return const NotFoundScaffold();
    final total = formatRupiah(r.payable);
    final code = r.pickup.voucherCode;
    ref.watch(myVouchersProvider);
    final applied = code == null ? null : ref.read(myVouchersProvider.notifier).byCode(code);
    final rows = <Widget>[
      ListingSummaryCard(
        listing: r.listing,
        subtitle: '${r.provider.name} · ${r.portions} porsi · ${r.delivery == null ? 'ambil' : 'diantar'} s/d ${formatTime(r.pickup.deadline)}',
      ),
      const SizedBox(height: 16),
      Text('Rincian', style: AppTypography.titleM),
      const SizedBox(height: 6),
      AmountRow('Harga disepakati', formatRupiah(r.amount)),
      // The delivery fee goes entirely to the provider, like the food price.
      if (r.delivery != null) AmountRow('Ongkir', r.deliveryFee == 0 ? 'Gratis' : formatRupiah(r.deliveryFee)),
      if (code != null) AppliedVoucherRow(code: code, discount: r.discount),
      const AmountRow('Biaya layanan', 'Gratis'),
      const Divider(height: 20),
      AmountRow('Total', total, strong: true),
      const SizedBox(height: 14),
      // The voucher card stays once a voucher is applied: it then shows that voucher, a tap changes it, the ✕ removes it.
      if (code == null)
        OptionRow(
          title: 'Pakai voucher',
          subtitle: 'Punya voucher potongan makanan?',
          lead: OptionLead.badge,
          icon: LucideIcons.ticket,
          selected: false,
          chevron: true,
          onTap: () => showVoucherSheet(context, conversationId: widget.conversationId),
        )
      else
        OptionRow(
          title: applied?.reward.title ?? 'Voucher terpasang',
          subtitle: applied == null ? code : voucherSubtitle(applied),
          lead: OptionLead.badge,
          icon: LucideIcons.ticket,
          selected: true,
          trailingIcon: LucideIcons.x,
          trailingLabel: 'Lepas voucher $code',
          onTrailing: () => ref.read(chatProvider.notifier).removeVoucher(widget.conversationId),
          onTap: () => showVoucherSheet(context, conversationId: widget.conversationId),
        ),
      const SizedBox(height: 16),
      Text('Cara bayar', style: AppTypography.titleM),
      const SizedBox(height: 10),
      OptionRow(
        title: 'Tunai di tempat',
        subtitle: r.delivery == null ? 'Bayar saat ambil, setelah pindai QR' : 'Bayar saat makanan sampai, setelah pindai QR',
        selected: _method == PayMethod.cash,
        onTap: () => setState(() => _method = PayMethod.cash),
      ),
      const SizedBox(height: 10),
      OptionRow(
        title: 'QRIS',
        subtitle: 'Dipindai dari e-wallet atau m-banking',
        selected: _method == PayMethod.qris,
        onTap: () => setState(() => _method = PayMethod.qris),
      ),
      const SizedBox(height: 14),
      FadeSwitch(
        child: InfoBox(
          key: ValueKey(_method),
          _method == PayMethod.cash
              ? 'Bayar tunai ke penyedia setelah memindai QR. Jangan transfer uang di luar aplikasi.'
              : 'Dana ditahan PawonFood sampai QR ambil dipindai. Kalau batal atau kedaluwarsa, dana kembali penuh.',
        ),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: EntranceScope(
          child: Column(
            children: [
              const TopBar(title: 'Pembayaran', fallback: '/messages'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [for (final (i, w) in rows.indexed) FadeSlideIn(index: i ~/ 3, child: w)],
                ),
              ),
              StickyBottomBar(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppCheckbox(
                      value: _consent,
                      textSize: 13,
                      label: 'Saya telah memeriksa kondisi makanan dan membebaskan PawonFood dari tuntutan kesehatan.',
                      onChanged: (v) => setState(() => _consent = v),
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: _method == PayMethod.cash ? 'Pakai tunai di tempat' : 'Bayar $total',
                      onPressed: _consent ? () => _confirm(r) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
