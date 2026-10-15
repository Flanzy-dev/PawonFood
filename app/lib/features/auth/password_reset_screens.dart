import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/motion/entrance.dart';
import '../../core/motion/motion.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/top_bar.dart';

/// Shared layout of the three password-reset steps: back button, big title, short line, then the form.
class _ResetLayout extends StatelessWidget {
  const _ResetLayout({required this.title, required this.body, required this.children, this.fallback = '/login'});

  final String title;
  final String body;
  final List<Widget> children;
  final String fallback;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: EntranceScope(
            child: Column(children: [
              TopBar(fallback: fallback),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    FadeSlideIn(child: Text(title, style: AppTypography.titleXl)),
                    const SizedBox(height: 8),
                    FadeSlideIn(index: 1, child: Text(body, style: AppTypography.text(15, height: 22, color: AppColors.inkMuted))),
                    const SizedBox(height: 20),
                    for (final (i, c) in children.indexed) FadeSlideIn(index: 2 + i, child: c),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
}

/// A4c Lupa password: email or phone, then a code is "sent" (simulated).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _contact = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  void _send() {
    final error = Validators.emailOrPhone(_contact.text);
    setState(() => _error = error);
    if (error == null) context.push('/forgot/code', extra: _contact.text.trim());
  }

  @override
  Widget build(BuildContext context) => _ResetLayout(
        title: 'Lupa password?',
        body: 'Masukkan email atau nomor HP yang kamu daftarkan. Kami kirim kode untuk membuat password baru.',
        children: [
          AppTextField(
            label: 'Email atau nomor HP',
            controller: _contact,
            hint: 'contoh@email.com',
            errorText: _error,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: 24),
          AppButton(label: 'Kirim kode', onPressed: _send),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: AppColors.primary),
              child: Text('Kembali ke Masuk', style: AppTypography.text(15, weight: 700, color: AppColors.primary)),
            ),
          ),
        ],
      );
}

/// "r***@email.com"
String maskContact(String c) {
  final at = c.indexOf('@');
  if (at > 0) return '${c[0]}***${c.substring(at)}';
  return c.length > 4 ? '${'*' * (c.length - 4)}${c.substring(c.length - 4)}' : c;
}

/// A4d Cek email kamu: 6 code boxes and a resend timer. Any 6 digits are accepted (no backend yet).
class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key, required this.contact});

  final String contact;

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  var _wait = 60;
  var _shake = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _focus.addListener(() => setState(() {}));
  }

  void _startTimer() {
    _timer?.cancel();
    _wait = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _verify() {
    if (_code.text.length < 6) {
      HapticFeedback.lightImpact();
      // The shake is skipped under reduced motion, so the problem is also said in words.
      setState(() {
        _shake++;
        _error = 'Masukkan 6 angka kode dari emailmu.';
      });
      return;
    }
    context.pushReplacement('/forgot/new');
  }

  @override
  Widget build(BuildContext context) {
    final digits = _code.text;
    return _ResetLayout(
      title: 'Cek email kamu',
      body: 'Kami kirim kode 6 digit ke ${maskContact(widget.contact)}.',
      fallback: '/forgot',
      children: [
        // A hidden field drives the six boxes, so paste and the number keyboard just work.
        GestureDetector(
          onTap: () => _focus.requestFocus(),
          child: Stack(children: [
            // Invisible but kept in the semantics tree: this is the field screen readers focus and type into.
            Opacity(
              opacity: 0,
              alwaysIncludeSemantics: true,
              child: SizedBox(
                height: 64,
                child: Semantics(
                  label: 'Kode verifikasi, 6 angka',
                  child: TextField(
                    controller: _code,
                    focusNode: _focus,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      setState(() => _error = null);
                      if (v.length == 6) _verify();
                    },
                  ),
                ),
              ),
            ),
            TweenAnimationBuilder<double>(
              key: ValueKey(_shake),
              tween: Tween(begin: _shake == 0 ? 0 : 1, end: 0),
              duration: Motion.of(context, const Duration(milliseconds: 360)),
              // A short, damped side-to-side shake when the code is incomplete.
              builder: (_, t, child) => Transform.translate(offset: Offset(8 * t * math.sin(t * math.pi * 6), 0), child: child),
              child: ExcludeSemantics(
                child: Row(children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: Motion.of(context, Motion.fast),
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _focus.hasFocus && i == digits.length ? AppColors.primary : AppColors.border, width: _focus.hasFocus && i == digits.length ? 1.6 : 1),
                        ),
                        // Typed digits appear instantly: keystrokes are never animated.
                        child: Text(i < digits.length ? digits[i] : '', style: AppTypography.display(26)),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 1), child: Icon(LucideIcons.triangleAlert, size: 16, color: AppColors.error)),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!, style: AppTypography.text(13, weight: 600, height: 18, color: AppColors.error))),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        Center(
          child: _wait > 0
              ? Text('Kirim ulang kode dalam ${(_wait ~/ 60).toString().padLeft(2, '0')}:${(_wait % 60).toString().padLeft(2, '0')}', style: AppTypography.text(14, color: AppColors.inkMuted))
              : TextButton(
                  onPressed: () {
                    setState(_startTimer);
                    showAppSnack(context, 'Kode baru sudah dikirim.');
                  },
                  child: Text('Kirim ulang kode', style: AppTypography.text(14, weight: 700, color: AppColors.primary)),
                ),
        ),
        const SizedBox(height: 16),
        AppButton(label: 'Verifikasi', onPressed: _verify),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/forgot'),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: AppColors.primary),
            child: Text('Salah alamat? Ganti email', style: AppTypography.text(15, weight: 700, color: AppColors.primary)),
          ),
        ),
      ],
    );
  }
}

/// A4e Buat password baru.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _new = TextEditingController();
  final _again = TextEditingController();
  String? _newError;
  String? _againError;

  @override
  void dispose() {
    _new.dispose();
    _again.dispose();
    super.dispose();
  }

  void _save() {
    setState(() {
      _newError = Validators.password(_new.text);
      _againError = _again.text != _new.text ? 'Password tidak sama' : null;
    });
    if (_newError != null || _againError != null) return;
    showAppSnack(context, 'Password baru tersimpan. Silakan masuk.');
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) => _ResetLayout(
        title: 'Buat password baru',
        body: 'Password baru harus berbeda dari yang lama.',
        children: [
          AppTextField(label: 'Password baru', controller: _new, password: true, hint: 'Minimal 8 karakter', helperText: 'Gunakan huruf dan angka', errorText: _newError, onChanged: (_) => setState(() => _newError = null)),
          const SizedBox(height: 16),
          AppTextField(label: 'Ulangi password', controller: _again, password: true, hint: 'Ketik ulang password', errorText: _againError, onChanged: (_) => setState(() => _againError = null)),
          const SizedBox(height: 28),
          AppButton(label: 'Simpan password', onPressed: _save),
        ],
      );
}
