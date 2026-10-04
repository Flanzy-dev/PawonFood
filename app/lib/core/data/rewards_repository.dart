import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/claimed_voucher.dart';
import '../models/reward.dart';
import '../services/rewards.dart';
import 'providers.dart';
import 'session_repository.dart';

/// Chips on Tukar poin: Semua / Belanja / Antar / Sertifikat.
enum RewardFilter {
  all('Semua', null),
  belanja('Belanja', RewardCategory.belanja),
  antar('Antar', RewardCategory.antar),
  sertifikat('Sertifikat', RewardCategory.sertifikat);

  const RewardFilter(this.label, this.category);
  final String label;
  final RewardCategory? category;
}

final rewardFilterProvider = StateProvider<RewardFilter>((ref) => RewardFilter.all);

/// Rewards matching the selected chip, in catalog order.
final filteredRewardsProvider = Provider<List<Reward>>((ref) {
  final filter = ref.watch(rewardFilterProvider);
  return [for (final r in ref.watch(mockDataProvider).rewards) if (filter.category == null || r.category == filter.category) r];
});

final rewardByIdProvider = Provider.family<Reward?, String>((ref, id) {
  for (final r in ref.watch(mockDataProvider).rewards) {
    if (r.id == id) return r;
  }
  return null;
});

/// Outcome of a claim: the voucher, or an Indonesian error message.
typedef ClaimResult = ({ClaimedVoucher? voucher, String? error});

/// Holds the most recent claimed voucher (shown on "Voucher berhasil diklaim"). Claiming deducts the points.
class RewardsNotifier extends Notifier<ClaimedVoucher?> {
  @override
  ClaimedVoucher? build() => null;

  ClaimResult claim(String rewardId) {
    final reward = ref.read(rewardByIdProvider(rewardId));
    final user = ref.read(sessionProvider);
    if (reward == null || user == null) return (voucher: null, error: 'Hadiah tidak ditemukan.');
    final error = claimError(reward, user.points);
    if (error != null) return (voucher: null, error: error);
    ref.read(sessionProvider.notifier).addPoints(-reward.cost);
    final now = ref.read(clockProvider)();
    final voucher = ClaimedVoucher(reward: reward, code: generateVoucherCode(ref.read(randomProvider)), validUntil: now.add(Duration(days: reward.validDays)));
    state = voucher;
    return (voucher: voucher, error: null);
  }
}

final rewardsProvider = NotifierProvider<RewardsNotifier, ClaimedVoucher?>(RewardsNotifier.new);
