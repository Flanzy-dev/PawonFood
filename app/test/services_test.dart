import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pawonfood/core/models/enums.dart';
import 'package:pawonfood/core/services/food_label.dart';
import 'package:pawonfood/core/services/food_validator.dart';
import 'package:pawonfood/core/services/formatters.dart';
import 'package:pawonfood/core/services/geo.dart';
import 'package:pawonfood/core/services/negotiation.dart';
import 'package:pawonfood/core/services/pickup_times.dart';
import 'package:pawonfood/core/services/points.dart';
import 'package:pawonfood/core/services/validators.dart';
import 'package:pawonfood/core/widgets/map_cluster.dart';

import 'support.dart';

void main() {
  group('AI validation rule (ARCHITECTURE.md)', () {
    test('no detections is rejected', () {
      final r = decideValidation(const []);
      expect(r.verdict, AiVerdict.rejected);
      expect(r.message, msgNoDetection);
    });

    test('bukan_makanan above 0.70 is rejected, even next to a food class', () {
      expect(decideValidation(const [Detection(AiClass.bukanMakanan, 0.71)]).verdict, AiVerdict.rejected);
      final both = decideValidation(const [Detection(AiClass.bukanMakanan, 0.9), Detection(AiClass.makananMatang, 0.9)]);
      expect(both.verdict, AiVerdict.rejected);
      expect(both.message, msgNotFood);
    });

    test('bukan_makanan at exactly 0.70 is not a rejection', () {
      expect(decideValidation(const [Detection(AiClass.bukanMakanan, 0.70)]).verdict, AiVerdict.pendingReview);
    });

    test('a food class above 0.60 is approved with that category', () {
      final r = decideValidation(const [Detection(AiClass.makananMatang, 0.61)]);
      expect(r.verdict, AiVerdict.approved);
      expect(r.category, FoodCategory.makananMatang);
      expect(decideValidation(const [Detection(AiClass.bahanMentah, 0.8), Detection(AiClass.makananMatang, 0.7)]).category, FoodCategory.bahanMentah);
    });

    test('anything else goes to manual review', () {
      expect(decideValidation(const [Detection(AiClass.makananMatang, 0.60)]).verdict, AiVerdict.pendingReview);
    });

    test('simulated validator follows the demo mode', () async {
      Future<AiVerdict> run(DemoAiMode m) => SimulatedFoodValidator(mode: () => m, scanDelay: Duration.zero).validate('x').then((r) => r.verdict);
      expect(await run(DemoAiMode.normal), AiVerdict.approved);
      expect(await run(DemoAiMode.rawIngredients), AiVerdict.approved);
      expect(await run(DemoAiMode.notFood), AiVerdict.rejected);
      expect(await run(DemoAiMode.lowConfidence), AiVerdict.pendingReview);
    });
  });

  group('formatters', () {
    test('rupiah uses a dot as thousands separator', () {
      expect(formatRupiah(5000), 'Rp5.000');
      expect(formatRupiah(15000), 'Rp15.000');
      expect(formatRupiah(0), 'Rp0');
      expect(formatRupiah(1250000), 'Rp1.250.000');
    });

    test('time uses a dot and two digits', () {
      expect(formatTime(DateTime(2026, 1, 1, 20, 30)), '20.30');
      expect(formatTime(DateTime(2026, 1, 1, 9, 5)), '09.05');
    });

    test('distance and walking time', () {
      expect(formatDistance(296), '300 m');
      expect(formatDistance(0), '0 m');
      expect(formatDistance(1200), '1,2 km');
      expect(walkLabel(300), '± 4 mnt jalan kaki');
    });

    test('thread time and venue short names', () {
      final now = DateTime(2026, 10, 3, 20, 0);
      expect(formatThreadTime(DateTime(2026, 10, 3, 19, 42), now), '19.42');
      expect(formatThreadTime(DateTime(2026, 10, 2, 8, 0), now), 'Kemarin');
      expect(shortName('Warteg Bu Siti'), 'Bu Siti');
      expect(shortName('Bu Kos Wulan'), 'Bu Kos Wulan');
      expect(formatRating(4.8), '4,8');
    });
  });

  group('input validation', () {
    test('password needs 8+ characters with letters and digits', () {
      expect(Validators.password('abc'), 'Password minimal 8 karakter');
      expect(Validators.password('abcdefgh'), 'Gunakan huruf dan angka');
      expect(Validators.password('abcd1234'), isNull);
    });

    test('email or phone', () {
      expect(Validators.emailOrPhone(''), isNotNull);
      expect(Validators.emailOrPhone('rafi@email'), 'Format email atau nomor HP tidak valid');
      expect(Validators.emailOrPhone('rafi@email.com'), isNull);
      expect(Validators.emailOrPhone('0812-3456-7890'), isNull);
    });

    test('price >= 0, portions >= 1, pickup in the future', () {
      expect(Validators.price(-1), isNotNull);
      expect(Validators.price(0), isNull);
      expect(Validators.portions(0), isNotNull);
      expect(Validators.portions(1), isNull);
      expect(Validators.pickupTime(fixedNow.subtract(const Duration(minutes: 1)), fixedNow), isNotNull);
      expect(Validators.pickupTime(fixedNow.add(const Duration(minutes: 1)), fixedNow), isNull);
    });

    test('offer amount must be positive and not above the price', () {
      expect(Validators.offerAmount(null, 5000), 'Masukkan nominal tawaran');
      expect(Validators.offerAmount(6000, 5000), 'Tawaran tidak boleh melebihi harga');
      expect(Validators.offerAmount(3000, 5000), isNull);
    });
  });

  group('points and tiers', () {
    test('thresholds', () {
      expect(tierFor(0), Tier.sobatPawon);
      expect(tierFor(499), Tier.sobatPawon);
      expect(tierFor(500), Tier.foodSavior);
      expect(tierFor(1500), Tier.pahlawanPangan);
      expect(pointsToNext(150), 350);
      expect(pointsToNext(2000), 0);
      expect(tierProgress(150), closeTo(0.3, 1e-9));
    });

    test('provider points: free food earns double, a rating of 4+ adds a bonus', () {
      expect(pickupPoints(portions: 2, isFree: false), 20);
      expect(pickupPoints(portions: 2, isFree: true), 40);
      expect(pickupPoints(portions: 1, isFree: false, rating: 5), 15);
      expect(pickupPoints(portions: 1, isFree: false, rating: 3), 10);
    });
  });

  group('negotiation', () {
    test('free food and full price are accepted', () {
      expect(decideOffer(price: 0, amount: 0, negotiable: false), isA<OfferAccepted>());
      expect(decideOffer(price: 5000, amount: 5000, negotiable: false), isA<OfferAccepted>());
    });

    test('half the price or more is accepted, lower gets a counter', () {
      expect(decideOffer(price: 5000, amount: 2500, negotiable: true), isA<OfferAccepted>());
      final low = decideOffer(price: 5000, amount: 2000, negotiable: true);
      expect(low, isA<OfferCountered>());
      expect((low as OfferCountered).amount, 3000);
    });

    test('non-negotiable listings only take the full price', () {
      final r = decideOffer(price: 5000, amount: 4000, negotiable: false);
      expect((r as OfferCountered).amount, 5000);
    });

    test('quick offers and pickup codes', () {
      expect(quickOffers(5000), [3000, 4000]);
      expect(quickOffers(500), isEmpty);
      expect(generatePickupCode(Random(3)), matches(RegExp(r'^PWN-\d{4}$')));
    });
  });

  test('pickup time chips: next half hour at least 45 minutes away, then +90 and +180 minutes', () {
    final t = suggestPickupTimes(DateTime(2026, 10, 3, 21, 40));
    expect(t.map(formatTime).toList(), ['22.30', '00.00', '01.30']);
    expect(suggestPickupTimes(DateTime(2026, 10, 3, 18, 0)).first, DateTime(2026, 10, 3, 19, 0));
  });

  group('geo and map clusters', () {
    test('haversine distance matches the mock listing (about 300 m)', () {
      final ayam = loadMockData().listings.firstWhere((l) => l.id == 'l_ayam');
      expect(distanceMeters(pogung, ayam.position), inInclusiveRange(250, 330));
      expect(distanceMeters(pogung, pogung), 0);
    });

    test('nearby listings merge into one cluster, far ones stay single', () {
      final ls = loadMockData().listings.where((l) => l.id == 'l_ayam' || l.id == 'l_ayam2' || l.id == 'l_lodeh2').toList();
      expect(clusterListings(ls, 10).length, 3);
      final merged = clusterListings(ls, 5000);
      expect(merged.length, 1);
      expect(merged.first.count, 3);
      expect(merged.first.center, isA<LatLng>());
    });

    test('zoomForSpan is the inverse of metersPerPixel', () {
      final z = zoomForSpan(pogung.latitude, 2000, 250);
      expect(metersPerPixel(pogung.latitude, z) * 250, closeTo(2000, 1));
    });
  });

  group('food label', () {
    final all = loadMockData().listings;
    final ayam = all.firstWhere((l) => l.id == 'l_ayam'); // Pahlawan Pangan provider, cooked 30 min ago, 2 portions
    final lodeh = all.firstWhere((l) => l.id == 'l_lodeh'); // Sobat Pawon provider, cooked 45 min ago
    final sayur = all.firstWhere((l) => l.id == 'l_sayur'); // raw ingredients, never cooked

    test('a top-tier provider is Populer', () => expect(foodLabelFor(ayam, fixedNow), FoodLabel.populer));
    test('freshly cooked food is Terbaru', () => expect(foodLabelFor(lodeh, fixedNow), FoodLabel.terbaru));
    test('no label when old or never cooked', () {
      expect(foodLabelFor(lodeh, fixedNow.add(const Duration(minutes: 30)))?.label, isNull); // 75 min after cooking
      expect(foodLabelFor(sayur, fixedNow), isNull);
    });
    test('one portion left wins over every other label', () {
      expect(foodLabelFor(ayam.copyWith(portionsLeft: 1), fixedNow), FoodLabel.hampirHabis);
      expect(foodLabelFor(lodeh.copyWith(portionsLeft: 1), fixedNow), FoodLabel.hampirHabis);
    });
    test('labels read as in the design', () {
      expect([for (final l in FoodLabel.values) l.label], ['Hampir habis', 'Populer', 'Terbaru']);
    });
  });
}
