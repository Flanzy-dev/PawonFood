import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawonfood/core/data/listings_repository.dart';
import 'package:pawonfood/core/data/providers.dart';
import 'package:pawonfood/core/models/listing.dart';
import 'package:pawonfood/core/services/fyp.dart';
import 'package:pawonfood/core/theme/app_theme.dart';
import 'package:pawonfood/features/listing/listing_detail_screen.dart';

import 'support.dart';

void main() {
  setUpAll(loadAppFonts);

  group('FypClient', () {
    test('asks /recommend for the user and returns the items best first', () async {
      late http.Request seen;
      final client = FypClient('http://127.0.0.1:8000', client: MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode({'user_id': 'u0', 'tipe': 'personal', 'items': ['i106', 'i101', 'i1']}), 200);
      }));
      expect(await client.recommend('u0'), ['i106', 'i101', 'i1']);
      expect(seen.url.path, '/recommend');
      expect(seen.url.queryParameters, {'user_id': 'u0', 'n': '$fypRankAll'});
    });

    test('posts an event as JSON and never throws', () async {
      late http.Request seen;
      final ok = FypClient('http://127.0.0.1:8000/', client: MockClient((req) async {
        seen = req;
        return http.Response('{"status":"tercatat"}', 200);
      }));
      await ok.event('u0', 'i1', FypEvent.view);
      expect(seen.method, 'POST');
      expect(seen.url.path, '/event');
      expect(jsonDecode(seen.body), {'user_id': 'u0', 'item_id': 'i1', 'event': 'view'});

      final down = FypClient('http://127.0.0.1:8000', client: MockClient((_) async => throw http.ClientException('offline')));
      await down.event('u0', 'i1', FypEvent.transaction); // no exception
    });

    test('a server error or a strange answer throws, and the ranking is then empty', () async {
      final broken = FypClient('http://x', client: MockClient((_) async => http.Response('{"detail":"boom"}', 500)));
      await expectLater(broken.recommend('u0'), throwsA(isA<http.ClientException>()));
      final odd = FypClient('http://x', client: MockClient((_) async => http.Response('{"items":"no"}', 200)));
      await expectLater(odd.recommend('u0'), throwsFormatException);

      final c = ProviderContainer(overrides: [...testOverrides(), fypClientProvider.overrideWithValue(broken)]);
      addTearDown(c.dispose);
      expect(await c.read(fypRankingProvider.future), isEmpty);
    });
  });

  group('affinity', () {
    test('runs from 1 for the best item down to 0.2 for the last, never 0', () {
      expect(affinityFromRank(0, 200), 1);
      expect(affinityFromRank(199, 200), closeTo(0.2, 1e-9));
      expect(affinityFromRank(500, 200), closeTo(0.2, 1e-9));
      expect(affinityFromRank(0, 1), 1);
    });

    test('no ranking: everyone counts the same; ranked: by position; unknown to the model: neutral', () {
      final l = loadMockData().listings.firstWhere((l) => l.id == 'l_ayam'); // fypItem i1
      expect(affinityOf(l, const {}), 1);
      expect(affinityOf(l, const {'i1': 0, 'i2': 1}), 1);
      expect(affinityOf(l, const {'i2': 0, 'i1': 1}), closeTo(0.2, 1e-9));
      expect(affinityOf(l, const {'i2': 0, 'i3': 1}), neutralAffinity);
    });
  });

  test('the Beranda feed follows the recommender: the same listing scores higher when the model ranks it first', () async {
    Future<double> scoreOf(String id, Map<String, int> ranking) async {
      final c = ProviderContainer(overrides: [...testOverrides(), fypRankingProvider.overrideWith((ref) async => ranking)]);
      addTearDown(c.dispose);
      await c.read(fypRankingProvider.future);
      return c.read(feedProvider).firstWhere((i) => i.listing.id == id).score;
    }

    final items = [for (final l in loadMockData().listings) if (l.fypItem != null) l.fypItem!];
    final ayamFirst = {for (final (i, item) in (['i1', ...items.where((x) => x != 'i1')]).indexed) item: i};
    final ayamLast = {for (final (i, item) in ([...items.where((x) => x != 'i1'), 'i1']).indexed) item: i};
    expect(await scoreOf('l_ayam', ayamFirst), greaterThan(await scoreOf('l_ayam', ayamLast)));
  });

  testWidgets('the food detail tells the recommender "view" only after 3 seconds', (tester) async {
    usePhoneScreen(tester);
    final events = <(String, FypEvent)>[];
    final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => const ListingDetailScreen(listingId: 'l_ayam'))]);
    await tester.pumpWidget(ProviderScope(
      overrides: [...testOverrides(), fypEventsProvider.overrideWithValue((Listing l, FypEvent e) => events.add((l.id, e)))],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(events, isEmpty, reason: 'a quick look is not a view');
    await tester.pump(const Duration(seconds: 2));
    expect(events, [('l_ayam', FypEvent.view)]);
  });
}
