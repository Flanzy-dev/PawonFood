import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/services/food_validator.dart';

/// The photo taken in step 1 and the AI check running on it in the background. [result] and [failure] are both null
/// while the check is running; a failed check never counts as validated.
class ShareCapture {
  const ShareCapture({required this.photoPath, this.result, this.failure});

  final String photoPath;
  final ValidationResult? result;
  final ValidationFailure? failure;

  bool get checking => result == null && failure == null;
  bool get eligible => result?.eligible ?? false;
}

class ShareCaptureNotifier extends Notifier<ShareCapture?> {
  var _disposed = false;

  @override
  ShareCapture? build() {
    ref.onDispose(() => _disposed = true);
    return null;
  }

  /// Starts checking [path] without blocking the caller. A slower answer for an earlier photo never overwrites the
  /// state of a newer one.
  Future<void> start(String path) async {
    state = ShareCapture(photoPath: path);
    ShareCapture next;
    try {
      next = ShareCapture(photoPath: path, result: await ref.read(foodValidatorProvider).validate(path));
    } on Object catch (e) {
      next = ShareCapture(photoPath: path, failure: e is ValidationUnavailable ? e.failure : ValidationFailure.badResponse);
    }
    if (!_disposed && state?.photoPath == path) state = next;
  }

  /// Checks the current photo again ("Coba lagi").
  Future<void> retry() async {
    final path = state?.photoPath;
    if (path != null) await start(path);
  }

  void clear() => state = null;
}

final shareCaptureProvider = NotifierProvider<ShareCaptureNotifier, ShareCapture?>(ShareCaptureNotifier.new);

String validationFailureText(ValidationFailure? f) => switch (f) {
      ValidationFailure.rateLimited => 'Terlalu banyak percobaan. Tunggu sebentar, lalu coba lagi.',
      ValidationFailure.uploadRejected => 'Foto ini tidak bisa diperiksa. Coba foto ulang.',
      ValidationFailure.timeout => 'Pemeriksaan terlalu lama. Periksa koneksi internet, lalu coba lagi.',
      ValidationFailure.serverError => 'Pemeriksaan foto sedang bermasalah. Coba lagi sebentar lagi.',
      _ => 'Foto belum bisa diperiksa. Periksa koneksi internet, lalu coba lagi.',
    };
