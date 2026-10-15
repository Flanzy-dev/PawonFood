import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/settings_repository.dart';
import '../../core/motion/entrance.dart';
import '../../core/motion/motion.dart';
import '../../core/widgets/settings_list.dart';
import '../../core/widgets/top_bar.dart';

/// D18f Notifikasi: activity, nearby food and quiet hours.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _pickQuietHours(BuildContext context, WidgetRef ref, AppSettings s) async {
    final from = await showTimePicker(context: context, initialTime: s.quietFrom, helpText: 'Jam tenang mulai');
    if (from == null || !context.mounted) return;
    final to = await showTimePicker(context: context, initialTime: s.quietTo, helpText: 'Jam tenang selesai');
    if (to == null) return;
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(quietFrom: from, quietTo: to));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    void set(AppSettings Function(AppSettings) f) => ref.read(settingsProvider.notifier).update(f);
    final groups = [
      SettingsGroup(title: 'Aktivitas', children: [
        SettingsRow(title: 'Pesan baru', toggle: s.newMessages, onToggle: (v) => set((s) => s.copyWith(newMessages: v))),
        SettingsRow(title: 'Tawaran diterima atau ditolak', toggle: s.offerUpdates, onToggle: (v) => set((s) => s.copyWith(offerUpdates: v))),
        SettingsRow(title: 'Pengingat jam ambil', toggle: s.pickupReminder, onToggle: (v) => set((s) => s.copyWith(pickupReminder: v))),
      ]),
      SettingsGroup(title: 'Di sekitarmu', children: [
        SettingsRow(title: 'Makanan baru dalam radius', subtitle: 'Sesuai radius default', toggle: s.nearbyFood, onToggle: (v) => set((s) => s.copyWith(nearbyFood: v))),
      ]),
      SettingsGroup(title: 'Jam tenang', children: [
        SettingsRow(title: 'Jam tenang', toggle: s.quietHours, onToggle: (v) => set((s) => s.copyWith(quietHours: v))),
        if (s.quietHours)
          SettingsRow(
            title: 'Dari ${formatTimeOfDay(s.quietFrom)} sampai ${formatTimeOfDay(s.quietTo)}',
            subtitle: 'Notifikasi tidak berbunyi, tetap masuk ke Pesan',
            onTap: () => _pickQuietHours(context, ref, s),
          ),
      ]),
    ];
    return Scaffold(
      body: SafeArea(
        child: EntranceScope(
          child: Column(children: [
            const TopBar(title: 'Notifikasi', fallback: '/settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [for (final (i, g) in groups.indexed) FadeSlideIn(index: i, child: Padding(padding: const EdgeInsets.only(bottom: 18), child: AnimatedSize(duration: Motion.of(context, Motion.base), curve: Motion.move, child: g)))],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
