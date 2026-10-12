import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawonfood/app.dart';
import 'package:pawonfood/core/data/onboarding_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

/// The app with real (mocked) device storage, so the first-launch onboarding is active.
Future<SharedPreferences> openApp(WidgetTester tester, [Map<String, Object> stored = const {}]) async {
  usePhoneScreen(tester);
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(overrides: [...testOverrides(), preferencesProvider.overrideWithValue(prefs)], child: const PawonApp()));
  await tester.pumpAndSettle();
  return prefs;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('first launch: three slides, Mulai opens Welcome and the intro is remembered', (tester) async {
    final prefs = await openApp(tester);
    expect(find.text('Bagikan makanan berlebih'), findsOneWidget);
    expect(find.text('Lewati'), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, 'Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Temukan makanan di dekatmu'), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, 'Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Ambil, pindai, dapat poin'), findsOneWidget);
    final skip = find.ancestor(of: find.text('Lewati'), matching: find.byType(AnimatedOpacity));
    expect(tester.widget<AnimatedOpacity>(skip).opacity, 0, reason: 'no Lewati on the last slide');
    expect(tester.widget<IgnorePointer>(find.ancestor(of: find.text('Lewati'), matching: find.byType(IgnorePointer)).first).ignoring, isTrue);

    await tester.tap(find.widgetWithText(InkWell, 'Mulai'));
    await tester.pumpAndSettle();
    expect(find.text('Sudah punya akun? Masuk'), findsOneWidget);
    expect(prefs.getBool('onboarding_seen'), isTrue);
  });

  testWidgets('Lewati skips straight to Welcome', (tester) async {
    final prefs = await openApp(tester);
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    expect(find.text('Sudah punya akun? Masuk'), findsOneWidget);
    expect(prefs.getBool('onboarding_seen'), isTrue);
  });

  testWidgets('once seen, the app opens on Welcome', (tester) async {
    await openApp(tester, {'onboarding_seen': true});
    expect(find.text('Bagikan makanan berlebih'), findsNothing);
    expect(find.text('Sudah punya akun? Masuk'), findsOneWidget);
  });
}
