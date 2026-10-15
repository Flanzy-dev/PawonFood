import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/food_validator.dart';

/// The photo taken in step 1 and the AI verdict, handed to the review form (step 2).
class ShareCapture {
  const ShareCapture({required this.photoPath, required this.result});

  final String photoPath;
  final ValidationResult result;
}

final shareCaptureProvider = StateProvider<ShareCapture?>((ref) => null);
