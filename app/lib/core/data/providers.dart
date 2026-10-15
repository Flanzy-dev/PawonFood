import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_data.dart';
import '../models/person.dart';
import '../services/cloud_food_validator.dart';
import '../services/food_validator.dart';

/// Mock data loaded at startup (overridden in main.dart and in tests).
final mockDataProvider = Provider<MockData>((ref) => throw UnimplementedError('mockDataProvider must be overridden'));

/// Everyone the user can meet in listings and chats, by id.
final peopleProvider = Provider<Map<String, Person>>((ref) => ref.watch(mockDataProvider).people);

/// Injectable clock so time-dependent rules (pickup deadlines, "Sedang hangat") are testable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final randomProvider = Provider<Random>((ref) => Random());

/// How long the simulated counterpart takes to answer in chat.
final simulatedReplyDelayProvider = Provider<Duration>((ref) => const Duration(milliseconds: 1500));

/// How long the simulated QR scan takes: the receiver's camera finding the code (B10b), and the mock receiver
/// scanning the provider's QR (C17).
final simulatedScanDelayProvider = Provider<Duration>((ref) => const Duration(milliseconds: 2500));

/// Demo switch for the simulated AI validator (long-press the camera title).
final demoAiModeProvider = StateProvider<DemoAiMode>((ref) => DemoAiMode.normal);

/// Base URL of the validation server (app/server), from `--dart-define=PAWON_VALIDATOR_URL=...`. Empty keeps the
/// simulated validator. The optional `PAWON_CLIENT_TOKEN` is a weak shared gate, not a secret.
const validatorUrl = String.fromEnvironment('PAWON_VALIDATOR_URL');
const validatorClientToken = String.fromEnvironment('PAWON_CLIENT_TOKEN');

/// Whether photos go to the cloud validator. The camera then shows no simulated live detection.
final cloudValidatorProvider = Provider<bool>((ref) => validatorUrl.isNotEmpty);

final foodValidatorProvider = Provider<FoodValidator>(
  (ref) => ref.watch(cloudValidatorProvider)
      ? CloudFoodValidator.fromBaseUrl(validatorUrl, clientToken: validatorClientToken)
      : SimulatedFoodValidator(mode: () => ref.read(demoAiModeProvider)),
);
