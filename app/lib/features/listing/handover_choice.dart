import 'package:flutter/material.dart';

import '../../core/data/pickup_points_repository.dart';
import '../../core/models/conversation.dart';
import '../../core/models/listing.dart';
import '../../core/services/formatters.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/option_row.dart';

/// A point as the provider reads it, written the same way as a listing's pickup point.
String addressOf(PickupPoint p) => p.fromMap ? '${p.name}, ${p.address}' : p.name;

/// "Minta diantar" to [p] at the listing's fee.
Delivery deliveryTo(Listing l, PickupPoint p) => Delivery(address: addressOf(p), position: p.position, fee: l.deliveryFee ?? 0);

/// An earlier delivery's address as a point, so "Tawar lagi" starts from the same choice.
PickupPoint pointOf(Delivery d) => PickupPoint(id: 'drop', name: d.address, address: '', position: d.position);

/// B8 "Cara ambil", also in "Tulis tawaranmu": *Ambil sendiri (Rp0)* or *Minta diantar (+ongkir)* to [address]. Only for
/// listings the provider opened for delivery ([Listing.canDeliver]). Delivery-only food ([Listing.allowsPickup] false)
/// keeps "Ambil sendiri" visible but off, so the receiver sees why. An address more than 1 km from the food turns the
/// delivery row off and says why; [onChangeAddress] (the detail screen only) lets the receiver pick another one.
class HandoverChoice extends StatelessWidget {
  const HandoverChoice({super.key, required this.listing, required this.address, required this.delivery, required this.onChanged, this.onChangeAddress});

  final Listing listing;
  final PickupPoint address;
  final bool delivery;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onChangeAddress;

  @override
  Widget build(BuildContext context) {
    final error = Validators.delivery(listing, address.position);
    final pickup = listing.allowsPickup;
    final delivered = delivery || !pickup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cara ambil', style: AppTypography.titleM),
        const SizedBox(height: 10),
        OptionRow(
          title: 'Ambil sendiri',
          subtitle: pickup ? 'Rp0 · jalan ke titik ambil' : 'Penyedia hanya mengantar',
          selected: pickup && (!delivery || error != null),
          enabled: pickup,
          onTap: pickup ? () => onChanged(false) : null,
        ),
        const SizedBox(height: 10),
        OptionRow(
          title: 'Minta diantar',
          subtitle: error ?? '${formatDeliveryFee(listing.deliveryFee ?? 0)} · ke ${addressOf(address)}',
          selected: delivered && error == null,
          enabled: error == null,
          onTap: error == null ? () => onChanged(true) : null,
        ),
        if (onChangeAddress != null)
          TextButton(
            onPressed: onChangeAddress,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 4), foregroundColor: AppColors.primary),
            child: Text('Ubah alamat antar', style: AppTypography.text(14, weight: 700, color: AppColors.primary)),
          ),
      ],
    );
  }
}
