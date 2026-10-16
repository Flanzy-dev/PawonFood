import 'package:flutter/material.dart';

import '../../core/data/pickup_points_repository.dart';
import '../../core/models/listing.dart';
import '../../core/services/formatters.dart';
import '../../core/services/negotiation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_sheet.dart';
import '../listing/handover_choice.dart';

/// B10m "Tawar ongkir": only the delivery fee is haggled. The chips go down from the provider's fee in Rp1.000 steps to
/// Gratis ([deliveryFeeOffers]); the food stays at [amount] per porsi. Returns the fee to offer; the button stays off
/// while the fee equals the provider's, because that is no offer. [fee] is where the choice starts (the provider's last
/// counter), else one step below the listed fee.
Future<int?> showFeeOfferSheet(BuildContext context, {required Listing listing, required PickupPoint address, required int amount, int? fee}) => showAppSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _FeeOfferSheet(listing: listing, address: address, amount: amount, fee: fee),
    );

class _FeeOfferSheet extends StatefulWidget {
  const _FeeOfferSheet({required this.listing, required this.address, required this.amount, this.fee});

  final Listing listing;
  final PickupPoint address;
  final int amount;
  final int? fee;

  @override
  State<_FeeOfferSheet> createState() => _FeeOfferSheetState();
}

class _FeeOfferSheetState extends State<_FeeOfferSheet> {
  late final _listed = widget.listing.deliveryFee ?? 0;
  late var _fee = (widget.fee ?? _listed - 1000).clamp(0, _listed);

  String _label(int fee) => fee == 0 ? 'Gratis' : formatRupiah(fee);

  bool get _canSend => _fee < _listed;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tawar ongkir', style: AppTypography.titleL),
            const SizedBox(height: 4),
            Text('Ongkir dari penyedia ${formatRupiah(_listed)}', style: AppTypography.text(14, color: AppColors.inkMuted)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in deliveryFeeOffers(_listed)) AppChip(label: _label(f), selected: _fee == f, height: 44, onTap: () => setState(() => _fee = f)),
            ]),
            const SizedBox(height: 16),
            Text('Diantar ke ${addressOf(widget.address)}', style: AppTypography.text(14)),
            const SizedBox(height: 2),
            Text('Harga makanan tetap ${formatRupiah(widget.amount)} per porsi', style: AppTypography.text(13, color: AppColors.inkMuted)),
            const SizedBox(height: 16),
            AppButton(label: 'Kirim tawaran ongkir · ${_label(_fee)}', onPressed: _canSend ? () => closeSheet(context, _fee) : null),
          ],
        ),
      );
}
