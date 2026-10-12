import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_repository.dart';
import 'app_sheet.dart';

/// "Keluar" on Profil and Pengaturan: asks first, because it sits right above the bottom nav and one stray tap would sign out.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final ok = await confirmAction(
    context,
    title: 'Keluar dari PawonFood?',
    message: 'Kamu perlu masuk lagi untuk memakai akunmu.',
    confirmLabel: 'Keluar',
    destructive: false,
  );
  if (ok) ref.read(sessionProvider.notifier).logout();
}
