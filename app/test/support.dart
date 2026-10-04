import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawonfood/app.dart';
import 'package:pawonfood/core/data/providers.dart';
import 'package:pawonfood/core/mock/mock_data.dart';
import 'package:pawonfood/core/widgets/pawon_map.dart';

/// All mock times are relative to this moment, so tests are deterministic.
final fixedNow = DateTime(2026, 10, 3, 20, 0);

MockData loadMockData([DateTime? now]) {
  dynamic read(String name) => json.decode(File('assets/mock/$name.json').readAsStringSync());
  return MockData.fromJson(
    user: read('user') as Map<String, dynamic>,
    people: read('people') as List<dynamic>,
    listings: read('listings') as List<dynamic>,
    conversations: read('conversations') as List<dynamic>,
    rewards: read('rewards') as List<dynamic>,
    now: now ?? fixedNow,
  );
}

List<Override> testOverrides() => [
      mockDataProvider.overrideWithValue(loadMockData()),
      clockProvider.overrideWithValue(() => fixedNow),
      simulatedReplyDelayProvider.overrideWithValue(Duration.zero),
      randomProvider.overrideWithValue(Random(7)),
      tilesEnabledProvider.overrideWithValue(false),
    ];

ProviderContainer makeContainer() {
  final c = ProviderContainer(overrides: testOverrides());
  addTearDown(c.dispose);
  return c;
}

/// Gives the test a 402 x 874 logical phone screen (the design frame).
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Widget appUnderTest() => ProviderScope(overrides: testOverrides(), child: const PawonApp());

/// Loads the app fonts (Inter, Bricolage Grotesque) so widget tests lay text out like the device; without this
/// flutter_test falls back to the very wide Ahem font and reports overflows that do not happen on a phone.
Future<void> loadAppFonts() async {
  for (final (family, asset) in const [('Inter', 'assets/fonts/Inter.ttf'), ('BricolageGrotesque', 'assets/fonts/BricolageGrotesque.ttf')]) {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }
}
