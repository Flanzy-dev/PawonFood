import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/services/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/info_box.dart';
import '../../core/widgets/status_layout.dart';

/// B10c Waktu ambil sudah lewat (receiver) and C17c QR sudah kedaluwarsa (provider).
class ExpiredScreen extends ConsumerWidget {
  const ExpiredScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(reservationProvider(conversationId));
    if (r == null) return const NotFoundScaffold();
    final deadline = formatTime(r.pickup.deadline);
    if (!r.asReceiver) {
      return StatusLayout(
        kind: StatusKind.failure,
        back: true,
        fallback: '/chat/$conversationId',
        title: 'QR sudah kedaluwarsa',
        body: 'Reservasi ${r.receiver.name.split(' ').first} berakhir pukul $deadline. Porsinya dibuka lagi untuk penerima lain.',
        actions: [AppButton(label: 'Kembali ke chat', onPressed: () => context.go('/chat/$conversationId'))],
      );
    }
    return StatusLayout(
      kind: StatusKind.clock,
      back: true,
      fallback: '/chat/$conversationId',
      title: 'Waktu ambil sudah lewat',
      body: 'Reservasi ${r.listing.name} berakhir pukul $deadline. Porsinya dibuka lagi untuk orang lain.',
      content: const [
        InfoBox('Reservasi yang kedaluwarsa berulang kali menurunkan rating dan prioritas reservasimu.', icon: LucideIcons.info, iconColor: AppColors.accent),
      ],
      actions: [
        AppButton(label: 'Cari makanan lain', onPressed: () => context.go('/')),
        AppButton(label: 'Chat ${shortName(r.provider.name)}', icon: LucideIcons.messageSquare, variant: AppButtonVariant.outline, onPressed: () => context.go('/chat/$conversationId')),
      ],
    );
  }
}
