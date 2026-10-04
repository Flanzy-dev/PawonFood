import '../models/enums.dart';
import '../models/listing.dart';

/// Status label shown on a food photo (replaces the old "AI" badge).
enum FoodLabel {
  hampirHabis('Hampir habis'),
  populer('Populer'),
  terbaru('Terbaru');

  const FoodLabel(this.label);
  final String label;
}

/// A listing counts as new for this long after it was cooked / published.
const int newListingMinutes = 60;

/// Picks at most one label. Priority: almost sold out, then popular (top-tier provider), then new.
FoodLabel? foodLabelFor(Listing l, DateTime now) {
  if (l.portionsLeft <= 1) return FoodLabel.hampirHabis;
  if (l.provider.tier == Tier.pahlawanPangan) return FoodLabel.populer;
  final cooked = l.cookedAt;
  if (cooked != null && now.difference(cooked).inMinutes <= newListingMinutes) return FoodLabel.terbaru;
  return null;
}
