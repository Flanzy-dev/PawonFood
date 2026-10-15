import 'enums.dart';

/// Another user as seen in listings and chats (provider or receiver).
class Person {
  const Person({required this.id, required this.name, required this.tier, this.rating = 0, this.tone = AvatarTone.primary});

  final String id;
  final String name;
  final Tier tier;
  final double rating;
  final AvatarTone tone;

  /// Two letters: first and last word, ignoring a leading venue word when a person's name follows
  /// ("Warteg Bu Siti" -> BS, "Bu Kos Wulan" -> BW, "Warmindo Barokah" -> WB).
  String get initials {
    const venues = {'Warteg', 'Warung', 'Warmindo', 'Katering', 'Kos'};
    var words = name.split(RegExp(r'[\s,]+')).where((p) => p.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length > 2 && venues.contains(words.first)) words = words.sublist(1);
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(1, 2)).toUpperCase();
    return (words.first[0] + words.last[0]).toUpperCase();
  }

  factory Person.fromJson(Map<String, dynamic> j) => Person(
        id: j['id'] as String,
        name: j['name'] as String,
        tier: Tier.fromKey(j['tier'] as String),
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        tone: AvatarTone.values.firstWhere((t) => t.name == (j['tone'] ?? 'primary'), orElse: () => AvatarTone.primary),
      );
}
