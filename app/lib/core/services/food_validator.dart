import '../models/enums.dart';

/// Classes of the PawonFood YOLO model (see /ml and labels.txt).
enum AiClass {
  makananMatang('makanan_matang'),
  bahanMentah('bahan_mentah'),
  bukanMakanan('bukan_makanan');

  const AiClass(this.key);
  final String key;

  FoodCategory? get category => switch (this) {
        AiClass.makananMatang => FoodCategory.makananMatang,
        AiClass.bahanMentah => FoodCategory.bahanMentah,
        AiClass.bukanMakanan => null,
      };
}

class Detection {
  const Detection(this.cls, this.confidence);
  final AiClass cls;
  final double confidence;
}

/// `retake`: the photo is too poor to judge (blurry, dark, blocked). `rejected`: not food.
enum AiVerdict { approved, rejected, pendingReview, retake }

enum ImageQuality {
  good('good'),
  blurry('blurry'),
  tooDark('too_dark'),
  obstructed('obstructed'),
  tooFar('too_far');

  const ImageQuality(this.key);
  final String key;

  static ImageQuality? tryKey(Object? key) => values.where((v) => v.key == key).firstOrNull;
}

class ValidationResult {
  const ValidationResult({
    required this.verdict,
    this.category,
    this.message,
    this.confidence = 0,
    this.detections = const [],
    this.suggestedName,
    this.suggestedDescription,
    this.imageQuality,
    this.warnings = const [],
    this.suggestedHealthTags = const {},
  });

  final AiVerdict verdict;

  /// Null when the AI could not tell the category: the provider must pick one before publishing.
  final FoodCategory? category;

  /// User-facing reason (Indonesian). The cloud validator always sends one.
  final String? message;

  /// YOLO detection confidence. The cloud validator reports none (no fabricated scores), so it stays 0 there.
  final double confidence;
  final List<Detection> detections;

  /// Name pre-filled in the share form: the simulation's name, or `food_name` from the cloud validator.
  final String? suggestedName;

  /// One short sentence about what the photo shows, pre-filled in the form's "Deskripsi".
  final String? suggestedDescription;
  final ImageQuality? imageQuality;

  /// Short notes about ambiguity ("lebih dari satu jenis makanan"), shown to the provider before publishing.
  final List<String> warnings;

  /// "Pilihan sehat" tags the AI could see (pre-selected in the share form; the provider confirms them).
  final Set<HealthTag> suggestedHealthTags;

  bool get approved => verdict == AiVerdict.approved;

  /// Whether the share form may publish with this result (manual review still publishes, as before).
  bool get eligible => verdict == AiVerdict.approved || verdict == AiVerdict.pendingReview;
}

/// What the cloud model may report in `health_signals` (visible composition and cooking method only).
enum HealthSignal {
  sayurBuah('sayur_buah'),
  protein('protein'),
  digoreng('digoreng'),
  direbusKukus('direbus_kukus');

  const HealthSignal(this.key);
  final String key;

  static HealthSignal? tryKey(Object? key) => values.where((v) => v.key == key).firstOrNull;
}

/// Maps what the model saw to the provider's tags. "Tidak digoreng" needs boiled/steamed and nothing fried;
/// "Rendah gula" cannot be seen in a photo, so it is never suggested.
Set<HealthTag> healthTagsFromSignals(Set<HealthSignal> signals) => {
      if (signals.contains(HealthSignal.sayurBuah)) HealthTag.sayurBuah,
      if (signals.contains(HealthSignal.protein)) HealthTag.protein,
      if (signals.contains(HealthSignal.direbusKukus) && !signals.contains(HealthSignal.digoreng)) HealthTag.tidakDigoreng,
    };

/// Why a photo could not be checked. The photo is then never treated as validated.
enum ValidationFailure { network, timeout, rateLimited, uploadRejected, badResponse, serverError }

class ValidationUnavailable implements Exception {
  const ValidationUnavailable(this.failure);
  final ValidationFailure failure;

  @override
  String toString() => 'ValidationUnavailable(${failure.name})';
}

const msgNoDetection = 'Tidak ada makanan yang terdeteksi di foto.';
const msgNotFood = 'Gambar terdeteksi bukan makanan. Mohon foto ulang.';
// Matches REASONS.blurry in server/src/rules.js.
const msgBlurry = 'Foto buram. Pegang kamera lebih stabil, lalu foto ulang.';

/// Decision rule from ARCHITECTURE.md (identical on device and in the optional server validator):
/// no detections -> rejected; `bukan_makanan` > 0.70 -> rejected; any food class > 0.60 -> approved;
/// otherwise pending manual review.
ValidationResult decideValidation(List<Detection> detections) {
  if (detections.isEmpty) {
    return const ValidationResult(verdict: AiVerdict.rejected, message: msgNoDetection);
  }
  final notFood = detections.where((d) => d.cls == AiClass.bukanMakanan && d.confidence > 0.70);
  if (notFood.isNotEmpty) {
    return ValidationResult(verdict: AiVerdict.rejected, message: msgNotFood, confidence: notFood.first.confidence, detections: detections);
  }
  final food = detections.where((d) => d.cls != AiClass.bukanMakanan && d.confidence > 0.60).toList()..sort((a, b) => b.confidence.compareTo(a.confidence));
  if (food.isNotEmpty) {
    return ValidationResult(verdict: AiVerdict.approved, category: food.first.cls.category, confidence: food.first.confidence, detections: detections);
  }
  return ValidationResult(verdict: AiVerdict.pendingReview, detections: detections);
}

/// Photo validation. The app ships [SimulatedFoodValidator], or `CloudFoodValidator` (Qwen behind app/server) when
/// `PAWON_VALIDATOR_URL` is set. A TFLite (flutter_vision) implementation can replace either without touching any UI.
/// Throws [ValidationUnavailable] when the photo could not be checked.
abstract class FoodValidator {
  Future<ValidationResult> validate(String imagePath);
}

/// Demo switch for the simulated validator (long-press the camera title).
enum DemoAiMode {
  normal('Normal: lauk matang'),
  rawIngredients('Bahan mentah'),
  notFood('Bukan makanan (ditolak)'),
  lowConfidence('Ragu-ragu (tinjauan manual)'),
  blurry('Foto buram (foto ulang)'),
  serverDown('Server AI gagal (coba lagi)');

  const DemoAiMode(this.label);
  final String label;
}

class SimulatedFoodValidator implements FoodValidator {
  SimulatedFoodValidator({required this.mode, this.scanDelay = const Duration(milliseconds: 1600)});

  /// Read at call time so the demo switch takes effect immediately.
  final DemoAiMode Function() mode;
  final Duration scanDelay;

  @override
  Future<ValidationResult> validate(String imagePath) async {
    await Future<void>.delayed(scanDelay);
    final m = mode();
    switch (m) {
      case DemoAiMode.blurry:
        return const ValidationResult(verdict: AiVerdict.retake, message: msgBlurry, imageQuality: ImageQuality.blurry);
      case DemoAiMode.serverDown:
        throw const ValidationUnavailable(ValidationFailure.network);
      case DemoAiMode.normal || DemoAiMode.rawIngredients || DemoAiMode.notFood || DemoAiMode.lowConfidence:
        break;
    }
    final r = decideValidation(switch (m) {
      DemoAiMode.rawIngredients => const [Detection(AiClass.bahanMentah, 0.81)],
      DemoAiMode.notFood => const [Detection(AiClass.bukanMakanan, 0.91)],
      DemoAiMode.lowConfidence => const [Detection(AiClass.makananMatang, 0.55)],
      _ => const [Detection(AiClass.makananMatang, 0.86)],
    });
    return ValidationResult(
      verdict: r.verdict,
      category: r.category,
      message: r.message,
      confidence: r.confidence,
      detections: r.detections,
      suggestedName: r.verdict == AiVerdict.rejected ? null : (m == DemoAiMode.rawIngredients ? 'Wortel dan kol' : 'Ayam goreng'),
      suggestedDescription: r.verdict == AiVerdict.rejected ? null : (m == DemoAiMode.rawIngredients ? 'Wortel dan kol utuh, belum dipotong.' : 'Ayam goreng bumbu kuning, beberapa potong paha dan dada.'),
      suggestedHealthTags: switch (m) {
        _ when r.verdict == AiVerdict.rejected => const {},
        DemoAiMode.rawIngredients => const {HealthTag.sayurBuah, HealthTag.tidakDigoreng},
        _ => const {HealthTag.protein},
      },
    );
  }
}
