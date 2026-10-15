import 'dart:math' as math;

import '../models/enums.dart';
import '../models/listing.dart';

// Feed ranking ("Pilihan untukmu di sekitar", PRD): score = user affinity × distance proximity × deadline urgency.
// Affinity comes from the FYP recommender (services/fyp.dart); freshness and health only drive the card labels.
// See ARCHITECTURE.md → Feed ranking.

/// Each factor counts from this floor up to 1, so no single one (far away, plenty left, low affinity) zeroes a
/// listing out of the product.
const double scoreFloor = 0.2;

/// Cooked food loses freshness linearly and counts as 0 after this many minutes.
const int cookedFreshMinutes = 360;

/// Raw ingredients carry no cooking time; they are shared the day they were bought.
const double rawIngredientFreshness = 0.9;

/// Freshness when the data says nothing (cooked food with no cooking time, sealed food with no best-before date).
const double unknownCookedFreshness = 0.5;
const double unknownSealedFreshness = 0.6;

/// Sealed food with at least this many days left is fully fresh.
const int sealedFreshDays = 3;

/// Points per tag in [healthScore].
const Map<HealthTag, double> healthTagWeights = {
  HealthTag.sayurBuah: 0.4,
  HealthTag.protein: 0.25,
  HealthTag.tidakDigoreng: 0.2,
  HealthTag.rendahGula: 0.15,
};

/// [healthScore] from which a listing counts as healthy ("Sehat"): vegetables plus one more tag.
const double healthyThreshold = 0.5;

/// [freshness] from which a listing counts as fresh ("Segar"): cooked within the last 90 minutes, like "Sedang hangat".
const double freshThreshold = 0.75;

/// Listings with this many portions or more get no urgency from their stock.
const int plentifulPortions = 8;

/// A pickup deadline this close (or closer) is fully urgent; [relaxedPickupMinutes] or later is not urgent at all.
const int urgentPickupMinutes = 30;
const int relaxedPickupMinutes = 360;

double _unit(double v) => v.clamp(0.0, 1.0).toDouble();

/// How fresh the food is, from its category and what the listing knows (cooking time, best-before date).
double freshness(Listing l, DateTime now) {
  switch (l.category) {
    case FoodCategory.makananMatang:
      final cooked = l.cookedAt;
      if (cooked == null) return unknownCookedFreshness;
      return _unit(1 - now.difference(cooked).inMinutes / cookedFreshMinutes);
    case FoodCategory.bahanMentah:
      return rawIngredientFreshness;
    case FoodCategory.sealedFood:
      final best = l.bestBefore;
      if (best == null) return unknownSealedFreshness;
      final days = best.difference(now).inHours / 24;
      return _unit(0.2 + 0.8 * days / sealedFreshDays);
  }
}

/// Sum of the provider's health tags ([healthTagWeights]); 1 when every tag applies.
double healthScore(Listing l) => _unit(l.healthTags.fold(0.0, (sum, t) => sum + healthTagWeights[t]!));

/// How soon the food would go to waste: few portions left and a near pickup deadline.
double urgency(Listing l, DateTime now) {
  final stock = _unit(1 - (math.max(l.portionsLeft, 1) - 1) / (plentifulPortions - 1));
  final minutesLeft = l.pickupBy.difference(now).inMinutes;
  final time = _unit(1 - (minutesLeft - urgentPickupMinutes) / (relaxedPickupMinutes - urgentPickupMinutes));
  return (stock + time) / 2;
}

double _floored(double v) => scoreFloor + (1 - scoreFloor) * _unit(v);

/// Ranking score of a listing in the feed, 0..1, higher first: [affinity] (0.2..1 from the recommender, 1 when there
/// is none) × proximity (1 at the user's location, down to the floor at the edge of the radius) × [urgency].
double feedScore(Listing l, double distanceMeters, double radiusMeters, DateTime now, {double affinity = 1}) {
  final nearness = radiusMeters <= 0 ? 1.0 : 1 - distanceMeters / radiusMeters;
  return _unit(affinity) * _floored(nearness) * _floored(urgency(l, now));
}

bool isHealthy(Listing l) => healthScore(l) >= healthyThreshold;

bool isFresh(Listing l, DateTime now) => freshness(l, now) >= freshThreshold;
