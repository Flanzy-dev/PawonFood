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

/// "Tawar cepat" amounts for a price: about 60% and 80%, rounded to Rp500, strictly between 0 and the price.
/// (Rp5.000 -> Rp3.000 and Rp4.000.)
List<int> quickOffers(int price) {
  int round500(double v) => (v / 500).round() * 500;
  final amounts = {round500(price * 0.6), round500(price * 0.8)}.where((a) => a > 0 && a < price).toList()..sort();
  return amounts;
}

/// `PWN-XXXX` (4 digits). In the MVP this runs on device; later it must be generated server-side.
String generatePickupCode(Random random) => 'PWN-${(1000 + random.nextInt(9000))}';
