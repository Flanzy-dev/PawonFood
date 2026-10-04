import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/person.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

Color avatarColor(AvatarTone tone) => switch (tone) {
      AvatarTone.primary => AppColors.primary,
      AvatarTone.olive => AppColors.avatarOlive,
      AvatarTone.taupe => AppColors.avatarTaupe,
    };

/// Circle with cream initials.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar(this.person, {super.key, this.size = 48});

  final Person person;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: avatarColor(person.tone), shape: BoxShape.circle),
        child: Text(person.initials, style: AppTypography.text(size * 0.36, weight: 700, color: AppColors.background)),
      );
}
