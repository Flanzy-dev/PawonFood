import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/recipe.dart';

/// Recipe ideas from the AI for fresh ingredients ("Minta ide dari AI"). Optional: the local library in
/// recipes.json always works on its own.
abstract class RecipeIdeas {
  /// Throws [RecipeIdeasUnavailable] when no answer could be read.
  Future<List<Recipe>> suggest(String ingredients);
}

class RecipeIdeasUnavailable implements Exception {
  const RecipeIdeasUnavailable();
}

/// Asks app/server `POST /v1/recipe-ideas`. The server validates the model's answer and drops health claims.
class CloudRecipeIdeas implements RecipeIdeas {
  CloudRecipeIdeas({required this.endpoint, http.Client? client, this.clientToken = '', this.timeout = const Duration(seconds: 25)})
      : _client = client ?? http.Client();

  factory CloudRecipeIdeas.fromBaseUrl(String baseUrl, {String clientToken = ''}) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return CloudRecipeIdeas(endpoint: Uri.parse('$base/v1/recipe-ideas'), clientToken: clientToken);
  }

  final Uri endpoint;
  final String clientToken;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<List<Recipe>> suggest(String ingredients) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json', if (clientToken.isNotEmpty) 'X-Pawon-Client': clientToken},
            body: jsonEncode({'ingredients': ingredients}),
          )
          .timeout(timeout);
    } on Object {
      throw const RecipeIdeasUnavailable();
    }
    if (res.statusCode != 200) throw const RecipeIdeasUnavailable();
    try {
      return parseRecipeIdeas(jsonDecode(utf8.decode(res.bodyBytes)));
    } on FormatException {
      throw const RecipeIdeasUnavailable();
    }
  }
}

/// Reads `{recipes: [{title, minutes, ingredients, steps}]}`. Anything off is a [FormatException].
List<Recipe> parseRecipeIdeas(Object? json) {
  if (json is! Map<String, dynamic> || json['recipes'] is! List) throw const FormatException('recipes is missing');
  List<String> texts(Object? v) {
    if (v is! List || v.isEmpty || v.any((e) => e is! String)) throw const FormatException('expected a list of text');
    return v.cast<String>();
  }

  return [
    for (final (i, r) in (json['recipes'] as List).indexed)
      if (r is Map<String, dynamic> && r['title'] is String && r['minutes'] is num)
        Recipe(
          id: 'ai_${i}_${(r['title'] as String).hashCode}',
          title: r['title'] as String,
          minutes: (r['minutes'] as num).round(),
          ingredients: texts(r['ingredients']),
          steps: texts(r['steps']),
          fromAi: true,
        )
      else
        throw const FormatException('recipe has the wrong shape'),
  ];
}
