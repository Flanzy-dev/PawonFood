import 'package:flutter/material.dart';

import '../../core/services/formatters.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/form_controls.dart';

/// "Tulis sendiri": asks for an offer amount (must be 1..price). Returns the amount or null.
Future<int?> showOfferSheet(BuildContext context, {required int price}) => showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OfferSheet(price: price),
    );

class _OfferSheet extends StatefulWidget {
  const _OfferSheet({required this.price});

  final int price;

  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = parseAmount(_controller.text);
    final error = Validators.offerAmount(amount, widget.price);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tulis tawaranmu', style: AppTypography.titleL),
            const SizedBox(height: 4),
            Text('Harga sekarang ${formatRupiah(widget.price)} per porsi.', style: AppTypography.bodyMuted),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Tawaran per porsi',
              controller: _controller,
              hint: '3.000',
              prefix: 'Rp',
              suffixText: '/porsi',
              errorText: _error,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsFormatter()],
              autofocus: true,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            AppButton(label: 'Kirim tawaran', onPressed: _submit),
          ],
        ),
      );
}
