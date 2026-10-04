import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Tungku-Lensa mark (the Bagikan FAB and shutter logo), recolorable.
class PawonLogo extends StatelessWidget {
  const PawonLogo({super.key, this.size = 32, this.color = AppColors.primary});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/images/brand/logo_tungku.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        semanticsLabel: 'PawonFood',
      );
}

/// "PawonFood" brush wordmark (transparent PNG).
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.width = 190});

  final double width;

  @override
  Widget build(BuildContext context) => Image.asset('assets/images/brand/wordmark.png', width: width, fit: BoxFit.contain, semanticLabel: 'PawonFood');
}

/// Fluent "full screen maximize" icon (fluent:full-screen-maximize-16-filled), used by the map CTA.
class FullscreenIcon extends StatelessWidget {
  const FullscreenIcon({super.key, this.size = 20, this.color = AppColors.background});

  final double size;
  final Color color;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path fill="#000" d="M4 3.5a.5.5 0 0 0-.5.5v1.614a.75.75 0 0 1-1.5 0V4a2 2 0 0 1 2-2h1.614a.75.75 0 0 1 0 1.5zm5.636-.75a.75.75 0 0 1 .75-.75H12a2 2 0 0 1 2 2v1.614a.75.75 0 0 1-1.5 0V4a.5.5 0 0 0-.5-.5h-1.614a.75.75 0 0 1-.75-.75M2.75 9.636a.75.75 0 0 1 .75.75V12a.5.5 0 0 0 .5.5h1.614a.75.75 0 0 1 0 1.5H4a2 2 0 0 1-2-2v-1.614a.75.75 0 0 1 .75-.75m10.5 0a.75.75 0 0 1 .75.75V12a2 2 0 0 1-2 2h-1.614a.75.75 0 1 1 0-1.5H12a.5.5 0 0 0 .5-.5v-1.614a.75.75 0 0 1 .75-.75"/></svg>';

  @override
  Widget build(BuildContext context) => SvgPicture.string(_svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
}
