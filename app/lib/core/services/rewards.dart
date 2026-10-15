import 'dart:math';

import '../models/reward.dart';

/// `PWN-V-XXXX` (4 digits), the voucher code a partner checks at checkout. Runs on device in the MVP.
String generateVoucherCode(Random random) => 'PWN-V-${1000 + random.nextInt(9000)}';

/// Why a reward cannot be claimed with [points], or null when it can. Messages are shown to the user.
String? claimError(Reward reward, int points) {
  if (!reward.claimable) return 'Hadiah ini belum bisa diklaim dengan poin.';
  if (points < reward.cost) return 'Poin belum cukup';
  return null;
}

/// Points still missing to claim [reward] (0 when affordable or not bought with points).
int pointsShort(Reward reward, int points) => reward.claimable && points < reward.cost ? reward.cost - points : 0;
