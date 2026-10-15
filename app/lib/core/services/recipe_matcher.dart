import '../models/recipe.dart';

/// A recipe and the ingredient words of the listing it matched.
class RecipeMatch {
  const RecipeMatch(this.recipe, this.matched);
  final Recipe recipe;
  final List<String> matched;
}

/// Other words people write for the same ingredient, mapped to the keyword used in recipes.json.
const Map<String, String> ingredientSynonyms = {
  'kubis': 'kol',
  'cabe': 'cabai',
  'lombok': 'cabai',
  'brambang': 'bawang merah',
  'kacang lanjaran': 'kacang panjang',
  'jipang': 'labu siam',
  'tomato': 'tomat',
  'wortel import': 'wortel',
};

String _normalize(String text) {
  var t = ' ${text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ')} ';
  for (final e in ingredientSynonyms.entries) {
    t = t.replaceAll(' ${e.key} ', ' ${e.value} ');
  }
  return t;
}

/// Recipes from [library] that use ingredients named in [text] (a listing's name and description). Most matched
/// ingredients first, then the best-fitting and quickest; at most [limit]. Empty when nothing matches.
List<RecipeMatch> suggestRecipes(String text, List<Recipe> library, {int limit = 3}) {
  final t = _normalize(text);
  final matches = <RecipeMatch>[
    for (final r in library)
      if (r.keywords.where((k) => t.contains(' $k ')).toList() case final hit when hit.isNotEmpty) RecipeMatch(r, hit),
  ];
  matches.sort((a, b) {
    final byCount = b.matched.length.compareTo(a.matched.length);
    if (byCount != 0) return byCount;
    // Same count: the recipe built mostly from these ingredients beats one that needs many more, then the quickest.
    final byShare = (b.matched.length / b.recipe.keywords.length).compareTo(a.matched.length / a.recipe.keywords.length);
    return byShare != 0 ? byShare : a.recipe.minutes.compareTo(b.recipe.minutes);
  });
  return matches.take(limit).toList();
}
