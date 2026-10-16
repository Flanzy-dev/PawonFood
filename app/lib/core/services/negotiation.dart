import 'dart:math';

/// Result of the simulated provider reacting to an offer (MVP has no real counterpart).
sealed class OfferDecision {
  const OfferDecision();
}

class OfferAccepted extends OfferDecision {
  const OfferAccepted();
}

/// Provider answers with a counter price.
class OfferCountered extends OfferDecision {
  const OfferCountered(this.amount);
  final int amount;
}

/// Offers of at least half the price are accepted. Lower offers get a counter at about 60% of the price.
/// Non-negotiable listings only accept the full price. Free food is always accepted.
OfferDecision decideOffer({required int price, required int amount, required bool negotiable}) {
  if (price == 0 || amount >= price) return const OfferAccepted();
  if (!negotiable) return OfferCountered(price);
  if (amount * 2 >= price) return const OfferAccepted();
  final counter = ((price * 0.6) / 500).round() * 500;
  return OfferCountered(max(counter, 500).clamp(0, price).toInt());
}

/// The simulated provider on an offered delivery fee: half the fee or more is fine (null), lower gets a counter at about
/// 60% of the fee, rounded to Rp1.000 (Rp2.000 -> Rp1.000, Rp3.000 -> Rp2.000).
int? counterDeliveryFee({required int fee, required int offered}) {
  if (offered * 2 >= fee) return null;
  return (((fee * 0.6) / 1000).round() * 1000).clamp(offered, fee).toInt();
}

/// "Tawar ongkir" choices for a provider's fee: the fee, then down in Rp1.000 steps to Rp0 (Rp3.000 -> 3.000, 2.000,
/// 1.000, 0). Free delivery has nothing to haggle.
List<int> deliveryFeeOffers(int fee) => fee <= 0 ? const [] : [for (var f = fee; f > 0; f -= 1000) f, 0];

/// "Tawar cepat" amounts for a price: about 60% and 80%, rounded to Rp500, strictly between 0 and the price.
/// (Rp5.000 -> Rp3.000 and Rp4.000.)
List<int> quickOffers(int price) {
  int round500(double v) => (v / 500).round() * 500;
  final amounts = {round500(price * 0.6), round500(price * 0.8)}.where((a) => a > 0 && a < price).toList()..sort();
  return amounts;
}
