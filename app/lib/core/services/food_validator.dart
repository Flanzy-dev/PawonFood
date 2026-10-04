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

enum AiVerdict { approved, rejected, pendingReview }

class ValidationResult {
  const ValidationResult({required this.verdict, this.category, this.message, this.confidence = 0, this.detections = const [], this.suggestedName});

  final AiVerdict verdict;
  final FoodCategory? category;
  final String? message;
  final double confidence;
  final List<Detection> detections;

  /// Name pre-filled in the share form. Only the simulation provides one; a real YOLO model only knows the class.
  final String? suggestedName;

  bool get approved => verdict == AiVerdict.approved;
}

const msgNoDetection = 'Tidak ada makanan yang terdeteksi di foto.';
const msgNotFood = 'Gambar terdeteksi bukan makanan. Mohon foto ulang.';

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

/// Photo validation. The MVP ships [SimulatedFoodValidator]; a TFLite (flutter_vision) implementation
/// can replace it once the model from /ml is trained, without touching any UI.
abstract class FoodValidator {
  Future<ValidationResult> validate(String imagePath);
}

/// Demo switch for the simulated validator (long-press the camera title).
enum DemoAiMode {
  normal('Normal: lauk matang'),
  rawIngredients('Bahan mentah'),
  notFood('Bukan makanan (ditolak)'),
  lowConfidence('Ragu-ragu (tinjauan manual)');

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
    final r = decideValidation(switch (m) {
      DemoAiMode.normal => const [Detection(AiClass.makananMatang, 0.86)],
      DemoAiMode.rawIngredients => const [Detection(AiClass.bahanMentah, 0.81)],
      DemoAiMode.notFood => const [Detection(AiClass.bukanMakanan, 0.91)],
      DemoAiMode.lowConfidence => const [Detection(AiClass.makananMatang, 0.55)],
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
