/// Domain enums shared across features (names follow ARCHITECTURE.md).
enum UserRole { receiver, provider }

enum FoodCategory {
  makananMatang('makanan_matang', 'Lauk matang', 'Makanan matang', 'Lauk, nasi, jajanan siap makan', 'Ready-to-Eat'),
  bahanMentah('bahan_mentah', 'Bahan mentah', 'Bahan mentah', 'Sayur, daging, bumbu', 'Fresh Ingredient'),
  sealedFood('makanan_kemasan', 'Makanan kemasan', 'Makanan kemasan', 'Roti, snack, minuman bersegel', 'Sealed Food');

  const FoodCategory(this.key, this.label, this.title, this.examples, this.chip);
  final String key;

  /// Tag on cards and the detail tile ("Lauk matang").
  final String label;

  /// Option title in the "Ubah kategori" sheet (C15c).
  final String title;
  final String examples;

  /// Beranda chip, intentionally English (PRD Core Feature 1).
  final String chip;

  static FoodCategory fromKey(String key) => values.firstWhere((c) => c.key == key, orElse: () => makananMatang);
}

/// What a dish contains or how it was cooked, tagged by the provider (the AI pre-fills what it can see).
/// Describes composition only: never a health or safety claim.
enum HealthTag {
  sayurBuah('sayur_buah', 'Sayur/buah'),
  protein('protein', 'Protein'),
  tidakDigoreng('tidak_digoreng', 'Tidak digoreng'),
  rendahGula('rendah_gula', 'Rendah gula');

  const HealthTag(this.key, this.label);
  final String key;
  final String label;

  static HealthTag? tryKey(Object? key) => values.where((t) => t.key == key).firstOrNull;

  /// Reads a JSON list of keys; unknown keys are skipped.
  static Set<HealthTag> parseList(Object? keys) => {
        if (keys is List)
          for (final k in keys) ?tryKey(k),
      };
}

enum Tier {
  // Display names follow the lo-fi D17 (user's choice, 2026-10-08); the keys stay as in the mock data.
  sobatPawon('Pawon Friend', 0),
  foodSavior('Pawon Elite', 500),
  pahlawanPangan('Pawon Hero', 1500);

  const Tier(this.label, this.minPoints);
  final String label;
  final int minPoints;

  static Tier fromKey(String key) => values.firstWhere((t) => t.name == key, orElse: () => sobatPawon);
}

enum AiStatus { approved, pendingReview, rejected }

enum ListingStatus { available, reserved, pickedUp, expired, habis }

enum OfferStatus { pending, accepted, rejected, cancelled }

enum MessageType { text, offer, system }

/// A reservation: held until the pickup deadline, closed by the receiver scanning the provider's QR.
enum PickupStatus { reserved, pickedUp, expired, cancelled }

/// How the receiver pays a paid listing (PRD Core Feature 6). Free listings have none.
enum PayMethod {
  cash('Tunai di tempat'),
  qris('QRIS');

  const PayMethod(this.label);
  final String label;
}

/// Background tone of an initials avatar.
enum AvatarTone { primary, olive, taupe }
