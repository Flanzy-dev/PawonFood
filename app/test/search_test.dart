import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawonfood/app.dart';
import 'package:pawonfood/core/data/listings_repository.dart';
import 'package:pawonfood/core/data/onboarding_repository.dart';
import 'package:pawonfood/core/data/search_history_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

ProviderContainer containerWith(SharedPreferences? prefs) {
  final c = ProviderContainer(overrides: [...testOverrides(), if (prefs != null) preferencesProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUpAll(loadAppFonts);

  group('search history', () {
    test('newest first, one entry per word whatever the case, at most 8, blank ignored', () {
      final c = containerWith(null);
      final h = c.read(searchHistoryProvider.notifier);
      h.add('nasi');
      h.add('  ');
      h.add('roti');
      h.add('Nasi');
      expect(c.read(searchHistoryProvider), ['Nasi', 'roti']);
      for (var i = 0; i < 10; i++) {
        h.add('kata $i');
      }
      expect(c.read(searchHistoryProvider), hasLength(SearchHistoryNotifier.max));
      expect(c.read(searchHistoryProvider).first, 'kata 9');
    });

    test('remove and clear', () {
      final c = containerWith(null);
      final h = c.read(searchHistoryProvider.notifier)..add('nasi')..add('roti');
      h.remove('nasi');
      expect(c.read(searchHistoryProvider), ['roti']);
      h.clear();
      expect(c.read(searchHistoryProvider), isEmpty);
    });

    test('is kept on the device', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      containerWith(prefs).read(searchHistoryProvider.notifier).add('lodeh');
      expect(containerWith(prefs).read(searchHistoryProvider), ['lodeh']);
    });
  });

  group('popular words', () {
    test('only words that match a visible listing nearby, at most 6, most matches first', () {
      final c = makeContainer();
      final words = c.read(popularKeywordsProvider);
      expect(words, isNotEmpty);
      expect(words.length, lessThanOrEqualTo(6));
      final nearby = c.read(nearbyListingsProvider);
      for (final w in words) {
        expect(nearby.any((l) => matchesQuery(l, w.toLowerCase())), isTrue, reason: '$w has no listing');
      }
      int count(String w) => nearby.where((l) => matchesQuery(l, w.toLowerCase())).length;
      for (var i = 1; i < words.length; i++) {
        expect(count(words[i - 1]), greaterThanOrEqualTo(count(words[i])));
      }
    });
  });

  group('search page', () {
    Future<void> openSearch(WidgetTester tester) async {
      usePhoneScreen(tester);
      await signIn(tester);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping the bar opens a white page with the bar on top and the popular words', (tester) async {
      await openSearch(tester);
      expect(find.text('Populer di sekitarmu'), findsOneWidget);
      expect(find.byTooltip('Hapus dari riwayat'), findsNothing, reason: 'no history yet');
      expect(tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor, Colors.white);
      expect(tester.getTopLeft(find.byType(TextField)).dy, lessThan(120));
    });

    testWidgets('submitting a word filters Beranda, is remembered, and a history row applies it again', (tester) async {
      await openSearch(tester);
      await tester.enterText(find.byType(TextField), 'lodeh');
      await tester.pump();
      expect(find.text('Cari "lodeh"'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Populer di sekitarmu'), findsNothing, reason: 'back on Beranda');
      expect(find.text('lodeh'), findsOneWidget, reason: 'the bar shows the active word');
      final container = ProviderScope.containerOf(tester.element(find.byType(PawonApp)));
      expect(container.read(searchQueryProvider), 'lodeh');
      expect(container.read(searchHistoryProvider), ['lodeh']);

      await tester.tap(find.byTooltip('Hapus pencarian')); // the ✕ clears the filter without opening the page
      await tester.pumpAndSettle();
      expect(container.read(searchQueryProvider), '');
      expect(find.text('Populer di sekitarmu'), findsNothing);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('Pencarian terakhir'), findsOneWidget);
      await tester.tap(find.text('lodeh'));
      await tester.pumpAndSettle();
      expect(container.read(searchQueryProvider), 'lodeh');
    });

    testWidgets('back leaves the filter alone; Hapus semua and ✕ edit the history', (tester) async {
      await openSearch(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(PawonApp)));
      container.read(searchHistoryProvider.notifier)..add('nasi')..add('roti');
      await tester.pumpAndSettle();
      expect(find.text('Pencarian terakhir'), findsOneWidget);

      await tester.tap(find.byTooltip('Hapus dari riwayat').first); // "roti", the newest
      await tester.pumpAndSettle();
      expect(container.read(searchHistoryProvider), ['nasi']);
      await tester.tap(find.text('Hapus semua'));
      await tester.pumpAndSettle();
      expect(find.text('Pencarian terakhir'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Kembali'));
      await tester.pumpAndSettle();
      expect(container.read(searchQueryProvider), '');
      expect(find.text('Populer di sekitarmu'), findsNothing);
    });

    testWidgets('a popular word applies like a typed one', (tester) async {
      await openSearch(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(PawonApp)));
      final word = container.read(popularKeywordsProvider).first;
      await tester.tap(find.widgetWithText(InkWell, word));
      await tester.pumpAndSettle();
      expect(container.read(searchQueryProvider), word);
      expect(container.read(feedProvider), isNotEmpty);
    });
  });
}
