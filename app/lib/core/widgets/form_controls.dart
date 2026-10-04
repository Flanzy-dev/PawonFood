import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'brand_icons.dart';

/// Groups digits with dots while typing (5000 -> 5.000), like the price format in the design.
class ThousandsFormatter extends TextInputFormatter {
  const ThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Parses "5.000" back to 5000.
int? parseAmount(String text) => int.tryParse(text.replaceAll('.', ''));

/// Two-option segmented control (Gratis / Jual murah, Saya menerima / Saya berbagi). Sand track, selected white.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({super.key, required this.options, required this.selected, required this.onChanged, this.badges});

  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  /// Optional unread counts, same length as [options].
  final List<int>? badges;

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: AppColors.surfaceSand, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == selected,
                  label: options[i],
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == selected ? AppColors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: i == selected ? const [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1))] : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(options[i], style: AppTypography.text(16, weight: i == selected ? 700 : 600, color: i == selected ? AppColors.ink : AppColors.inkMuted)),
                          if (badges != null && badges![i] > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                              child: Text('${badges![i]}', style: AppTypography.text(13, weight: 700, color: AppColors.background)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// "−" sand circle, value, "+" green circle.
class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 99});

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) => Container(
        width: 140,
        height: 56,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.border)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _RoundButton(icon: LucideIcons.minus, fill: AppColors.surfaceSand, color: AppColors.ink, label: 'Kurangi porsi', onTap: value > min ? () => onChanged(value - 1) : null),
            Text('$value', style: AppTypography.text(20, weight: 700)),
            _RoundButton(icon: LucideIcons.plus, fill: AppColors.primary, color: AppColors.background, label: 'Tambah porsi', onTap: value < max ? () => onChanged(value + 1) : null),
          ],
        ),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.fill, required this.color, required this.label, required this.onTap});

  final IconData icon;
  final Color fill;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        child: Material(
          color: onTap == null ? fill.withValues(alpha: 0.5) : fill,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: color))),
        ),
      );
}

/// Equal-width pickup deadline chips (19.00 / 20.30 / 22.00). Times that already passed are disabled.
class TimeChips extends StatelessWidget {
  const TimeChips({super.key, required this.times, required this.selected, required this.now, required this.onSelected});

  final List<DateTime> times;
  final DateTime? selected;
  final DateTime now;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 0; i < times.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _chip(times[i])),
          ],
        ],
      );

  Widget _chip(DateTime t) {
    final enabled = t.isAfter(now);
    final on = selected != null && selected!.isAtSameMomentAs(t);
    return Semantics(
      button: true,
      selected: on,
      enabled: enabled,
      label: 'Ambil paling lambat ${formatTime(t)}',
      child: Material(
        color: on ? AppColors.primary : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: on ? AppColors.primary : AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? () => onSelected(t) : null,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            child: Text(
              formatTime(t),
              style: AppTypography.text(16, weight: 700, color: on ? AppColors.background : (enabled ? AppColors.ink : AppColors.inkMuted.withValues(alpha: 0.5))),
            ),
          ),
        ),
      ),
    );
  }
}

/// Green checkbox with a label widget.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({super.key, required this.value, required this.onChanged, required this.label, this.textSize = 14});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final double textSize;

  @override
  Widget build(BuildContext context) => Semantics(
        checked: value,
        label: label,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: value ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: value ? null : Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: value ? const Icon(LucideIcons.check, size: 16, color: AppColors.background) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(label, style: AppTypography.text(textSize, weight: 500, height: textSize * 1.4)))),
              ],
            ),
          ),
        ),
      );
}

/// Text field with a label above, error text with an icon below (never color-only), and an optional eye toggle.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.helperText,
    this.password = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.suffixText,
    this.inputFormatters,
    this.focusNode,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final bool password;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? prefix;
  final String? suffixText;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.password;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: w));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(widget.label, style: AppTypography.display(16, weight: 700, height: 22)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          inputFormatters: widget.inputFormatters,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: AppTypography.text(16, weight: 500),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTypography.text(16, color: AppColors.inkMuted),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            prefixIcon: widget.prefix == null ? null : Padding(padding: const EdgeInsets.only(left: 16, right: 8), child: Text(widget.prefix!, style: AppTypography.text(16, weight: 700, color: AppColors.inkMuted))),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixText: widget.suffixText,
            suffixStyle: AppTypography.text(14, color: AppColors.inkMuted),
            suffixIcon: widget.password
                ? IconButton(
                    tooltip: _obscured ? 'Tampilkan password' : 'Sembunyikan password',
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: _obscured ? const FluentEyeOffIcon() : const FluentEyeIcon(),
                  )
                : null,
            enabledBorder: border(hasError ? AppColors.error : AppColors.border, hasError ? 1.5 : 1),
            focusedBorder: border(hasError ? AppColors.error : AppColors.primary, 1.5),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 1), child: Icon(LucideIcons.triangleAlert, size: 16, color: AppColors.error)),
            const SizedBox(width: 6),
            Expanded(child: Text(widget.errorText!, style: AppTypography.text(13, weight: 600, height: 18, color: AppColors.error))),
          ]),
        ] else if (widget.helperText != null) ...[
          const SizedBox(height: 6),
          Text(widget.helperText!, style: AppTypography.text(13, height: 18, color: AppColors.inkMuted)),
        ],
      ],
    );
  }
}
