import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/session_repository.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/brand_icons.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/navigation_widgets.dart';

/// A4 Masuk. The MVP has no real authentication: any valid email / phone and a non-empty password sign in.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _contact = TextEditingController();
  final _password = TextEditingController();
  var _submitted = false;

  @override
  void dispose() {
    _contact.dispose();
    _password.dispose();
    super.dispose();
  }

  String? get _contactError => _submitted ? Validators.emailOrPhone(_contact.text) : null;
  String? get _passwordError => _submitted && _password.text.isEmpty ? 'Password wajib diisi' : null;

  void _submit() {
    setState(() => _submitted = true);
    if (_contactError != null || _passwordError != null) return;
    ref.read(sessionProvider.notifier).login(_contact.text);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _submitted && (_contactError != null || _passwordError != null);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: RoundIconButton(icon: LucideIcons.arrowLeft, semanticLabel: 'Kembali', onTap: () => context.canPop() ? context.pop() : context.go('/welcome')),
            ),
            const SizedBox(height: 24),
            Text('Masuk', style: AppTypography.display(32, height: 38)),
            const SizedBox(height: 8),
            Text('Selamat datang kembali di PawonFood.', style: AppTypography.text(14, height: 20, color: AppColors.inkMuted)),
            const SizedBox(height: 28),
            AppTextField(
              label: 'Email atau nomor HP',
              controller: _contact,
              hint: 'contoh@email.com',
              errorText: _contactError,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Password',
              controller: _password,
              hint: 'Masukkan password',
              errorText: _passwordError,
              password: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showAppSnack(context, 'Reset password segera hadir.'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: Text('Lupa password?', style: AppTypography.text(14, weight: 700, color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 4),
            AppButton(label: 'Masuk', onPressed: blocked ? null : _submit),
            const SizedBox(height: 24),
            Row(children: [
              const Expanded(child: Divider(color: AppColors.border)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('atau', style: AppTypography.text(14, color: AppColors.inkMuted))),
              const Expanded(child: Divider(color: AppColors.border)),
            ]),
            const SizedBox(height: 24),
            AppButton(label: 'Lanjut dengan Google', variant: AppButtonVariant.outline, leading: const GoogleLogo(), onPressed: () => showAppSnack(context, 'Login sosial segera hadir.')),
            const SizedBox(height: 12),
            AppButton(label: 'Lanjut dengan Apple', variant: AppButtonVariant.outline, leading: const AppleLogo(), onPressed: () => showAppSnack(context, 'Login sosial segera hadir.')),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => context.pushReplacement('/register'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: Text('Belum punya akun? Daftar', style: AppTypography.text(15, weight: 700, color: AppColors.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
