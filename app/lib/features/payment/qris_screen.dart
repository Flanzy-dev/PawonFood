import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/data/providers.dart';
import '../../core/motion/entrance.dart';
import '../../core/services/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/countdown.dart';
import '../../core/widgets/info_box.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/qr_box.dart';
import '../../core/widgets/top_bar.dart';
import 'payment_guard.dart';

/// B10f / B10f2 Bayar dengan QRIS (simulated gateway). "Cek status" answers "belum masuk" first, then succeeds.
/// When the 15-minute timer runs out the payment fails (B10h). Long-press the title to fail it right away (demo).
class QrisScreen extends ConsumerStatefulWidget {
  const QrisScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<QrisScreen> createState() => _QrisScreenState();
}

class _QrisScreenState extends ConsumerState<QrisScreen> {
  // The payment window is 15 minutes, but never longer than the time left to collect the food.
  late final DateTime _expires = () {
    final now = ref.read(clockProvider)();
    final window = now.add(const Duration(minutes: 15));
    final deadline = ref.read(reservationProvider(_id))?.pickup.deadline;
    return deadline != null && deadline.isBefore(window) ? deadline : window;
  }();
  var _checking = false;
  var _notYet = false;

  String get _id => widget.conversationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) redirectIfReservationOver(context, ref, _id);
    });
  }

  void _fail() => context.pushReplacement('/pay/$_id/failed');

  Future<void> _check() async {
    setState(() => _checking = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    if (redirectIfReservationOver(context, ref, _id)) return;
    final paid = ref.read(chatProvider.notifier).checkQrisPayment(_id);
    if (paid) {
      context.pushReplacement('/pay/$_id/done');
    } else {
      setState(() {
        _checking = false;
        _notYet = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(reservationProvider(_id));
    if (r == null) return const NotFoundScaffold();
    return Scaffold(
      body: SafeArea(
        child: EntranceScope(
          child: Column(
            children: [
              TopBar(title: 'Bayar dengan QRIS', fallback: '/chat/$_id', onTitleLongPress: _fail),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    FadeSlideIn(
                      child: Column(children: [
                        Text('Total bayar', style: AppTypography.text(14, color: AppColors.inkMuted)),
                        Text(formatRupiah(r.payable), style: AppTypography.display(34, height: 42)),
                        const SizedBox(height: 8),
                        Countdown(
                          until: _expires,
                          now: ref.read(clockProvider),
                          onDone: _fail,
                          builder: (_, left) => Pill('Bayar dalam ${formatMmSs(left)}', color: AppColors.accentInk, height: 32, size: 14, weight: 700, hPad: 14),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      index: 1,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
                        child: Column(children: [
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: 'QRIS', style: AppTypography.display(17, weight: 800)),
                              TextSpan(text: ' · PawonFood', style: AppTypography.display(17, weight: 600)),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          QrBox(data: 'qris://pawonfood/${r.pickup.id}?amount=${r.payable}', size: 236, semanticLabel: 'QRIS untuk membayar ${formatRupiah(r.payable)}'),
                          const SizedBox(height: 12),
                          Text('${r.listing.name} · ${r.provider.name}', textAlign: TextAlign.center, style: AppTypography.text(13, color: AppColors.inkMuted)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FadeSwitch(
                      child: _notYet
                          ? Semantics(
                              liveRegion: true,
                              key: const ValueKey('notyet'),
                              child: const InfoBox(
                                'Pembayaran belum masuk. Kalau sudah bayar, tunggu sebentar lalu cek lagi.',
                                icon: LucideIcons.info,
                                tone: InfoTone.dark,
                              ),
                            )
                          : FadeSlideIn(
                              key: const ValueKey('steps'),
                              index: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final s in const ['1. Buka aplikasi e-wallet atau m-banking.', '2. Pindai QR ini.', '3. Halaman ini otomatis lanjut setelah bayar.'])
                                    Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(s, style: AppTypography.text(14, height: 21))),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(children: [
                  AppButton(label: 'Simpan QR', variant: AppButtonVariant.outline, onPressed: () => showAppSnack(context, 'Simpan QR segera hadir.')),
                  const SizedBox(height: 12),
                  AppButton(label: 'Cek status pembayaran', loading: _checking, onPressed: _checking ? null : _check),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
