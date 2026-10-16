import 'package:flutter/material.dart';

import '../../core/data/pickup_points_repository.dart';
import '../../core/models/conversation.dart';
import '../../core/models/listing.dart';
import '../../core/motion/entrance.dart';
import '../../core/services/formatters.dart';
import '../../core/services/negotiation.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/info_box.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/form_controls.dart';
import '../listing/handover_choice.dart';

/// What the receiver wrote in "Tulis sendiri".
class OfferDraft {
  const OfferDraft({required this.amount, required this.portions, required this.message, this.delivery, this.deliveryFee});
  final int amount;
  final int portions;
  final String message;

  /// "Minta diantar"; null for "Ambil sendiri".
  final Delivery? delivery;

  /// "Tawar ongkir": the fee the receiver offers with [delivery]; null for pickup.
  final int? deliveryFee;
}

/// B8e-B8g "Tulis tawaranmu": price per portion, portions (up to the stock), pickup or delivery to [address] (only when
/// the provider opened delivery; [delivery] is the choice made on the detail), the delivery fee to offer (starts at
/// [fee], else the provider's) and an optional note. The amount is checked while typing (above Rp0, below the listed
/// price, or up to it when the ongkir is lowered) and the button stays off until it is valid.
Future<OfferDraft?> showOfferSheet(BuildContext context, {required Listing listing, required PickupPoint address, bool delivery = false, int? fee}) =>
    showAppSheet<OfferDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _OfferSheet(listing: listing, address: address, delivery: delivery, fee: fee),
    );

class _OfferSheet extends StatefulWidget {
  const _OfferSheet({required this.listing, required this.address, required this.delivery, this.fee});

  final Listing listing;
  final PickupPoint address;
  final bool delivery;
  final int? fee;

  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  final _amount = TextEditingController();
  final _message = TextEditingController();
  var _portions = 1;
  late var _wantsDelivery = widget.delivery;
  late final _listedFee = widget.listing.deliveryFee ?? 0;
  late var _fee = (widget.fee ?? _listedFee).clamp(0, _listedFee);

  /// Delivery-only food always asks for a delivery; null when the address is out of reach. Carries the offered fee.
  Delivery? get _delivery {
    if (!(_wantsDelivery || !widget.listing.allowsPickup) || Validators.delivery(widget.listing, widget.address.position) != null) return null;
    final d = deliveryTo(widget.listing, widget.address);
    return Delivery(address: d.address, position: d.position, fee: _fee);
  }

  /// Only a delivered offer can ask for a lower ongkir.
  bool get _feeLowered => _delivery != null && _fee < _listedFee;

  int get _price => widget.listing.price;

  @override
  void dispose() {
    _amount.dispose();
    _message.dispose();
    super.dispose();
  }

  int? get _value => parseAmount(_amount.text);

  /// Error only once something was typed; an empty field just shows the hint under it.
  String? get _error => _amount.text.isEmpty || _value == 0 ? null : Validators.offerAmount(_value, _price, feeLowered: _feeLowered);

  bool get _valid => Validators.offerAmount(_value, _price, feeLowered: _feeLowered) == null;

  /// A valid amount and a handover the listing allows (delivery-only food needs a reachable address).
  bool get _canSend => _valid && (widget.listing.allowsPickup || _delivery != null);

  String get _helper {
    if (!_valid) return _feeLowered ? 'Paling tinggi ${formatRupiah(_price)}' : 'Di bawah harga ${formatRupiah(_price)}';
    return _value == _price ? 'Harga penuh, yang ditawar ongkirnya' : 'Hemat ${formatRupiah(_price - _value!)} dari harga';
  }

  void _submit() {
    if (!_canSend) return;
    final drop = _delivery;
    closeSheet(context, OfferDraft(amount: _value!, portions: _portions, message: _message.text, delivery: drop, deliveryFee: drop?.fee));
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
          if (l.bringsContainer) ...[const SizedBox(height: 8), PackagingNote(l.packaging, compact: true)],
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
          if (l.canDeliver) ...[
            const SizedBox(height: 16),
            HandoverChoice(listing: l, address: widget.address, delivery: _wantsDelivery, onChanged: (v) => setState(() => _wantsDelivery = v)),
          ],
          if (_delivery != null && _listedFee > 0) ...[
            const SizedBox(height: 16),
            Text('Tawar ongkir', style: AppTypography.display(16, weight: 700)),
            const SizedBox(height: 4),
            Text('Ongkir dari penyedia ${formatRupiah(_listedFee)}', style: AppTypography.text(13, color: AppColors.inkMuted)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in deliveryFeeOffers(_listedFee))
                AppChip(label: f == 0 ? 'Gratis' : formatRupiah(f), selected: _fee == f, height: 44, onTap: () => setState(() => _fee = f)),
            ]),
          ],
          const SizedBox(height: 16),
          AppTextField(label: 'Pesan untuk penjual (opsional)', controller: _message, hint: 'Contoh: saya bisa ambil sekarang', textInputAction: TextInputAction.done),
          const SizedBox(height: 20),
          FadeSwitch(
            alignment: Alignment.center,
            duration: const Duration(milliseconds: 150),
            child: AppButton(
              key: ValueKey(_canSend),
              label: _canSend ? 'Kirim tawaran · ${formatRupiah(_value!)}' : 'Kirim tawaran',
              onPressed: _canSend ? _submit : null,
            ),
          ),
          if (_delivery != null) ...[
            const SizedBox(height: 8),
            Center(child: Text(_delivery!.fee == 0 ? 'Gratis ongkir' : '+ ongkir ${formatRupiah(_delivery!.fee)}', style: AppTypography.text(13, color: AppColors.inkMuted))),
          ],
        ],
      ),
    );
  }
}
