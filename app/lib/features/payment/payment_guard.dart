import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/chat_repository.dart';
import '../../core/models/enums.dart';

/// Payment screens can stay open past the pickup deadline. When the reservation already ran out, this sends the receiver to
/// the "Waktu ambil sudah lewat" screen (B10c) instead of letting them pay for food they can no longer collect.
/// Call it from a post-frame callback; returns true when it redirected.
bool redirectIfReservationOver(BuildContext context, WidgetRef ref, String conversationId) {
  final notifier = ref.read(chatProvider.notifier);
  final expired = notifier.expireIfLate(conversationId) || ref.read(reservationProvider(conversationId))?.pickup.status == PickupStatus.expired;
  if (expired && context.mounted) context.go('/expired/$conversationId');
  return expired;
}
