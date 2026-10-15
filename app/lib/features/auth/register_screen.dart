import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/session_repository.dart';
import '../../core/models/enums.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/navigation_widgets.dart';

/// A2 Daftar akun. After a failed submit the fields show inline errors (A3) and the button stays
/// disabled until every field is valid.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _password = TextEditingController();
  var _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _password.dispose();
    super.dispose();
  }

  String? get _nameError => _submitted ? Validators.name(_name.text) : null;
  String? get _contactError => _submitted ? Validators.emailOrPhone(_contact.text) : null;
  String? get _passwordError => _submitted ? Validators.password(_password.text) : null;
  bool get _hasErrors => _nameError != null || _contactError != null || _passwordError != null;

  void _submit() {
    setState(() => _submitted = true);
    if (_hasErrors) return;
    // One account both takes and shares food, so there is no role to pick.
    ref.read(sessionProvider.notifier).register(
          name: _name.text,
          emailOrPhone: _contact.text,
          roles: {UserRole.receiver, UserRole.provider},
        );
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _submitted && _hasErrors;
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
            Text('Buat akun', style: AppTypography.display(32, height: 38)),
            const SizedBox(height: 8),
            Text('Satu akun untuk mengambil dan membagikan makanan.', style: AppTypography.text(14, height: 20, color: AppColors.inkMuted)),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Nama lengkap',
              controller: _name,
              hint: 'Masukkan nama',
              errorText: _nameError,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
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
              hint: 'Minimal 8 karakter',
              helperText: 'Gunakan huruf dan angka',
              errorText: _passwordError,
              password: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            AppButton(label: 'Buat akun', onPressed: blocked ? null : _submit),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => context.pushReplacement('/login'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: Text('Sudah punya akun? Masuk', style: AppTypography.text(15, weight: 700, color: AppColors.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
