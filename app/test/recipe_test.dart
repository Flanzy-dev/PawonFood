import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawonfood/core/data/listings_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawonfood/core/models/enums.dart';
import 'package:pawonfood/core/models/recipe.dart';
import 'package:pawonfood/core/services/recipe_ideas.dart';
import 'package:pawonfood/core/services/recipe_matcher.dart';
import 'package:pawonfood/features/listing/recipe_sheet.dart';

import 'support.dart';

void main() {
  final data = loadMockData();
  final library = data.recipes;

  group('library', () {
    test('every recipe has ingredients, steps and keywords', () {
      expect(library.length, greaterThanOrEqualTo(8));
      for (final r in library) {
        expect(r.ingredients, isNotEmpty, reason: r.id);
        expect(r.steps, isNotEmpty, reason: r.id);
        expect(r.keywords, isNotEmpty, reason: r.id);
        expect(r.fromAi, isFalse);
      }
    });

    test('mock listings resolve their recipeId', () {
      expect(data.listings.firstWhere((l) => l.id == 'l_sayur').recipe?.id, 'r_sup_wortel_kol');
      expect(data.listings.firstWhere((l) => l.id == 'l_sayur2').recipe, isNull, reason: 'no seller recipe: buyers get the unverified suggestion');
      expect(data.listings.where((l) => l.recipe != null).every((l) => l.category == FoodCategory.bahanMentah), isTrue);
    });

    test('Recipe.fromJson lower-cases keywords and reads health tags', () {
      final r = Recipe.fromJson({
        'id': 'x',
        'title': 'Sup',
        'minutes': 10,
        'keywords': ['Wortel'],
        'healthTags': ['sayur_buah', 'nope'],
        'ingredients': ['a'],
        'steps': ['b'],
      });
      expect(r.keywords, ['wortel']);
      expect(r.healthTags, {HealthTag.sayurBuah});
      expect(r.servings, 2);
    });
  });

  group('suggestRecipes', () {
    test('carrot and cabbage find recipes using both, the best-fitting one first', () {
      final m = suggestRecipes('Wortel & Kol, belum dipotong', library);
      expect(m.first.recipe.id, 'r_tumis_kol_wortel');
      expect(m.first.matched, containsAll(['wortel', 'kol']));
      expect(m.length, lessThanOrEqualTo(3));
    });

    test('synonyms count: kubis is kol', () {
      expect(suggestRecipes('Kubis segar', library).map((m) => m.recipe.id), contains('r_tumis_kol_wortel'));
    });

    test('a keyword must be a whole word', () {
      expect(suggestRecipes('Kolak pisang', library), isEmpty);
    });

    test('no ingredient, no recipe', () {
      expect(suggestRecipes('Roti Manis Kotakan', library), isEmpty);
      expect(suggestRecipes('', library), isEmpty);
    });
  });

  group('AI recipe ideas', () {
    test('a well-formed answer becomes Ide AI recipes', () {
      final r = parseRecipeIdeas({
        'recipes': [
          {'title': 'Tumis Kangkung', 'minutes': 10.0, 'ingredients': ['1 ikat kangkung'], 'steps': ['Tumis.']},
        ],
      });
      expect(r.single.fromAi, isTrue);
      expect(r.single.minutes, 10);
    });

    test('the client posts the ingredients with the token and parses the answer', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode({'recipes': [{'title': 'Sup', 'minutes': 12, 'ingredients': ['a'], 'steps': ['b']}]}), 200);
      });
      final ideas = CloudRecipeIdeas(endpoint: Uri.parse('https://x.test/v1/recipe-ideas'), client: client, clientToken: 'tok');
      expect((await ideas.suggest('wortel')).single.title, 'Sup');
      expect(seen.headers['X-Pawon-Client'], 'tok');
      expect(jsonDecode(seen.body), {'ingredients': 'wortel'});
      expect(CloudRecipeIdeas.fromBaseUrl('https://x.test/').endpoint.toString(), 'https://x.test/v1/recipe-ideas');
    });

    test('server errors and bad bodies are RecipeIdeasUnavailable', () async {
      for (final res in [http.Response('', 502), http.Response('not json', 200), http.Response('{"recipes": 1}', 200)]) {
        final ideas = CloudRecipeIdeas(endpoint: Uri.parse('https://x.test/v1/recipe-ideas'), client: MockClient((_) async => res));
        await expectLater(ideas.suggest('wortel'), throwsA(isA<RecipeIdeasUnavailable>()));
      }
    });

    test('anything off is a FormatException', () {
      expect(() => parseRecipeIdeas('x'), throwsFormatException);
      expect(() => parseRecipeIdeas({'recipes': 'x'}), throwsFormatException);
      expect(() => parseRecipeIdeas({'recipes': [{'title': 'x', 'minutes': 5, 'ingredients': [], 'steps': ['a']}]}), throwsFormatException);
      expect(() => parseRecipeIdeas({'recipes': [{'title': 'x'}]}), throwsFormatException);
    });
  });

  group('recipe sheet', () {
    testWidgets('lists ingredients and numbered steps with the reminder', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) => TextButton(onPressed: () => showRecipeSheet(context, library.first, verified: true), child: const Text('buka'))),
      ));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      expect(find.text(library.first.title), findsOneWidget);
      expect(find.text('Bahan'), findsOneWidget);
      expect(find.text('Cara masak'), findsOneWidget);
      expect(find.text('Resep hanya ide. Cek kondisi bahan sebelum dimasak.'), findsOneWidget);
      expect(find.text('Dicek dan dipilih oleh pemberi'), findsOneWidget);
    });

    testWidgets('an unverified suggestion says so instead of claiming the seller checked it', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) => TextButton(onPressed: () => showRecipeSheet(context, library.first, verified: false), child: const Text('buka'))),
      ));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      expect(find.text('Saran otomatis, belum dicek pemberi'), findsOneWidget);
      expect(find.text('Dicek dan dipilih oleh pemberi'), findsNothing);
    });
  });

  group('app flow', () {
    testWidgets('detail of fresh ingredients shows the attached recipe and the health tags', (tester) async {
      usePhoneScreen(tester);
      await signIn(tester);
      final list = find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.text('Wortel & Kol, belum dipotong'), 200, scrollable: list);
      await tester.drag(list, const Offset(0, -150)); // lift it clear of the bottom navigation bar
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wortel & Kol, belum dipotong'));
      await tester.pumpAndSettle();
      final detail = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Ide resep'), 200, scrollable: detail);
      expect(find.text('Pilihan sehat'), findsOneWidget);
      expect(find.text('Sayur/buah'), findsOneWidget);
      expect(find.textContaining('Diverifikasi pemberi'), findsOneWidget);
      await tester.tap(find.text('Sup Wortel Kol'));
      await tester.pumpAndSettle();
      expect(find.text('Cara masak'), findsOneWidget);
      expect(find.text('Dicek dan dipilih oleh pemberi'), findsOneWidget);
    });

    Future<void> openListing(WidgetTester tester, String id) async {
      unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/listing/$id'));
      await tester.pumpAndSettle();
    }

    testWidgets('without a seller recipe the buyer still gets a suggestion, labelled as not verified', (tester) async {
      usePhoneScreen(tester);
      await signIn(tester);
      await openListing(tester, 'l_sayur2'); // Sayur Campur dari Pasar: bayam, kacang panjang, tomat
      await tester.scrollUntilVisible(find.text('Ide resep'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Belum diverifikasi pemberi'), findsOneWidget);
      expect(find.textContaining('Diverifikasi pemberi'), findsNothing);
      await tester.tap(find.textContaining('Belum diverifikasi pemberi'));
      await tester.pumpAndSettle();
      expect(find.text('Saran otomatis, belum dicek pemberi'), findsOneWidget);
    });

    testWidgets('the seller does not get the recipe card on their own listing', (tester) async {
      usePhoneScreen(tester);
      await signIn(tester);
      final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
      final own = c.read(listingsProvider.notifier).publish(PublishDraft(
            name: 'Wortel dan kol',
            category: FoodCategory.bahanMentah,
            portions: 2,
            price: 0,
            negotiable: false,
            pickupBy: fixedNow.add(const Duration(hours: 2)),
            pickupPoint: 'Kos Melati, Pogung',
            recipe: library.first,
          ));
      expect(own.listing!.recipe, isNotNull);
      await openListing(tester, own.listing!.id);
      expect(find.text('Wortel dan kol'), findsWidgets);
      expect(find.text('Ide resep'), findsNothing);
      expect(find.textContaining('pemberi'), findsNothing);
    });
  });
}
