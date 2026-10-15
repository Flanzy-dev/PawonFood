import 'package:flutter_test/flutter_test.dart';
import 'package:pawonfood/core/models/enums.dart';
import 'package:pawonfood/core/models/listing.dart';
import 'package:pawonfood/core/services/food_score.dart';

import 'support.dart';

void main() {
  final all = loadMockData().listings;
  Listing mock(String id) => all.firstWhere((l) => l.id == id);
  final lodeh = mock('l_lodeh'); // cooked 45 min ago, sayur + protein + tidak digoreng, 3 portions
  final ayam = mock('l_ayam'); // cooked 30 min ago, protein only, 2 portions
  final sayur = mock('l_sayur'); // raw, sayur + tidak digoreng
  final roti = mock('l_roti'); // sealed, best before in 2 days

  Listing at(Listing l, {int? cookedMinutesAgo}) => Listing(
        id: l.id,
        provider: l.provider,
        photo: l.photo,
        name: l.name,
        category: l.category,
        portionsLeft: l.portionsLeft,
        price: l.price,
        pickupBy: l.pickupBy,
        pickupPoint: l.pickupPoint,
        position: l.position,
        cookedAt: cookedMinutesAgo == null ? null : fixedNow.subtract(Duration(minutes: cookedMinutesAgo)),
        healthTags: l.healthTags,
        bestBefore: l.bestBefore,
      );

  test('health tag weights add up to one', () {
    expect(healthTagWeights.values.fold(0.0, (a, b) => a + b), closeTo(1, 1e-9));
  });

  group('freshness', () {
    test('cooked food fades linearly over six hours', () {
      expect(freshness(at(ayam, cookedMinutesAgo: 0), fixedNow), 1);
      expect(freshness(at(ayam, cookedMinutesAgo: 180), fixedNow), closeTo(0.5, 1e-9));
      expect(freshness(at(ayam, cookedMinutesAgo: 400), fixedNow), 0);
      expect(freshness(at(ayam), fixedNow), unknownCookedFreshness);
    });

    test('raw ingredients are fresh, sealed food follows its best-before date', () {
      expect(freshness(sayur, fixedNow), rawIngredientFreshness);
      expect(freshness(roti, fixedNow), closeTo(0.2 + 0.8 * 2 / 3, 0.02));
    });
  });

  group('health', () {
    test('score is the sum of tag weights', () {
      expect(healthScore(lodeh), closeTo(0.85, 1e-9));
      expect(healthScore(ayam), closeTo(0.25, 1e-9));
      expect(healthScore(roti), 0);
    });

    test('healthy needs vegetables plus one more tag; protein alone is not enough', () {
      expect(isHealthy(lodeh), isTrue);
      expect(isHealthy(sayur), isTrue);
      expect(isHealthy(ayam), isFalse);
    });
  });

  group('urgency', () {
    test('few portions and a near deadline are urgent', () {
      final urgent = Listing(
        id: 'u',
        provider: ayam.provider,
        photo: '',
        name: 'x',
        category: FoodCategory.makananMatang,
        portionsLeft: 1,
        price: 0,
        pickupBy: fixedNow.add(const Duration(minutes: 20)),
        pickupPoint: '',
        position: ayam.position,
      );
      expect(urgency(urgent, fixedNow), 1);
      expect(urgency(mock('l_lodeh2'), fixedNow), lessThan(urgency(ayam, fixedNow))); // 8 portions, 200 min vs 2, 120 min
    });
  });

  group('feed score = affinity × proximity × urgency', () {
    test('is the product of the three factors, each floored at 0.2', () {
      final u = urgency(ayam, fixedNow);
      expect(feedScore(ayam, 0, 1000, fixedNow), closeTo(1 * 1 * (0.2 + 0.8 * u), 1e-9));
      expect(feedScore(ayam, 1000, 1000, fixedNow, affinity: 0.5), closeTo(0.5 * 0.2 * (0.2 + 0.8 * u), 1e-9));
    });

    test('a higher affinity from the recommender outranks the same food at the same place', () {
      expect(feedScore(lodeh, 300, 1000, fixedNow, affinity: 0.9), greaterThan(feedScore(lodeh, 300, 1000, fixedNow, affinity: 0.3)));
    });

    test('nearness and urgency still break ties when the affinity is equal', () {
      expect(feedScore(lodeh, 100, 1000, fixedNow), greaterThan(feedScore(lodeh, 900, 1000, fixedNow)));
      expect(feedScore(ayam, 300, 1000, fixedNow), greaterThan(feedScore(mock('l_lodeh2'), 300, 1000, fixedNow)));
    });

    test('freshness and health only label the card, they do not move it', () {
      final fresh = at(lodeh, cookedMinutesAgo: 30);
      final stale = at(lodeh, cookedMinutesAgo: 330);
      expect(feedScore(fresh, 300, 1000, fixedNow), feedScore(stale, 300, 1000, fixedNow));
    });

    test('stays within 0..1', () {
      for (final l in all) {
        for (final a in [0.2, 0.6, 1.0]) {
          expect(feedScore(l, 500, 1000, fixedNow, affinity: a), inInclusiveRange(0, 1));
        }
      }
    });
  });
}
