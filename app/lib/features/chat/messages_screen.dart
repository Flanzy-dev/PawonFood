import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/data/listings_repository.dart';
import '../../core/data/providers.dart';
import '../../core/models/conversation.dart';
import '../../core/models/enums.dart';
import '../../core/services/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pills.dart';

/// B9 Pesan: threads split into "Saya menerima" and "Saya berbagi", with a permanent safety banner.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final received = ref.watch(receivedThreadsProvider);
    final shared = ref.watch(sharedThreadsProvider);
    final threads = _tab == 0 ? received : shared;
    int unread(List<Conversation> l) => l.fold(0, (s, c) => s + c.unread);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, navContentInset(context)),
        children: [
          Text('Pesan', style: AppTypography.display(32, height: 40)),
          const SizedBox(height: 16),
          SegmentedControl(
            options: const ['Saya menerima', 'Saya berbagi'],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
            badges: [unread(received), unread(shared)],
          ),
          const SizedBox(height: 8),
          if (threads.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: EmptyState(
                icon: LucideIcons.messageSquare,
                title: 'Belum ada percakapan',
                body: _tab == 0 ? 'Tawar atau ambil makanan dari Beranda untuk memulai.' : 'Bagikan makanan dulu. Tawaran dari penerima akan muncul di sini.',
              ),
            )
          else
            for (final c in threads) _ThreadRow(conversation: c, asReceiver: _tab == 0),
          const SizedBox(height: 16),
          const SafetyBanner(text: 'Tawar dan atur waktu ambil di sini saja. Jangan transfer uang di luar aplikasi sebelum makanan kamu terima.'),
        ],
      ),
    );
  }
}

class _ThreadRow extends ConsumerWidget {
  const _ThreadRow({required this.conversation, required this.asReceiver});

  final Conversation conversation;
  final bool asReceiver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = conversation;
    final listing = ref.watch(listingByIdProvider(c.listingId));
    final people = ref.watch(peopleProvider);
    final other = people[asReceiver ? c.providerId : c.receiverId];
    if (listing == null || other == null) return const SizedBox.shrink();
    final now = ref.watch(clockProvider)();
    final amount = c.offer?.status == OfferStatus.accepted ? c.offer!.amount : listing.price;
    final price = amount == 0 ? 'Gratis' : formatRupiah(amount);
    final last = c.lastChat;
    final unread = c.unread > 0;
    return Semantics(
      button: true,
      label: '${other.name}, ${listing.name}, ${c.status.label}',
      child: InkWell(
        onTap: () => context.push('/chat/${c.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PersonAvatar(other, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(other.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.display(18, weight: 700, height: 24))),
                      if (last != null) Text(formatThreadTime(last.at, now), style: AppTypography.text(14, color: AppColors.inkMuted)),
                    ]),
                    const SizedBox(height: 2),
                    Text('${listing.name} · $price', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.text(14, height: 20, color: AppColors.inkMuted)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: Text(
                          last?.body ?? 'Belum ada pesan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.text(14, weight: unread ? 700 : 400, height: 20, color: unread ? AppColors.ink : AppColors.inkMuted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusPill(c.status),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
