import 'reward.dart';

/// A reward the user has claimed with points. Kept in memory only (MVP): the code is generated on device;
/// later it must be issued server-side.
class ClaimedVoucher {
  const ClaimedVoucher({required this.reward, required this.code, required this.validUntil});

  final Reward reward;

  /// `PWN-V-XXXX`, shown to the partner at checkout.
  final String code;
  final DateTime validUntil;
}
