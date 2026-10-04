/// Domain enums shared across features (names follow ARCHITECTURE.md).
enum UserRole { receiver, provider }

enum FoodCategory {
  makananMatang('makanan_matang', 'Lauk matang'),
  bahanMentah('bahan_mentah', 'Bahan mentah');

  const FoodCategory(this.key, this.label);
  final String key;
  final String label;

  static FoodCategory fromKey(String key) => values.firstWhere((c) => c.key == key, orElse: () => makananMatang);
}

enum Tier {
  sobatPawon('Sobat Pawon', 0),
  foodSavior('Food Savior', 500),
  pahlawanPangan('Pahlawan Pangan', 1500);

  const Tier(this.label, this.minPoints);
  final String label;
  final int minPoints;

  static Tier fromKey(String key) => values.firstWhere((t) => t.name == key, orElse: () => sobatPawon);
}

enum AiStatus { approved, pendingReview, rejected }

enum ListingStatus { available, reserved, pickedUp, expired, habis }

enum OfferStatus { pending, accepted, rejected }

enum MessageType { text, offer, system }

enum PickupStatus { waiting, pickedUp, cancelled }

/// Background tone of an initials avatar.
enum AvatarTone { primary, olive, taupe }
