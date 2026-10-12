import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/top_bar.dart';

/// D18i Ubah password (simulated: there is no backend yet).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _again = TextEditingController();
  String? _oldError;
  String? _newError;
  String? _againError;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _again.dispose();
    super.dispose();
  }

  void _save() {
    setState(() {
      _oldError = _old.text.isEmpty ? 'Masukkan password lama' : null;
      _newError = Validators.newPassword(_new.text, old: _old.text);
      _againError = _again.text != _new.text ? 'Password tidak sama' : null;
    });
    if (_oldError != null || _newError != null || _againError != null) return;
    showAppSnack(context, 'Password berhasil diubah.');
    context.canPop() ? context.pop() : context.go('/settings');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            const TopBar(title: 'Ubah password', fallback: '/settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  AppTextField(label: 'Password lama', controller: _old, password: true, hint: 'Masukkan password lama', errorText: _oldError, onChanged: (_) => setState(() => _oldError = null)),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Password baru',
                    controller: _new,
                    password: true,
                    hint: 'Minimal 8 karakter',
                    helperText: 'Gunakan huruf dan angka',
                    errorText: _newError,
                    onChanged: (_) => setState(() => _newError = null),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(label: 'Ulangi password baru', controller: _again, password: true, hint: 'Ketik ulang password baru', errorText: _againError, onChanged: (_) => setState(() => _againError = null)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot'),
                      style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: AppColors.primary),
                      child: Text('Lupa password lama?', style: AppTypography.text(15, weight: 700, color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppButton(label: 'Simpan password', onPressed: _save),
                ],
              ),
            ),
          ]),
        ),
      );
}
