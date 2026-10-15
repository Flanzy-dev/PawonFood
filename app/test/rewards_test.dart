import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawonfood/core/data/listings_repository.dart';
import 'package:pawonfood/core/data/rewards_repository.dart';
import 'package:pawonfood/core/data/session_repository.dart';
import 'package:pawonfood/core/models/reward.dart';
import 'package:pawonfood/core/services/formatters.dart';
import 'package:pawonfood/core/services/rewards.dart';

import 'support.dart';

ProviderContainer signedIn() {
  final c = makeContainer();
  c.read(sessionProvider.notifier).login('rafi@email.com'); // 150 poin
  return c;
}

void main() {
  group('reward catalog', () {
    test('has eight rewards and the chips filter them by category', () {
      final c = signedIn();
      expect(c.read(filteredRewardsProvider).length, 8);
      c.read(rewardFilterProvider.notifier).state = RewardFilter.antar;
      expect([for (final r in c.read(filteredRewardsProvider)) r.id], ['r_ojek', 'r_ongkir']);
      c.read(rewardFilterProvider.notifier).state = RewardFilter.makanan;
      expect([for (final r in c.read(filteredRewardsProvider)) r.id], ['r_makan3', 'r_makan5']);
      c.read(rewardFilterProvider.notifier).state = RewardFilter.sertifikat;
      expect([for (final r in c.read(filteredRewardsProvider)) r.id], ['r_sertifikat']);
    });

    test('the certificate is not bought with points', () {
      final cert = signedIn().read(rewardByIdProvider('r_sertifikat'))!;
      expect(cert.claimable, isFalse);
      expect(cert.cardTitle, 'Sertifikat Peduli Lingkungan');
      expect(claimError(cert, 9999), isNotNull);
    });
  });

  group('points helpers', () {
    const reward = Reward(id: 'r', title: 'Voucher', subtitle: '', tile: 'Rp', cost: 200, tone: 'sand');

    test('pointsShort is the missing amount, never negative', () {
      expect(pointsShort(reward, 150), 50);
      expect(pointsShort(reward, 200), 0);
      expect(pointsShort(reward, 999), 0);
    });

    test('claimError explains why a claim is refused', () {
      expect(claimError(reward, 150), 'Poin belum cukup');
      expect(claimError(reward, 200), isNull);
    });

    test('voucher codes are PWN-V- plus four digits', () {
      final random = Random(3);
      for (var i = 0; i < 50; i++) {
        expect(generateVoucherCode(random), matches(RegExp(r'^PWN-V-[1-9]\d{3}$')));
      }
    });

    test('formatLongDate writes the full Indonesian month', () {
      expect(formatLongDate(DateTime(2026, 11, 3)), '3 November 2026');
      expect(formatLongDate(DateTime(2027, 1, 15)), '15 Januari 2027');
    });
  });

  group('claiming', () {
    test('deducts the points, creates a code and keeps the voucher valid for 30 days', () {
      final c = signedIn();
      final r = c.read(rewardsProvider.notifier).claim('r_ojek'); // 150 poin
      expect(r.error, isNull);
      expect(r.voucher!.code, matches(RegExp(r'^PWN-V-\d{4}$')));
      expect(r.voucher!.validUntil, fixedNow.add(const Duration(days: 30)));
      expect(c.read(sessionProvider)!.points, 0);
      expect(c.read(rewardsProvider), same(r.voucher));
    });

    test('refuses when the balance is too low and leaves the points alone', () {
      final c = signedIn();
      final r = c.read(rewardsProvider.notifier).claim('r_voucher'); // 200 poin
      expect(r.voucher, isNull);
      expect(r.error, 'Poin belum cukup');
      expect(c.read(sessionProvider)!.points, 150);
      expect(c.read(rewardsProvider), isNull);
    });

    test('refuses the certificate and unknown rewards', () {
      final c = signedIn();
      expect(c.read(rewardsProvider.notifier).claim('r_sertifikat').voucher, isNull);
      expect(c.read(rewardsProvider.notifier).claim('nope').error, 'Hadiah tidak ditemukan.');
      expect(c.read(sessionProvider)!.points, 150);
    });

    test('claiming needs a signed-in user', () {
      final c = makeContainer();
      expect(c.read(rewardsProvider.notifier).claim('r_ojek').voucher, isNull);
    });
  });

  group('full list sorting', () {
    test('Rekomendasi is the default and follows the score; Terdekat sorts by distance, Segera habis by portions left', () {
      final c = signedIn();
      final ranked = c.read(sortedFeedProvider);
      expect(c.read(feedSortProvider), FeedSort.recommended);
      for (var i = 1; i < ranked.length; i++) {
        expect(ranked[i].score, lessThanOrEqualTo(ranked[i - 1].score));
      }
      c.read(feedSortProvider.notifier).state = FeedSort.nearest;
      final nearest = c.read(sortedFeedProvider);
      for (var i = 1; i < nearest.length; i++) {
        expect(nearest[i].distance, greaterThanOrEqualTo(nearest[i - 1].distance));
      }
      c.read(feedSortProvider.notifier).state = FeedSort.urgent;
      final urgent = c.read(sortedFeedProvider);
      for (var i = 1; i < urgent.length; i++) {
        expect(urgent[i].listing.portionsLeft, greaterThanOrEqualTo(urgent[i - 1].listing.portionsLeft));
      }
      expect(urgent.length, nearest.length);
    });
  });
}
