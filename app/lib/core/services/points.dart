import '../models/enums.dart';

/// Assumptions for the open questions in PRD.md (tier thresholds, point rules, impact formula).
/// Tier thresholds: Sobat Pawon 0, Food Savior 500, Pahlawan Pangan 1.500.
const double kgPerPortion = 0.5;
const int pointsPerPortion = 10;
const int ratingBonusPoints = 5;

Tier tierFor(int points) {
  var current = Tier.sobatPawon;
  for (final t in Tier.values) {
    if (points >= t.minPoints) current = t;
  }
  return current;
}

Tier? nextTier(Tier t) {
  final i = Tier.values.indexOf(t);
  return i + 1 < Tier.values.length ? Tier.values[i + 1] : null;
}

/// Points still needed to reach the next tier (0 at the top tier).
int pointsToNext(int points) {
  final next = nextTier(tierFor(points));
  return next == null ? 0 : next.minPoints - points;
}

/// 0..1 progress toward the next tier (1 at the top tier).
double tierProgress(int points) {
  final cur = tierFor(points), next = nextTier(cur);
  if (next == null) return 1;
  return ((points - cur.minPoints) / (next.minPoints - cur.minPoints)).clamp(0.0, 1.0);
}

/// Points a provider earns when food is picked up. Free food earns double; a rating of 4+ adds a bonus.
int pickupPoints({required int portions, required bool isFree, int? rating}) {
  var p = portions * pointsPerPortion;
  if (isFree) p *= 2;
  if (rating != null && rating >= 4) p += ratingBonusPoints;
  return p;
}
