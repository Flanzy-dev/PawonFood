import 'enums.dart';

/// A simple recipe idea for fresh ingredients: from the local library (assets/mock/recipes.json) or from the AI
/// (app/server `/v1/recipe-ideas`).
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.minutes,
    required this.ingredients,
    required this.steps,
    this.servings = 2,
    this.keywords = const [],
    this.healthTags = const {},
    this.fromAi = false,
  });

  final String id;
  final String title;
  final int minutes;
  final int servings;

  /// Lower-case ingredient words the matcher looks for in a listing ("wortel", "kol").
  final List<String> keywords;

  /// "Bahan" lines shown in the recipe sheet.
  final List<String> ingredients;

  /// "Cara masak" steps, in order.
  final List<String> steps;
  final Set<HealthTag> healthTags;

  /// Suggested by the AI instead of the curated library.
  final bool fromAi;

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as String,
        title: j['title'] as String,
        minutes: (j['minutes'] as num).toInt(),
        servings: (j['servings'] as num?)?.toInt() ?? 2,
        keywords: [for (final k in (j['keywords'] as List<dynamic>? ?? const [])) (k as String).toLowerCase()],
        ingredients: (j['ingredients'] as List<dynamic>).cast<String>(),
        steps: (j['steps'] as List<dynamic>).cast<String>(),
        healthTags: HealthTag.parseList(j['healthTags']),
      );
}
