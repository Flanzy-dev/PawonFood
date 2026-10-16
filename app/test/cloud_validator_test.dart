import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawonfood/core/models/enums.dart';
import 'package:pawonfood/core/services/cloud_food_validator.dart';
import 'package:pawonfood/core/services/food_validator.dart';

/// A well-formed server answer (contract in app/server/README.md), with [overrides] applied.
Map<String, Object?> answer([Map<String, Object?> overrides = const {}]) => {
      'is_food': true,
      'category': 'makanan_matang',
      'food_name': 'Ayam goreng',
      'visual_condition': 'no_visible_issues',
      'visible_signs': <String>[],
      'image_quality': 'good',
      'warnings': <String>[],
      'listing_eligible': true,
      'decision': 'approved',
      'reason': 'Foto lolos validasi',
      ...overrides,
    };

void main() {
  group('parseCloudValidation', () {
    test('an approved answer fills category, name and reason; no confidence is invented', () {
      final r = parseCloudValidation(answer({'category': 'bahan_mentah', 'food_name': ' Sayur bayam '}));
      expect(r.verdict, AiVerdict.approved);
      expect(r.category, FoodCategory.bahanMentah);
      expect(r.suggestedName, 'Sayur bayam');
      expect(r.message, 'Foto lolos validasi');
      expect(r.confidence, 0);
      expect(r.eligible, isTrue);
    });

    test('each decision maps to a verdict, and only approved / pending are eligible', () {
      expect(parseCloudValidation(answer({'decision': 'pending_review', 'visual_condition': 'minor_concerns', 'visible_signs': ['daun sedikit layu']})).verdict, AiVerdict.pendingReview);
      final retake = parseCloudValidation(answer({'decision': 'retake', 'listing_eligible': false, 'image_quality': 'blurry'}));
      expect(retake.verdict, AiVerdict.retake);
      expect(retake.eligible, isFalse);
      final spoiled = parseCloudValidation(answer({'decision': 'rejected', 'listing_eligible': false, 'visual_condition': 'visible_spoilage', 'visible_signs': ['jamur hijau']}));
      expect(spoiled.verdict, AiVerdict.rejected);
      expect(spoiled.visualCondition, VisualCondition.visibleSpoilage);
      expect(spoiled.visibleSigns, ['jamur hijau']);
      final notFood = parseCloudValidation(answer({'is_food': false, 'category': 'bukan_makanan', 'food_name': null, 'decision': 'rejected', 'listing_eligible': false}));
      expect(notFood.category, isNull);
      expect(notFood.eligible, isFalse);
    });

    test('an unknown category leaves the category empty; an unexpected one also forces manual review', () {
      final unknown = parseCloudValidation(answer({'category': 'unknown', 'decision': 'pending_review'}));
      expect(unknown.category, isNull);
      expect(unknown.verdict, AiVerdict.pendingReview);
      final future = parseCloudValidation(answer({'category': 'minuman_segar'}));
      expect(future.category, isNull);
      expect(future.verdict, AiVerdict.pendingReview, reason: 'never auto-approve a category the app cannot fill in');
    });

    test('description is optional and trimmed; a wrong type is an error', () {
      expect(parseCloudValidation(answer()).suggestedDescription, isNull, reason: 'a server from before this field');
      expect(parseCloudValidation(answer({'description': null})).suggestedDescription, isNull);
      expect(parseCloudValidation(answer({'description': '   '})).suggestedDescription, isNull);
      expect(parseCloudValidation(answer({'description': '  Ayam goreng bumbu kuning, 4 potong. '})).suggestedDescription, 'Ayam goreng bumbu kuning, 4 potong.');
      expect(() => parseCloudValidation(answer({'description': 12})), throwsFormatException);
    });

    test('health_signals become suggested tags; a server without the field suggests none', () {
      expect(parseCloudValidation(answer()).suggestedHealthTags, isEmpty);
      final r = parseCloudValidation(answer({'health_signals': ['sayur_buah', 'protein', 'direbus_kukus', 'whatever']}));
      expect(r.suggestedHealthTags, {HealthTag.sayurBuah, HealthTag.protein, HealthTag.tidakDigoreng});
    });

    test('"tidak digoreng" needs boiled or steamed and nothing fried; low sugar is never guessed', () {
      expect(parseCloudValidation(answer({'health_signals': ['direbus_kukus', 'digoreng']})).suggestedHealthTags, isEmpty);
      expect(parseCloudValidation(answer({'health_signals': ['rendah_gula']})).suggestedHealthTags, isEmpty);
    });

    test('malformed health_signals are an error', () {
      expect(() => parseCloudValidation(answer({'health_signals': 'protein'})), throwsFormatException);
      expect(() => parseCloudValidation(answer({'health_signals': [1]})), throwsFormatException);
    });

    test('malformed or contradictory answers are errors, never approvals', () {
      final bad = <Object?>[
        null,
        'approved',
        <Object?>[],
        answer({'decision': 'ok'}),
        answer({'decision': null}),
        answer({'listing_eligible': 'yes'}),
        answer({'listing_eligible': false}), // contradicts "approved"
        answer({'decision': 'rejected'}), // eligible but rejected
        answer({'is_food': false}), // non-food marked eligible
        answer({'visual_condition': 'fresh'}),
        answer({'image_quality': null}),
        answer({'visible_signs': 'jamur'}),
        answer({'warnings': [1]}),
        answer({'food_name': 42}),
        answer({'reason': null}),
      ];
      for (final json in bad) {
        expect(() => parseCloudValidation(json), throwsFormatException, reason: '$json');
      }
    });
  });

  group('CloudFoodValidator', () {
    final endpoint = Uri.parse('http://validator.test/v1/food-validation');
    CloudFoodValidator validator(MockClientHandler handler, {Duration timeout = const Duration(seconds: 5), String token = ''}) =>
        CloudFoodValidator(endpoint: endpoint, client: MockClient(handler), timeout: timeout, clientToken: token, readImage: (_) async => [0xff, 0xd8, 0xff, 0xe0]);

    Future<ValidationFailure?> failureOf(Future<ValidationResult> f) async {
      try {
        await f;
        return null;
      } on ValidationUnavailable catch (e) {
        return e.failure;
      }
    }

    test('posts the raw JPEG with the optional client token and parses the answer', () async {
      late http.Request seen;
      final v = validator((req) async {
        seen = req;
        return http.Response(jsonEncode(answer()), 200, headers: {'content-type': 'application/json'});
      }, token: 'demo-token');
      final r = await v.validate('/tmp/photo.jpg');
      expect(r.verdict, AiVerdict.approved);
      expect(seen.method, 'POST');
      expect(seen.url, endpoint);
      expect(seen.headers['Content-Type'], startsWith('image/jpeg'));
      expect(seen.headers['X-Pawon-Client'], 'demo-token');
      expect(seen.bodyBytes, [0xff, 0xd8, 0xff, 0xe0]);
    });

    test('the base URL helper adds the route once', () {
      expect(CloudFoodValidator.fromBaseUrl('https://pawon.example/').endpoint.toString(), 'https://pawon.example/v1/food-validation');
      expect(CloudFoodValidator.fromBaseUrl('http://10.0.2.2:8787').endpoint.toString(), 'http://10.0.2.2:8787/v1/food-validation');
    });

    test('server errors, timeouts and bad bodies all throw ValidationUnavailable', () async {
      expect(await failureOf(validator((_) async => http.Response('{"error":{"code":"model_timeout"}}', 504)).validate('p.jpg')), ValidationFailure.timeout);
      expect(await failureOf(validator((_) async => http.Response('{}', 502)).validate('p.jpg')), ValidationFailure.badResponse);
      expect(await failureOf(validator((_) async => http.Response('{}', 500)).validate('p.jpg')), ValidationFailure.serverError);
      expect(await failureOf(validator((_) async => http.Response('{}', 401)).validate('p.jpg')), ValidationFailure.serverError);
      expect(await failureOf(validator((_) async => http.Response('{}', 429)).validate('p.jpg')), ValidationFailure.rateLimited);
      expect(await failureOf(validator((_) async => http.Response('{}', 422)).validate('p.jpg')), ValidationFailure.uploadRejected);
      expect(await failureOf(validator((_) async => http.Response('<html>proxy</html>', 200)).validate('p.jpg')), ValidationFailure.badResponse);
      expect(await failureOf(validator((_) async => http.Response(jsonEncode(answer({'decision': 'maybe'})), 200)).validate('p.jpg')), ValidationFailure.badResponse);
      expect(await failureOf(validator((_) async => throw http.ClientException('connection refused')).validate('p.jpg')), ValidationFailure.network);
      final slow = validator((_) => Completer<http.Response>().future, timeout: const Duration(milliseconds: 10));
      expect(await failureOf(slow.validate('p.jpg')), ValidationFailure.timeout);
    });

    test('an unreadable photo file is not sent', () async {
      var called = false;
      final v = CloudFoodValidator(endpoint: endpoint, client: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }), readImage: (_) async => throw const FileSystemExceptionStub());
      expect(await failureOf(v.validate('missing.jpg')), ValidationFailure.uploadRejected);
      expect(called, isFalse);
    });
  });
}

class FileSystemExceptionStub implements Exception {
  const FileSystemExceptionStub();
}
