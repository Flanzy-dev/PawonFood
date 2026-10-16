import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawonfood/app.dart';
import 'package:pawonfood/core/data/providers.dart';
import 'package:latlong2/latlong.dart';
import 'package:pawonfood/core/mock/mock_data.dart';
import 'package:pawonfood/core/services/location_service.dart';
import 'package:pawonfood/core/services/route_service.dart';
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
    recipes: read('recipes') as List<dynamic>,
    now: now ?? fixedNow,
  );
}

List<Override> testOverrides({DeviceLocator locator = const NoGpsLocator(), RoutePlanner planner = const NoRoutePlanner()}) => [
      mockDataProvider.overrideWithValue(loadMockData()),
      clockProvider.overrideWithValue(() => fixedNow),
      simulatedReplyDelayProvider.overrideWithValue(Duration.zero),
      simulatedOfferDelayProvider.overrideWithValue(Duration.zero),
      simulatedScanDelayProvider.overrideWithValue(Duration.zero),
      randomProvider.overrideWithValue(Random(7)),
      tilesEnabledProvider.overrideWithValue(false),
      deviceLocatorProvider.overrideWithValue(locator),
      routePlannerProvider.overrideWithValue(planner),
    ];

/// Tests never call the routing server: by default no route is found and the estimate is shown.
class NoRoutePlanner implements RoutePlanner {
  const NoRoutePlanner();

  @override
  Future<WalkRoute?> walk(LatLng from, LatLng to) async => null;
}

/// Tests never touch the real GPS: by default the position cannot be read (the app then keeps the demo areas).
class NoGpsLocator implements DeviceLocator {
  const NoGpsLocator();

  @override
  Future<LocationFix> locate() async => const LocationProblem(LocationIssue.unavailable);
  @override
  Stream<LatLng> track() => const Stream.empty();
  @override
  Future<String?> placeName(LatLng p) async => null;
  @override
  Future<String?> address(LatLng p) async => null;
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> openLocationSettings() async {}
}

ProviderContainer makeContainer() {
  final c = ProviderContainer(overrides: testOverrides());
  addTearDown(c.dispose);
  return c;
}

/// Gives the test a 402 x 874 logical phone screen (the design frame), with the OS "remove animations" setting on so
/// looping motion (scan lines, pulses) stops and `pumpAndSettle` can settle.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  useReducedMotion(tester);
}

void useReducedMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Widget appUnderTest({DeviceLocator locator = const NoGpsLocator()}) => ProviderScope(overrides: testOverrides(locator: locator), child: const PawonApp());

/// Loads the app fonts (Inter, Bricolage Grotesque) so widget tests lay text out like the device; without this
/// flutter_test falls back to the very wide Ahem font and reports overflows that do not happen on a phone.
Future<void> loadAppFonts() async {
  for (final (family, asset) in const [('Inter', 'assets/fonts/Inter.ttf'), ('BricolageGrotesque', 'assets/fonts/BricolageGrotesque.ttf')]) {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }
}

/// Opens the app and signs in with the demo account (Beranda is showing afterwards).
Future<void> signIn(WidgetTester tester, {DeviceLocator locator = const NoGpsLocator()}) async {
  await tester.pumpWidget(appUnderTest(locator: locator));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sudah punya akun? Masuk'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), 'rafi@email.com');
  await tester.enterText(find.byType(TextField).at(1), 'rahasia123');
  await tester.tap(find.widgetWithText(InkWell, 'Masuk'));
  await tester.pumpAndSettle();
}
