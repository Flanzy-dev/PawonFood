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

/// `retake`: the photo is too poor to judge (blurry, dark, blocked). `rejected`: not food, or visibly spoiled.
enum AiVerdict { approved, rejected, pendingReview, retake }

/// What the photo shows about the food's surface (cloud validator only). Visual only: never a safety verdict.
enum VisualCondition {
  noVisibleIssues('no_visible_issues'),
  minorConcerns('minor_concerns'),
  visibleSpoilage('visible_spoilage'),
  cannotAssess('cannot_assess');

  const VisualCondition(this.key);
  final String key;

  static VisualCondition? tryKey(Object? key) => values.where((v) => v.key == key).firstOrNull;
}

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
    this.visualCondition,
    this.imageQuality,
    this.visibleSigns = const [],
    this.warnings = const [],
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
  final VisualCondition? visualCondition;
  final ImageQuality? imageQuality;

  /// Visible signs such as "daun sedikit layu", shown to the provider before publishing.
  final List<String> visibleSigns;
  final List<String> warnings;

  bool get approved => verdict == AiVerdict.approved;

  /// Whether the share form may publish with this result (manual review still publishes, as before).
  bool get eligible => verdict == AiVerdict.approved || verdict == AiVerdict.pendingReview;
}

/// Why a photo could not be checked. The photo is then never treated as validated.
enum ValidationFailure { network, timeout, rateLimited, uploadRejected, badResponse }

class ValidationUnavailable implements Exception {
  const ValidationUnavailable(this.failure);
  final ValidationFailure failure;

  @override
  String toString() => 'ValidationUnavailable(${failure.name})';
}

const msgNoDetection = 'Tidak ada makanan yang terdeteksi di foto.';
const msgNotFood = 'Gambar terdeteksi bukan makanan. Mohon foto ulang.';
// The two below match REASONS in server/src/rules.js.
const msgBlurry = 'Foto buram. Pegang kamera lebih stabil, lalu foto ulang.';
const msgSpoiled = 'Terlihat tanda makanan tidak layak, misalnya jamur atau busuk. Makanan ini tidak bisa dibagikan.';

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
  spoiled('Tanda basi (ditolak)'),
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
        return const ValidationResult(verdict: AiVerdict.retake, message: msgBlurry, imageQuality: ImageQuality.blurry, visualCondition: VisualCondition.cannotAssess);
      case DemoAiMode.spoiled:
        return const ValidationResult(
          verdict: AiVerdict.rejected,
          category: FoodCategory.makananMatang,
          message: msgSpoiled,
          imageQuality: ImageQuality.good,
          visualCondition: VisualCondition.visibleSpoilage,
          visibleSigns: ['Bercak jamur putih di permukaan nasi'],
        );
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
      suggestedName: r.verdict == AiVerdict.rejected ? null : (m == DemoAiMode.rawIngredients ? 'Sayur mentah' : 'Ayam goreng'),
    );
  }
}
