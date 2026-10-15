import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

// "Pilihan untukmu": the FYP recommender in ml/fyp (a trained ALS model behind a small FastAPI server). It ranks the
// items for a user (GET /recommend) and logs what users do (POST /event) for the next training run.

/// The demo account's user in the FYP model. The model was trained on another dataset (users u0..u499, items
/// i0..i199); until it is retrained with PawonFood events, the demo account borrows u0 and the mock listings carry a
/// demo item id ([Listing.fypItem]).
const fypDemoUser = 'u0';

/// How many recommendations to ask for: the model knows 200 items, so this ranks every one of them.
const fypRankAll = 200;

/// Affinity of a listing the model does not rank (published in the app, or unknown to it): the middle of the road.
const neutralAffinity = 0.6;

/// How long the food detail must stay open before it counts as a "view" (PRD: more than 3 seconds).
const fypViewAfter = Duration(seconds: 3);

/// What the user did with a listing, named as the FYP server expects it.
enum FypEvent { view, addtocart, transaction }

/// Affinity 0.2..1 from a position in the model's list (0 = best). Never 0, so the model alone cannot bury a listing.
double affinityFromRank(int rank, int count) => count <= 1 ? 1.0 : 0.2 + 0.8 * (1 - rank.clamp(0, count - 1) / (count - 1));

class FypClient {
  FypClient(String baseUrl, {http.Client? client, this.timeout = const Duration(seconds: 5)})
      : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _client = client ?? http.Client();

  final Uri _base;
  final http.Client _client;
  final Duration timeout;

  /// Item ids for [userId], best first. Throws when the server cannot be reached or answers something unexpected.
  Future<List<String>> recommend(String userId, {int n = fypRankAll}) async {
    final res = await _client.get(_base.resolve('recommend').replace(queryParameters: {'user_id': userId, 'n': '$n'})).timeout(timeout);
    if (res.statusCode != 200) throw http.ClientException('recommend answered ${res.statusCode}');
    final json = jsonDecode(utf8.decode(res.bodyBytes));
    final items = json is Map ? json['items'] : null;
    if (items is! List) throw const FormatException('no items');
    return [for (final i in items) if (i is String) i];
  }

  /// Logs one action. Best effort: it never throws, the app must not depend on it.
  Future<void> event(String userId, String itemId, FypEvent e) async {
    try {
      await _client
          .post(_base.resolve('event'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'item_id': itemId, 'event': e.name}))
          .timeout(timeout);
    } on Object {
      // offline or server down: the event is lost, nothing else changes
    }
  }
}
