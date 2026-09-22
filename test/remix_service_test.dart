import 'dart:async';
import 'dart:convert';
import 'package:cooking_daddy/data/models/recipe.dart';
import 'package:cooking_daddy/services/gemini_service.dart';
import 'package:cooking_daddy/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isar/isar.dart';

void main() {
  late Recipe source;
  final generated = {
    'name': 'Tofu stir-fry',
    'category': 'dinner',
    'tags': ['vegetarian'],
    'ingredients': [
      {'name': 'tofu', 'quantity': 300, 'unit': 'g'},
    ],
    'tools': [
      {'name': 'pan', 'quantity': 1},
    ],
    'steps': [
      {
        'instruction': 'Fry the tofu.',
        'time': 120,
        'whatToLookFor': 'Golden edges',
      },
    ],
    'imageUrl': 'https://example.com/old-photo.jpg',
    'url': 'https://example.com/original',
  };

  setUp(() {
    source = Recipe(
      cloudId: 'source-id',
      name: 'Beef stir-fry',
      categoryKey: 'dinner',
      ingredients: [
        Ingredient(name: 'beef', quantity: 300, unit: MeasurementUnit.g),
      ],
      tools: [Tool(name: 'pan', quantity: 1)],
      steps: [Step(instruction: 'Fry the beef.', timer: 180)],
      basePortions: 2,
      createdDate: DateTime(2026),
      updatedAt: DateTime(2026),
      isFavorite: true,
      isSeed: true,
      energyNote: 'Old note',
    )..id = 42;
  });

  test(
    'sends the full source and returns an independent unsaved AI draft',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/remix');
        final body = jsonDecode(request.body);
        expect(body['instructions'], 'Use tofu');
        expect(body['language'], 'vi');
        expect(body['recipe']['basePortions'], 2);
        expect(body['recipe']['ingredients'][0]['quantity'], 300);
        expect(body['recipe']['ingredients'][0]['unit'], 'g');
        expect(body['recipe']['steps'][0]['time'], 180);
        return http.Response(
          jsonEncode({'success': true, 'recipe': generated}),
          200,
        );
      });
      final result = await GeminiService(client: client).remixRecipe(
        source: source,
        instructions: ' Use tofu ',
        languageCode: 'vi',
      );
      expect(result.success, isTrue);
      final remix = result.recipe!;
      expect(remix.id, Isar.autoIncrement);
      expect(
        remix.cloudId,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(remix.cloudId, isNot(source.cloudId));
      expect(remix.sourceRecipeId, source.cloudId);
      expect(remix.basePortions, 2);
      expect(remix.name, 'Tofu stir-fry');
      expect(remix.ingredients.single.name, 'tofu');
      expect(remix.steps.single.timer, 120);
      expect(remix.isFavorite, isFalse);
      expect(remix.isSeed, isFalse);
      expect(remix.energyNote, isNull);
      expect(remix.imageUrl, isNull);
      expect(remix.url, isNull);
      expect(source.ingredients.single.name, 'beef');
      expect(source.id, 42);
    },
  );

  test('smart generation sends actual coordinates and uses the same recipe parser', () async {
    final service = GeminiService(client: MockClient((request) async {
      final body = jsonDecode(request.body);
      expect(request.url.path, '/api/smart-generate');
      expect(body['location'], {'latitude': 10.78, 'longitude': 106.7});
      expect(body['language'], 'vi');
      expect(body['localHour'], inInclusiveRange(0, 23));
      return http.Response(jsonEncode({'success': true, 'recipe': generated}), 200);
    }));
    final result = await service.generateFromIngredients(ingredients: 'tofu', languageCode: 'vi',
      location: const RecipeLocation(latitude: 10.78, longitude: 106.7));
    expect(result.success, isTrue);
    expect(result.recipe!.ingredients.single.name, 'tofu');
    expect(result.recipe!.steps.single.timer, 120);
    expect(result.recipe!.id, Isar.autoIncrement);
  });

  test('smart generation without permission sends no default location', () async {
    final service = GeminiService(client: MockClient((request) async {
      expect(jsonDecode(request.body).containsKey('location'), isFalse);
      return http.Response('{"success":false,"error_code":"ai_not_configured"}', 503);
    }));
    final result = await service.generateFromIngredients(ingredients: 'rice');
    expect(result.error, 'ai_not_configured');
    expect(result.recipe, isNull);
  });

  test('a remix of a remix retains the original source link', () async {
    source.sourceRecipeId = 'root-id';
    final service = GeminiService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'success': true, 'recipe': generated}),
          200,
        ),
      ),
    );
    final result = await service.remixRecipe(
      source: source,
      instructions: '',
      languageCode: 'en',
    );
    expect(result.recipe!.sourceRecipeId, 'root-id');
  });

  for (final entry in {
    'quota': (429, '', 'ai_quota_error'),
    'server unavailable': (503, '{"success":false}', 'ai_generation_error'),
    'invalid JSON': (200, '<html>Error</html>', 'ai_generation_error'),
    'missing recipe': (200, '{"success":true}', 'ai_generation_error'),
    'configuration missing': (
      503,
      '{"success":false,"error_code":"ai_not_configured"}',
      'ai_not_configured',
    ),
    'empty recipe': (
      200,
      '{"success":true,"recipe":{"steps":[]}}',
      'ai_invalid_recipe',
    ),
  }.entries) {
    test('handles ${entry.key} without creating a draft', () async {
      final service = GeminiService(
        client: MockClient(
          (_) async => http.Response(entry.value.$2, entry.value.$1),
        ),
      );
      final result = await service.remixRecipe(
        source: source,
        instructions: '',
        languageCode: 'en',
      );
      expect(result.success, isFalse);
      expect(result.recipe, isNull);
      expect(result.error, entry.value.$3);
    });
  }

  test(
    'connection and timeout failures are retryable localized errors',
    () async {
      for (final failure in [
        http.ClientException('offline'),
        TimeoutException('timeout'),
      ]) {
        final service = GeminiService(
          client: MockClient((_) async => throw failure),
        );
        final result = await service.remixRecipe(
          source: source,
          instructions: '',
          languageCode: 'en',
        );
        expect(result.recipe, isNull);
        expect(
          result.error,
          failure is TimeoutException
              ? 'ai_timeout_error'
              : 'ai_connection_error',
        );
      }
    },
  );
}
