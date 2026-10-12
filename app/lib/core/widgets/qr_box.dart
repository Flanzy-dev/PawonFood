import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_colors.dart';

/// A QR code on a white rounded tile (provider's pickup QR, QRIS). Square modules in ink, like the mockups.
class QrBox extends StatelessWidget {
  const QrBox({super.key, required this.data, this.size = 236, this.semanticLabel = 'Kode QR', this.border = true});

  final String data;
  final double size;
  final String semanticLabel;
  final bool border;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        image: true,
        child: Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.05),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: border ? Border.all(color: AppColors.border) : null,
          ),
          child: QrImageView(
            data: data,
            padding: EdgeInsets.zero,
            backgroundColor: AppColors.surface,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.ink),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.ink),
          ),
        ),
      );
}
