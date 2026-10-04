import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Icons drawn from inline SVG paths (Iconify: logos:google-icon, ic:baseline-apple, fluent:eye-12-regular,
/// fluent:eye-off-16-regular). Single-color icons are recolored through a color filter.
class _MonoSvg extends StatelessWidget {
  const _MonoSvg(this.svg, {required this.size, required this.color});

  final String svg;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn), excludeFromSemantics: true);
}

/// Four-color Google "G" for the "Lanjut dengan Google" button.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 262"><path fill="#4285f4" d="M255.878 133.451c0-10.734-.871-18.567-2.756-26.69H130.55v48.448h71.947c-1.45 12.04-9.283 30.172-26.69 42.356l-.244 1.622l38.755 30.023l2.685.268c24.659-22.774 38.875-56.282 38.875-96.027"/><path fill="#34a853" d="M130.55 261.1c35.248 0 64.839-11.605 86.453-31.622l-41.196-31.913c-11.024 7.688-25.82 13.055-45.257 13.055c-34.523 0-63.824-22.773-74.269-54.25l-1.531.13l-40.298 31.187l-.527 1.465C35.393 231.798 79.49 261.1 130.55 261.1"/><path fill="#fbbc05" d="M56.281 156.37c-2.756-8.123-4.351-16.827-4.351-25.82c0-8.994 1.595-17.697 4.206-25.82l-.073-1.73L15.26 71.312l-1.335.635C5.077 89.644 0 109.517 0 130.55s5.077 40.905 13.925 58.602z"/><path fill="#eb4335" d="M130.55 50.479c24.514 0 41.05 10.589 50.479 19.438l36.844-35.974C195.245 12.91 165.798 0 130.55 0C79.49 0 35.393 29.301 13.925 71.947l42.211 32.783c10.59-31.477 39.891-54.251 74.414-54.251"/></svg>';

  @override
  Widget build(BuildContext context) => SvgPicture.string(_svg, width: size, height: size, excludeFromSemantics: true);
}

/// Apple logo for the "Lanjut dengan Apple" button.
class AppleLogo extends StatelessWidget {
  const AppleLogo({super.key, this.size = 20, this.color = AppColors.ink});

  final double size;
  final Color color;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="#000" d="M17.05 20.28c-.98.95-2.05.8-3.08.35c-1.09-.46-2.09-.48-3.24 0c-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8c1.18-.24 2.31-.93 3.57-.84c1.51.12 2.65.72 3.4 1.8c-3.12 1.87-2.38 5.98.48 7.13c-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25c.29 2.58-2.34 4.5-3.74 4.25"/></svg>';

  @override
  Widget build(BuildContext context) => _MonoSvg(_svg, size: size, color: color);
}

/// Password visible: open eye (fluent:eye-12-regular).
class FluentEyeIcon extends StatelessWidget {
  const FluentEyeIcon({super.key, this.size = 24, this.color = AppColors.inkMuted});

  final double size;
  final Color color;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 12"><path fill="#000" d="M1.974 6.659a.5.5 0 0 1-.948-.317c-.01.03 0-.001 0-.001a2 2 0 0 1 .062-.162c.04-.095.099-.226.18-.381c.165-.31.422-.723.801-1.136C2.834 3.827 4.087 3 6 3s3.166.827 3.931 1.662a5.5 5.5 0 0 1 .98 1.517l.046.113c.003.008.013.06.023.11L11 6.5s.084.333-.342.474a.5.5 0 0 1-.632-.314v-.003l-.006-.016l-.031-.078a4.5 4.5 0 0 0-.795-1.226C8.584 4.674 7.587 4 6 4s-2.584.673-3.194 1.338a4.5 4.5 0 0 0-.795 1.225l-.03.078zM6 5a2 2 0 1 0 0 4a2 2 0 0 0 0-4M5 7a1 1 0 1 1 2 0a1 1 0 0 1-2 0"/></svg>';

  @override
  Widget build(BuildContext context) => _MonoSvg(_svg, size: size, color: color);
}

/// Password hidden: eye with a slash (fluent:eye-off-16-regular).
class FluentEyeOffIcon extends StatelessWidget {
  const FluentEyeOffIcon({super.key, this.size = 24, this.color = AppColors.inkMuted});

  final double size;
  final Color color;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path fill="#000" d="m10.12 10.827l4.026 4.027a.5.5 0 0 0 .708-.708l-13-13a.5.5 0 1 0-.708.708l3.23 3.23A6 6 0 0 0 3.2 6.182a6.7 6.7 0 0 0-1.117 1.982c-.021.061-.047.145-.047.145l-.018.062s-.076.497.355.611a.5.5 0 0 0 .611-.355l.001-.003l.008-.025l.035-.109a5.7 5.7 0 0 1 .945-1.674a5 5 0 0 1 1.124-1.014L6.675 7.38a2.5 2.5 0 1 0 3.446 3.446m-.74-.74A1.5 1.5 0 1 1 7.413 8.12zM6.32 4.2l.854.854Q7.564 5 8 5c2.044 0 3.286.912 4.028 1.817a5.7 5.7 0 0 1 .945 1.674q.025.073.035.109l.008.025v.003l.001.001a.5.5 0 0 0 .966-.257v-.003l-.001-.004l-.004-.013a2 2 0 0 0-.06-.187a6.7 6.7 0 0 0-1.117-1.982C11.905 5.089 10.396 4 8.002 4c-.618 0-1.177.072-1.681.199"/></svg>';

  @override
  Widget build(BuildContext context) => _MonoSvg(_svg, size: size, color: color);
}
