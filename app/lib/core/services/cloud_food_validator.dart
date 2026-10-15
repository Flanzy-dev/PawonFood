import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/enums.dart';
import 'food_validator.dart';

/// Sends the camera photo to the PawonFood validation server (app/server), which asks a Qwen vision model and applies
/// the listing rules. The app holds no model key. Any failure throws [ValidationUnavailable]: a photo is only
/// validated when the server says so in a well-formed answer.
class CloudFoodValidator implements FoodValidator {
  CloudFoodValidator({
    required this.endpoint,
    http.Client? client,
    this.clientToken = '',
    this.timeout = const Duration(seconds: 25),
    Future<List<int>> Function(String path)? readImage,
  })  : _client = client ?? http.Client(),
        _readImage = readImage ?? ((path) => File(path).readAsBytes());

  /// Builds the validator from `--dart-define=PAWON_VALIDATOR_URL=https://host` (base URL of app/server).
  factory CloudFoodValidator.fromBaseUrl(String baseUrl, {String clientToken = ''}) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return CloudFoodValidator(endpoint: Uri.parse('$base/v1/food-validation'), clientToken: clientToken);
  }

  final Uri endpoint;
  final String clientToken;
  final Duration timeout;
  final http.Client _client;
  final Future<List<int>> Function(String path) _readImage;

  @override
  Future<ValidationResult> validate(String imagePath) async {
    final List<int> bytes;
    try {
      bytes = await _readImage(imagePath);
    } on Object {
      throw const ValidationUnavailable(ValidationFailure.uploadRejected);
    }
    final http.Response res;
    try {
      res = await _client
          .post(
            endpoint,
            headers: {'Content-Type': imagePath.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg', if (clientToken.isNotEmpty) 'X-Pawon-Client': clientToken},
            body: bytes,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ValidationUnavailable(ValidationFailure.timeout);
    } on Object {
      throw const ValidationUnavailable(ValidationFailure.network);
    }
    switch (res.statusCode) {
      case 200:
        break;
      case 429:
        throw const ValidationUnavailable(ValidationFailure.rateLimited);
      case 400 || 413 || 415 || 422:
        throw const ValidationUnavailable(ValidationFailure.uploadRejected);
      case 504:
        throw const ValidationUnavailable(ValidationFailure.timeout);
      case 502:
        throw const ValidationUnavailable(ValidationFailure.badResponse);
      default:
        throw const ValidationUnavailable(ValidationFailure.network);
    }
    try {
      return parseCloudValidation(jsonDecode(utf8.decode(res.bodyBytes)));
    } on FormatException {
      throw const ValidationUnavailable(ValidationFailure.badResponse);
    }
  }
}

const _verdicts = {'approved': AiVerdict.approved, 'pending_review': AiVerdict.pendingReview, 'retake': AiVerdict.retake, 'rejected': AiVerdict.rejected};

/// Strictly reads the server's response contract. Anything missing, mistyped or inconsistent is a [FormatException],
/// never a default that could approve a photo.
ValidationResult parseCloudValidation(Object? json) {
  if (json is! Map<String, dynamic>) throw const FormatException('response is not an object');
  T field<T>(String key) {
    final v = json[key];
    if (v is! T) throw FormatException('$key is missing or has the wrong type');
    return v;
  }

  List<String> notes(String key) {
    final v = field<List<dynamic>>(key);
    if (v.any((e) => e is! String)) throw FormatException('$key has a non-text item');
    return v.cast<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  var verdict = _verdicts[field<String>('decision')] ?? (throw const FormatException('unknown decision'));
  final eligible = field<bool>('listing_eligible');
  if (eligible != (verdict == AiVerdict.approved || verdict == AiVerdict.pendingReview)) {
    throw const FormatException('listing_eligible contradicts decision');
  }
  final isFood = field<bool>('is_food');
  if (!isFood && eligible) throw const FormatException('non-food marked eligible');
  final visual = VisualCondition.tryKey(field<String>('visual_condition')) ?? (throw const FormatException('unknown visual_condition'));
  final quality = ImageQuality.tryKey(field<String>('image_quality')) ?? (throw const FormatException('unknown image_quality'));

  final categoryKey = field<String>('category');
  final category = FoodCategory.values.where((c) => c.key == categoryKey).firstOrNull;
  // A category this app version does not know cannot be auto-filled: the provider has to pick it, so the photo goes
  // to manual review instead of straight approval.
  if (category == null && verdict == AiVerdict.approved) verdict = AiVerdict.pendingReview;

  final name = json['food_name'];
  if (name != null && name is! String) throw const FormatException('food_name has the wrong type');
  final foodName = name is String ? name.trim() : '';
  final reason = field<String>('reason').trim();

  return ValidationResult(
    verdict: verdict,
    category: category,
    message: reason.isEmpty ? null : reason,
    suggestedName: foodName.isEmpty ? null : foodName,
    visualCondition: visual,
    imageQuality: quality,
    visibleSigns: notes('visible_signs'),
    warnings: notes('warnings'),
  );
}
