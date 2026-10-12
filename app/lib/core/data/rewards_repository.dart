import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/claimed_voucher.dart';
import '../models/reward.dart';
import '../services/rewards.dart';
import 'providers.dart';
import 'session_repository.dart';

/// Chips on Tukar poin: Semua / Belanja / Antar / Makanan / Sertifikat.
enum RewardFilter {
  all('Semua', null),
  belanja('Belanja', RewardCategory.belanja),
  antar('Antar', RewardCategory.antar),
  makanan('Makanan', RewardCategory.makanan),
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
    ref.read(myVouchersProvider.notifier).add(voucher);
    return (voucher: voucher, error: null);
  }
}

/// D22b "Voucher saya": every claimed voucher. Seeded with a few for the demo.
class MyVouchersNotifier extends Notifier<List<ClaimedVoucher>> {
  @override
  List<ClaimedVoucher> build() {
    final now = ref.read(clockProvider)();
    Reward? r(String id) => ref.read(rewardByIdProvider(id));
    return [
      if (r('r_ojek') != null) ClaimedVoucher(reward: r('r_ojek')!, code: 'PWN-V-7392', validUntil: now.add(const Duration(days: 31))),
      if (r('r_voucher') != null) ClaimedVoucher(reward: r('r_voucher')!, code: 'PWN-V-5148', validUntil: now.add(const Duration(days: 48))),
      if (r('r_pulsa') != null) ClaimedVoucher(reward: r('r_pulsa')!, code: 'PWN-V-2276', validUntil: now.add(const Duration(days: 56))),
      if (r('r_ongkir') != null) ClaimedVoucher(reward: r('r_ongkir')!, code: 'PWN-V-1180', validUntil: now.subtract(const Duration(days: 3)), used: true),
      // Food vouchers for the demo: usable on Pembayaran.
      if (r('r_makan3') != null) ClaimedVoucher(reward: r('r_makan3')!, code: 'PWN-V-3001', validUntil: now.add(const Duration(days: 40))),
      if (r('r_makan5') != null) ClaimedVoucher(reward: r('r_makan5')!, code: 'PWN-V-3002', validUntil: now.add(const Duration(days: 40))),
    ];
  }

  void add(ClaimedVoucher v) => state = [v, ...state];

  /// The voucher with this code (case-insensitive, spaces ignored), or null.
  ClaimedVoucher? byCode(String code) {
    final c = code.replaceAll(' ', '').toUpperCase();
    for (final v in state) {
      if (v.code == c) return v;
    }
    return null;
  }

  /// A food voucher was spent on a payment: "Terpakai" on Voucher saya.
  void markUsed(String code) => state = [for (final v in state) if (v.code == code) v.copyWith(used: true) else v];
}

final myVouchersProvider = NotifierProvider<MyVouchersNotifier, List<ClaimedVoucher>>(MyVouchersNotifier.new);

final rewardsProvider = NotifierProvider<RewardsNotifier, ClaimedVoucher?>(RewardsNotifier.new);
