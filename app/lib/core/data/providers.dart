import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_data.dart';
import '../models/listing.dart';
import '../models/person.dart';
import '../models/recipe.dart';
import '../services/cloud_food_validator.dart';
import '../services/food_validator.dart';
import '../services/fyp.dart';
import '../services/recipe_ideas.dart';

/// Mock data loaded at startup (overridden in main.dart and in tests).
final mockDataProvider = Provider<MockData>((ref) => throw UnimplementedError('mockDataProvider must be overridden'));

/// Everyone the user can meet in listings and chats, by id.
final peopleProvider = Provider<Map<String, Person>>((ref) => ref.watch(mockDataProvider).people);

/// Injectable clock so time-dependent rules (pickup deadlines, "Sedang hangat") are testable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final randomProvider = Provider<Random>((ref) => Random());

/// How long the simulated counterpart takes to answer in chat.
final simulatedReplyDelayProvider = Provider<Duration>((ref) => const Duration(milliseconds: 1500));

/// How long the simulated provider takes to answer an offer (B10j "Menunggu jawaban"): long enough to tap
/// "Batalkan tawaran" while waiting. Plain chat replies keep [simulatedReplyDelayProvider].
final simulatedOfferDelayProvider = Provider<Duration>((ref) => const Duration(seconds: 8));

/// How long the simulated QR scan takes: the receiver's camera finding the code (B10b), and the mock receiver
/// scanning the provider's QR (C17).
final simulatedScanDelayProvider = Provider<Duration>((ref) => const Duration(milliseconds: 2500));

/// Demo switch for the simulated AI validator (long-press the camera title).
final demoAiModeProvider = StateProvider<DemoAiMode>((ref) => DemoAiMode.normal);

/// Base URL of the validation server (app/server), from `--dart-define=PAWON_VALIDATOR_URL=...`. Empty keeps the
/// simulated validator. The optional `PAWON_CLIENT_TOKEN` is a weak shared gate, not a secret.
const validatorUrl = String.fromEnvironment('PAWON_VALIDATOR_URL');
const validatorClientToken = String.fromEnvironment('PAWON_CLIENT_TOKEN');

/// Whether photos go to the cloud validator (Qwen behind app/server) instead of the simulation.
final cloudValidatorProvider = Provider<bool>((ref) => validatorUrl.isNotEmpty);

final foodValidatorProvider = Provider<FoodValidator>(
  (ref) => ref.watch(cloudValidatorProvider)
      ? CloudFoodValidator.fromBaseUrl(validatorUrl, clientToken: validatorClientToken)
      : SimulatedFoodValidator(mode: () => ref.read(demoAiModeProvider)),
);

/// Base URL of the FYP recommender (ml/fyp), from `--dart-define=PAWON_FYP_URL=...`. Empty: no recommender, the
/// feed ranks by distance and urgency only and no events are sent.
const fypUrl = String.fromEnvironment('PAWON_FYP_URL');

final fypClientProvider = Provider<FypClient?>((ref) => fypUrl.isEmpty ? null : FypClient(fypUrl));

/// The demo user's ranking from the recommender: item id → position (0 = best). Empty when there is no server or it
/// cannot be reached, so the feed never waits on it.
final fypRankingProvider = FutureProvider<Map<String, int>>((ref) async {
  final client = ref.watch(fypClientProvider);
  if (client == null) return const {};
  try {
    final items = await client.recommend(fypDemoUser);
    return {for (var i = 0; i < items.length; i++) items[i]: i};
  } on Object {
    return const {};
  }
});

/// Tells the recommender what the user did with a listing ("view", "addtocart", "transaction"). Does nothing without
/// a server, or for a listing the model does not know.
final fypEventsProvider = Provider<void Function(Listing listing, FypEvent event)>((ref) {
  final client = ref.watch(fypClientProvider);
  return (listing, event) {
    final item = listing.fypItem;
    if (client == null || item == null) return;
    unawaited(client.event(fypDemoUser, item, event));
  };
});

/// Local recipe library for fresh ingredients ("Ide resep").
final recipesProvider = Provider<List<Recipe>>((ref) => ref.watch(mockDataProvider).recipes);

/// AI recipe ideas from the same server as the photo check; null when it is not configured (local library only).
final recipeIdeasProvider = Provider<RecipeIdeas?>(
  (ref) => ref.watch(cloudValidatorProvider) ? CloudRecipeIdeas.fromBaseUrl(validatorUrl, clientToken: validatorClientToken) : null,
);
