import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/session_repository.dart';
import '../../core/data/settings_repository.dart';
import '../../core/motion/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/logout_confirm.dart';
import '../../core/widgets/option_row.dart';
import '../../core/widgets/radius_sheet.dart';
import '../../core/widgets/settings_list.dart';
import '../../core/widgets/top_bar.dart';

/// D18d Pengaturan: notifications, default radius, language, account and help.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final groups = [
      SettingsGroup(title: 'Notifikasi', children: [
        SettingsRow(title: 'Notifikasi', subtitle: 'Pesan, tawaran, makanan baru', onTap: () => context.push('/settings/notifications')),
      ]),
      SettingsGroup(title: 'Umum', children: [
        SettingsRow(title: 'Radius default', subtitle: formatRadius(s.radiusMeters), onTap: () => _radiusSheet(context, ref)),
        SettingsRow(title: 'Bahasa', subtitle: 'Indonesia', onTap: () => _languageSheet(context)),
      ]),
      SettingsGroup(title: 'Akun', children: [
        SettingsRow(title: 'Ubah password', onTap: () => context.push('/settings/password')),
        SettingsRow(title: 'Keluar', chevron: false, onTap: () => confirmLogout(context, ref)),
        SettingsRow(title: 'Hapus akun', destructive: true, onTap: () => _deleteSheet(context, ref)),
      ]),
      SettingsGroup(title: 'Bantuan', children: [
        SettingsRow(title: 'Pusat bantuan', onTap: () => context.push('/settings/help')),
        SettingsRow(title: 'Syarat & Ketentuan', onTap: () => context.push('/settings/terms')),
        SettingsRow(title: 'Kebijakan Privasi', onTap: () => context.push('/settings/privacy')),
      ]),
    ];
    return Scaffold(
      body: SafeArea(
        child: EntranceScope(
          child: Column(children: [
            const TopBar(title: 'Pengaturan', fallback: '/profile'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  for (final (i, g) in groups.indexed) FadeSlideIn(index: i, child: Padding(padding: const EdgeInsets.only(bottom: 18), child: g)),
                  Center(child: Text('PawonFood 0.1.0', style: AppTypography.text(13, color: AppColors.inkMuted))),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _radiusSheet(BuildContext context, WidgetRef ref) => showRadiusSheet(
        context,
        title: 'Radius default',
        subtitle: 'Dipakai di Beranda dan Peta',
        current: (ref) => ref.watch(settingsProvider).radiusMeters,
        onPick: (ref, m) => ref.read(settingsProvider.notifier).setRadius(m),
      );

  void _languageSheet(BuildContext context) => showAppSheet<void>(
        context: context,
        builder: (ctx) => SheetBody(
          title: 'Bahasa',
          children: [
            OptionRow(title: 'Indonesia', selected: true, onTap: () => Navigator.of(ctx).pop()),
            const SizedBox(height: 10),
            const OptionRow(title: 'English', tag: 'Segera hadir', selected: false, enabled: false, onTap: null),
          ],
        ),
      );

  void _deleteSheet(BuildContext context, WidgetRef ref) => showAppSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => const _DeleteAccountSheet(),
      );
}

/// D18j: deleting needs "HAPUS" typed in, so it is never one tap away.
class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _confirm.text.trim() == 'HAPUS';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        // Scrolls, so "Hapus akun" stays reachable when the keyboard is open on a short phone.
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: AppColors.errorLight, shape: BoxShape.circle),
                child: const Icon(LucideIcons.triangleAlert, color: AppColors.error),
              ),
              const SizedBox(width: 14),
              Text('Hapus akun?', style: AppTypography.titleL),
            ]),
            const SizedBox(height: 12),
            Text('Akun, riwayat, dan poinmu akan dihapus dan tidak bisa dikembalikan. Makanan yang masih tayang ikut dihapus.', style: AppTypography.text(14, height: 21)),
            const SizedBox(height: 14),
            AppTextField(label: 'Ketik HAPUS untuk melanjutkan', controller: _confirm, hint: 'HAPUS', textCapitalization: TextCapitalization.characters, onChanged: (_) => setState(() {})),
            const SizedBox(height: 20),
            AppButton(
              label: 'Hapus akun',
              variant: AppButtonVariant.danger,
              onPressed: ok
                  ? () {
                      closeSheet(context);
                      ref.read(sessionProvider.notifier).logout();
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            AppButton(label: 'Batal', variant: AppButtonVariant.outline, onPressed: () => closeSheet(context)),
          ],
        ),
        ),
      ),
    );
  }
}
