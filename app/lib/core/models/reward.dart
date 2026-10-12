/// Reward group shown as a filter chip on Tukar poin.
enum RewardCategory {
  belanja('belanja', 'Belanja'),
  antar('antar', 'Antar'),
  sertifikat('sertifikat', 'Sertifikat'),
  makanan('makanan', 'Makanan');

  const RewardCategory(this.key, this.label);
  final String key;
  final String label;

  static RewardCategory fromKey(String key) => values.firstWhere((c) => c.key == key, orElse: () => belanja);
}

class Reward {
  const Reward({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tile,
    required this.cost,
    required this.tone,
    this.category = RewardCategory.belanja,
    this.shortTitle,
    this.validDays = 30,
    this.foodDiscount = 0,
  });

  final String id;
  final String title;
  final String subtitle;

  /// Short label drawn inside the reward icon tile ("Rp", "Ojek", "Hijau").
  final String tile;

  /// Cost in points; 0 means the reward is not bought with points (monthly certificate).
  final int cost;

  /// `sand`, `tint` or `green` (icon tile style).
  final String tone;
  final RewardCategory category;

  /// Shorter title for the square card (two lines); falls back to [title].
  final String? shortTitle;

  /// How many days a claimed voucher stays valid.
  final int validDays;

  /// Rupiah taken off the food price when the voucher is used on Pembayaran; 0 for partner vouchers (minimarket, ojek...).
  final int foodDiscount;

  /// A voucher for the food itself, used at checkout in the app (not shown to a partner).
  bool get isFoodVoucher => foodDiscount > 0;

  String get cardTitle => shortTitle ?? title;

  /// Vouchers are bought with points; the certificate (cost 0) is issued monthly instead.
  bool get claimable => cost > 0;

  factory Reward.fromJson(Map<String, dynamic> j) => Reward(
        id: j['id'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        tile: j['tile'] as String,
        cost: (j['cost'] as num).toInt(),
        tone: (j['tone'] ?? 'sand') as String,
        category: RewardCategory.fromKey((j['category'] ?? 'belanja') as String),
        shortTitle: j['shortTitle'] as String?,
        validDays: (j['validDays'] as num?)?.toInt() ?? 30,
        foodDiscount: (j['foodDiscount'] as num?)?.toInt() ?? 0,
      );
}
