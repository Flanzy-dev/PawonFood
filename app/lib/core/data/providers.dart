import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_data.dart';
import '../models/person.dart';
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

/// Demo switch for the simulated AI validator (long-press the camera title).
final demoAiModeProvider = StateProvider<DemoAiMode>((ref) => DemoAiMode.normal);

final foodValidatorProvider = Provider<FoodValidator>((ref) => SimulatedFoodValidator(mode: () => ref.read(demoAiModeProvider)));
