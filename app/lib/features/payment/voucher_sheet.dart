import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/data/providers.dart';
import '../../core/data/rewards_repository.dart';
import '../../core/models/claimed_voucher.dart';
import '../../core/services/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/option_row.dart';

/// "Pakai voucher" on Pembayaran: type a voucher code, or tap one of the food vouchers from Voucher saya. Closes itself once a voucher is
/// applied; the reason is shown under the field when it is refused.
Future<void> showVoucherSheet(BuildContext context, {required String conversationId}) => showAppSheet<void>(
      context: context,
      builder: (ctx) => _VoucherSheet(conversationId: conversationId),
    );

class _VoucherSheet extends ConsumerStatefulWidget {
  const _VoucherSheet({required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<_VoucherSheet> createState() => _VoucherSheetState();
}

class _VoucherSheetState extends ConsumerState<_VoucherSheet> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _apply(String code) {
    final error = ref.read(chatProvider.notifier).applyVoucher(widget.conversationId, code);
    if (error == null) {
      closeSheet(context);
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final usable = [for (final v in ref.watch(myVouchersProvider)) if (v.reward.isFoodVoucher && !v.used && v.validUntil.isAfter(now)) v];
    return SheetBody(
      title: 'Pakai voucher',
      subtitle: 'Potongan makanan dari Tukar poin. Satu voucher untuk satu pembayaran.',
      children: [
        AppTextField(
          label: 'Kode voucher',
          controller: _code,
          hint: 'PWN-V-XXXX',
          errorText: _error,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: _apply,
        ),
        const SizedBox(height: 12),
        AppButton(label: 'Pakai kode', onPressed: _code.text.trim().isEmpty ? null : () => _apply(_code.text)),
        const SizedBox(height: 20),
        Text('Voucher saya', style: AppTypography.titleM),
        const SizedBox(height: 10),
        if (usable.isEmpty)
          Text('Belum ada voucher potongan makanan. Tukar poinmu di Profil > Tukar poin.', style: AppTypography.bodyMuted)
        else
          for (final v in usable) Padding(padding: const EdgeInsets.only(bottom: 10), child: _VoucherOption(voucher: v, onTap: () => _apply(v.code))),
      ],
    );
  }
}

class _VoucherOption extends StatelessWidget {
  const _VoucherOption({required this.voucher, required this.onTap});

  final ClaimedVoucher voucher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OptionRow(
        title: voucher.reward.title,
        subtitle: voucherSubtitle(voucher),
        lead: OptionLead.badge,
        icon: LucideIcons.ticket,
        selected: false,
        chevron: true,
        onTap: onTap,
      );
}

/// "PWN-V-3001 · s/d 18 Nov 2026": the second line of a voucher in the sheet and on the applied voucher card.
String voucherSubtitle(ClaimedVoucher v) => '${v.code} · s/d ${formatShortDate(v.validUntil)}';

/// The applied voucher in Rincian: only the code and the discount ("PWN-V-3001  −Rp3.000"). It is removed with the ✕ on
/// the voucher card under Total.
class AppliedVoucherRow extends StatelessWidget {
  const AppliedVoucherRow({super.key, required this.code, required this.discount});

  final String code;
  final int discount;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(code, style: AppTypography.text(15, height: 22, color: AppColors.primary, weight: 600))),
          Text('−${formatRupiah(discount)}', style: AppTypography.text(15, weight: 700, height: 22, color: AppColors.primary)),
        ]),
      );
}
