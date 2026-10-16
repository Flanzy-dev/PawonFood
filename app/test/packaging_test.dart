import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawonfood/core/data/chat_repository.dart';
import 'package:pawonfood/core/data/listings_repository.dart';
import 'package:pawonfood/core/data/session_repository.dart';
import 'package:pawonfood/core/models/enums.dart';
import 'package:pawonfood/core/theme/app_theme.dart';
import 'package:pawonfood/core/widgets/food_card.dart';
import 'package:pawonfood/core/widgets/pills.dart';
import 'package:pawonfood/features/chat/chat_screen.dart';
import 'package:pawonfood/features/listing/listing_detail_screen.dart';
import 'package:pawonfood/features/map/map_screen.dart';
import 'package:pawonfood/features/pickup/route_screen.dart';

import 'support.dart';

/// "Kemasan": already wrapped, or the receiver brings a container.
ProviderContainer signedIn() {
  final c = makeContainer();
  c.read(sessionProvider.notifier).login('rafi@email.com');
  return c;
}

PublishDraft draft({Packaging packaging = Packaging.dibungkus, FoodCategory category = FoodCategory.makananMatang, int? deliveryFee}) => PublishDraft(
      name: 'Sayur lodeh',
      category: category,
      portions: 2,
      price: 0,
      negotiable: false,
      pickupBy: fixedNow.add(const Duration(hours: 2)),
      pickupPoint: 'Kos Melati, Pogung',
      packaging: packaging,
      deliveryFee: deliveryFee,
    );

void main() {
  group('data', () {
    test('mock listings are wrapped unless they say otherwise', () {
      final byId = {for (final l in loadMockData().listings) l.id: l};
      expect(byId['l_ayam']!.packaging, Packaging.dibungkus);
      for (final id in ['l_lodeh', 'l_lodeh2', 'l_sayur']) {
        expect(byId[id]!.bringsContainer, isTrue, reason: id);
        expect(byId[id]!.canDeliver, isFalse, reason: "$id: food in the receiver's own container is not delivered");
      }
    });

    test('unknown or missing keys fall back to wrapped', () {
      expect(Packaging.fromKey(null), Packaging.dibungkus);
      expect(Packaging.fromKey('wadah_sendiri'), Packaging.wadahSendiri);
      expect(Packaging.fromKey('???'), Packaging.dibungkus);
    });
  });

  group('publishing', () {
    test('"Bawa wadah sendiri" is kept, and can not be delivered', () {
      final notifier = signedIn().read(listingsProvider.notifier);
      final ok = notifier.publish(draft(packaging: Packaging.wadahSendiri)).listing!;
      expect(ok.packaging, Packaging.wadahSendiri);
      expect(notifier.publish(draft(packaging: Packaging.wadahSendiri, deliveryFee: 2000)).error, 'Antar hanya untuk makanan yang sudah dibungkus.');
      expect(notifier.publish(draft(deliveryFee: 2000)).listing!.canDeliver, isTrue, reason: 'wrapped food can');
    });

    test('sealed food is always wrapped', () {
      final l = signedIn().read(listingsProvider.notifier).publish(draft(packaging: Packaging.wadahSendiri, category: FoodCategory.sealedFood)).listing!;
      expect(l.packaging, Packaging.dibungkus);
    });
  });

  group('"Sudah dibungkus" filter', () {
    test('keeps only wrapped listings on the feed and the map, and is off by default', () {
      final c = signedIn();
      c.read(feedFiltersProvider.notifier).state = {};
      expect(c.read(feedProvider).any((i) => i.listing.bringsContainer), isTrue);
      expect(c.read(mapListingsProvider).any((i) => i.listing.bringsContainer), isTrue);

      c.read(feedFiltersProvider.notifier).state = {FeedFilter.packed};
      expect(c.read(feedProvider), isNotEmpty);
      expect(c.read(feedProvider).every((i) => !i.listing.bringsContainer), isTrue);
      expect(c.read(mapListingsProvider).every((i) => !i.listing.bringsContainer), isTrue);
    });
  });

  group('screens', () {
    Future<void> openDetail(WidgetTester tester, String id) async {
      usePhoneScreen(tester);
      final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => ListingDetailScreen(listingId: id))]);
      final c = ProviderContainer(overrides: testOverrides());
      addTearDown(c.dispose);
      c.read(sessionProvider.notifier).login('rafi@email.com');
      await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router)));
      await tester.pumpAndSettle();
    }

    testWidgets('the detail says how the food is handed over', (tester) async {
      await openDetail(tester, 'l_lodeh');
      expect(find.text('Bawa wadah sendiri'), findsOneWidget);
      expect(find.text('Siapkan wadah bersih untuk makanan ini'), findsOneWidget);
    });

    testWidgets('a wrapped listing says "Sudah dibungkus"', (tester) async {
      await openDetail(tester, 'l_ayam');
      expect(find.text('Sudah dibungkus'), findsOneWidget);
      expect(find.text('Bisa langsung dibawa pulang'), findsOneWidget);
    });

    testWidgets('after the reservation, the chat card and the route remind the receiver to bring a container', (tester) async {
      usePhoneScreen(tester);
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).login('rafi@email.com');
      final id = container.read(chatProvider.notifier).claim('l_lodeh');
      final router = GoRouter(initialLocation: '/chat/$id', routes: [
        GoRoute(path: '/chat/:id', builder: (_, s) => ChatScreen(conversationId: s.pathParameters['id']!)),
        GoRoute(path: '/route/:id', builder: (_, s) => RouteScreen(conversationId: s.pathParameters['id']!)),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router)));
      await tester.pumpAndSettle();
      expect(find.text('Bawa wadah sendiri · Siapkan wadah bersih untuk makanan ini'), findsOneWidget);

      router.go('/route/$id');
      await tester.pumpAndSettle();
      expect(find.text('Bawa wadah sendiri · Siapkan wadah bersih untuk makanan ini'), findsOneWidget);
    });

    testWidgets('only a "bawa wadah" card gets the container tag, and screen readers hear it', (tester) async {
      final handle = tester.ensureSemantics();
      final all = {for (final l in loadMockData().listings) l.id: l};
      Future<void> pumpCard(String id) async {
        await tester.pumpWidget(ProviderScope(
          overrides: testOverrides(),
          child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: FoodCard(listing: all[id]!, distance: 296, onTap: () {}))),
        ));
      }

      await pumpCard('l_lodeh');
      expect(find.byType(ContainerTag), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('bawa wadah sendiri')), findsWidgets);
      await pumpCard('l_ayam');
      expect(find.byType(ContainerTag), findsNothing);
      handle.dispose();
    });
  });
}
