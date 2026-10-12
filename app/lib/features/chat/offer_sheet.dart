import 'package:flutter/material.dart';

import '../../core/models/listing.dart';
import '../../core/motion/entrance.dart';
import '../../core/services/formatters.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/form_controls.dart';

/// What the receiver wrote in "Tulis sendiri".
class OfferDraft {
  const OfferDraft({required this.amount, required this.portions, required this.message});
  final int amount;
  final int portions;
  final String message;
}

/// B8e-B8g "Tulis tawaranmu": price per portion, portions (up to the stock) and an optional note. The amount is
/// checked while typing (above Rp0, below the listed price) and the button stays off until it is valid.
Future<OfferDraft?> showOfferSheet(BuildContext context, {required Listing listing}) => showAppSheet<OfferDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _OfferSheet(listing: listing),
    );

class _OfferSheet extends StatefulWidget {
  const _OfferSheet({required this.listing});

  final Listing listing;

  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  final _amount = TextEditingController();
  final _message = TextEditingController();
  var _portions = 1;

  int get _price => widget.listing.price;

  @override
  void dispose() {
    _amount.dispose();
    _message.dispose();
    super.dispose();
  }

  int? get _value => parseAmount(_amount.text);

  /// Error only once something was typed; an empty field just shows the hint under it.
  String? get _error => _amount.text.isEmpty || _value == 0 ? null : Validators.offerAmount(_value, _price);

  bool get _valid => Validators.offerAmount(_value, _price) == null;

  String get _helper => _valid ? 'Hemat ${formatRupiah(_price - _value!)} dari harga' : 'Di bawah harga ${formatRupiah(_price)}';

  void _submit() {
    if (!_valid) return;
    closeSheet(context, OfferDraft(amount: _value!, portions: _portions, message: _message.text));
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tulis tawaranmu', style: AppTypography.titleL),
          const SizedBox(height: 4),
          Text('Harga ${formatRupiah(_price)} · sisa ${l.portionsLeft} porsi', style: AppTypography.text(14, color: AppColors.inkMuted)),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Tawaran per porsi',
            controller: _amount,
            hint: 'Rp0',
            prefix: _amount.text.isEmpty ? null : 'Rp',
            errorText: _error,
            helperText: _error == null ? _helper : null,
            keyboardType: TextInputType.number,
            inputFormatters: const [ThousandsFormatter()],
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('Jumlah porsi', style: AppTypography.display(16, weight: 700))),
            QtyStepper(value: _portions, min: 1, max: l.portionsLeft.clamp(1, 99), onChanged: (v) => setState(() => _portions = v)),
          ]),
          const SizedBox(height: 16),
          AppTextField(label: 'Pesan untuk penjual (opsional)', controller: _message, hint: 'Contoh: saya bisa ambil sekarang', textInputAction: TextInputAction.done),
          const SizedBox(height: 20),
          FadeSwitch(
            alignment: Alignment.center,
            duration: const Duration(milliseconds: 150),
            child: AppButton(
              key: ValueKey(_valid),
              label: _valid ? 'Kirim tawaran · ${formatRupiah(_value!)}' : 'Kirim tawaran',
              onPressed: _valid ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}
