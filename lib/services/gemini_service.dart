import 'dart:convert';
import '../data/models/recipe_tags.dart';
import 'package:http/http.dart' as http;
import '../data/models/recipe.dart';
import 'ai_interface.dart';
import 'location_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'step_activity.dart';

class GeminiService implements AIInterface {
  final String baseUrl = 'http://localhost:2975';
  final http.Client? _client;

  GeminiService({http.Client? client}) : _client = client;

  @override
  Future<AIGenerationResult> remixRecipe({
    required Recipe source,
    required String instructions,
    required String languageCode,
  }) async {
    try {
      final response = await (_client?.post ?? http.post)(
        Uri.parse('$baseUrl/api/remix'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'instructions': instructions.trim(),
          'language': languageCode,
          'recipe': {
            'name': source.name,
            'category': source.categoryKey,
            'tags': source.tags,
            'basePortions': source.basePortions,
            'ingredients': source.ingredients
                .map(
                  (item) => {
                    'name': item.name,
                    'quantity': item.quantity,
                    'unit': item.unit?.name,
                    'note': item.note,
                  },
                )
                .toList(),
            'tools': source.tools
                .map((item) => {'name': item.name, 'quantity': item.quantity})
                .toList(),
            'steps': source.steps
                .map(
                  (step) => {
                    'instruction': step.instruction,
                    'heat': step.heat,
                    'seasoning': step.seasonings,
                    'time': step.timer,
                    'notes': step.notes,
                    'whatToLookFor': step.whatToLookFor,
                    'activityType': StepActivityResolver.resolve(step).name,
                  },
                )
                .toList(),
          },
        }),
      ).timeout(const Duration(seconds: 60));

      final result = _readRecipeResponse(response);
      if (!result.success || result.recipe == null) return result;
      final remix = result.recipe!;
      remix.basePortions = source.basePortions;
      remix.sourceRecipeId = source.sourceRecipeId ?? source.cloudId;
      // The original photo and energy note may no longer describe this variation.
      remix.url = null;
      remix.imageUrl = null;
      return result;
    } on TimeoutException {
      return AIGenerationResult(success: false, error: 'ai_timeout_error');
    } on SocketException {
      return AIGenerationResult(success: false, error: 'ai_connection_error');
    } on http.ClientException {
      return AIGenerationResult(success: false, error: 'ai_connection_error');
    } catch (_) {
      return AIGenerationResult(success: false, error: 'ai_generation_error');
    }
  }

  @override
  Future<AIGenerationResult> generateFromIngredients({
    required String ingredients,
    String? tools,
    String? dish,
    String sessionLength = 'normal',
    String difficulty = 'normal',
    RecipeLocation? location,
    String languageCode = 'en',
  }) async {
    try {
      final body = <String, dynamic>{
        'ingredients': ingredients,
        'sessionLength': sessionLength,
        'difficulty': difficulty,
        'language': languageCode,
        'localHour': DateTime.now().hour,
        if (location != null) 'location': location.toJson(),
      };

      // Add optional fields only if provided
      if (tools != null && tools.isNotEmpty) {
        body['tools'] = tools;
      }
      if (dish != null && dish.isNotEmpty) {
        body['dish'] = dish;
      }

      final response = await (_client?.post ?? http.post)(
        Uri.parse('$baseUrl/api/smart-generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 60));

      return _readRecipeResponse(response);
    } on TimeoutException {
      return AIGenerationResult(success: false, error: 'ai_timeout_error');
    } on SocketException {
      return AIGenerationResult(success: false, error: 'ai_connection_error');
    } on http.ClientException {
      return AIGenerationResult(success: false, error: 'ai_connection_error');
    } catch (_) {
      return AIGenerationResult(success: false, error: 'ai_generation_error');
    }
  }

  AIGenerationResult _readRecipeResponse(http.Response response) {
    if (response.statusCode == 429) {
      return AIGenerationResult(success: false, error: 'ai_quota_error');
    }
    if (response.statusCode == 404) {
      return AIGenerationResult(success: false, error: 'ai_endpoint_missing');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 ||
        !_isSuccess(data) ||
        data['recipe'] is! Map) {
      const knownErrors = {
        'ai_not_configured',
        'ai_invalid_recipe',
        'ai_quota_error',
      };
      return AIGenerationResult(
        success: false,
        error: knownErrors.contains(data['error_code'])
            ? data['error_code']
            : 'ai_generation_error',
      );
    }
    final recipe = _convertToRecipe(data['recipe']);
    if (recipe.name.trim().isEmpty ||
        recipe.ingredients.isEmpty ||
        recipe.steps.isEmpty ||
        recipe.steps.any((step) => step.instruction.trim().isEmpty)) {
      return AIGenerationResult(success: false, error: 'ai_invalid_recipe');
    }
    return AIGenerationResult(
      success: true,
      recipe: recipe,
      remainingQuota: _toInt(data['remaining_quota']),
    );
  }

  @override
  Future<AIGenerationResult> generateFromUrl(String url) async {
    try {
      print('🔵 Calling: $baseUrl/api/generate-from-url');
      print('🔵 URL: $url');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/generate-from-url'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url}),
          )
          .timeout(const Duration(seconds: 60));

      // final response = await http
      //     .get(
      //       Uri.parse('$baseUrl/api/generate-from-url'),
      //       headers: {'Content-Type': 'application/json'},
      //       // body: jsonEncode({'url': url}),
      //     )
      // .timeout(const Duration(seconds: 60));

      print('🟢 Response status: ${response.statusCode}');
      print('🟢 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (_isSuccess(data) && data['recipe'] != null) {
          final recipe = _convertToRecipe(data['recipe']);
          print('✅ Recipe converted: ${recipe.name}');

          return AIGenerationResult(
            success: true,
            recipe: recipe,
            remainingQuota: data['remaining_quota'],
          );
        } else {
          print('❌ Server returned success=false');
          return AIGenerationResult(
            success: false,
            error: data['error'] ?? 'Unknown error',
          );
        }
      } else if (response.statusCode == 429) {
        return AIGenerationResult(
          success: false,
          error: 'Daily quota exceeded',
        );
      } else {
        print('❌ Error status: ${response.statusCode}');
        final data = jsonDecode(response.body);
        return AIGenerationResult(
          success: false,
          error: data['error'] ?? 'Generation failed',
        );
      }
    } on TimeoutException catch (e) {
      print('🔴 TIMEOUT: $e');
      return AIGenerationResult(success: false, error: 'Request timed out');
    } on SocketException catch (e) {
      print('🔴 SOCKET: $e');
      return AIGenerationResult(
        success: false,
        error: 'Cannot connect to server',
      );
    } catch (e) {
      print('🔴 Exception: $e');
      return AIGenerationResult(success: false, error: 'Connection failed: $e');
    }
  }

  @override
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('🔴 Health check failed: $e');
      return false;
    }
  }

  @override
  Future<QuotaInfo?> getQuota() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/quota'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return QuotaInfo(
          remaining: data['remaining'] as int,
          limit: data['limit'] as int,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Recipe _convertToRecipe(Map<String, dynamic> aiData) {
    print('🔵 Converting AI data to Recipe...');
    print('🔵 AI data keys: ${aiData.keys}');

    final ingredients = _parseIngredients(aiData['ingredients']);
    print('🔵 Converted ingredients: "${ingredients.length}"');

    final tools = _parseTools(aiData['tools']);

    // Map category
    final categoryKey = _mapCategory(aiData['category']);

    // Convert steps
    final steps = (aiData['steps'] as List).asMap().entries.map((entry) {
      final index = entry.key;
      final step = entry.value;

      final activityType = stepActivityTypeFromName(step['activityType']);
      return Step(
        instruction: step['instruction'] ?? '',
        heat: step['heat'],
        seasonings: step['seasoning'],
        timer: _toInt(step['time']),
        notes: step['notes'],
        whatToLookFor: step['whatToLookFor'] ?? '',
        index: index,
        activityType:
            activityType ??
            StepActivityResolver.infer(
              instruction: step['instruction']?.toString() ?? '',
              heat: step['heat']?.toString(),
              seasonings: step['seasoning']?.toString(),
              timer: _toInt(step['time']),
              notes: step['notes']?.toString(),
              whatToLookFor: step['whatToLookFor']?.toString(),
            ),
      );
    }).toList();

    final now = DateTime.now();
    return Recipe(
      cloudId: const Uuid().v4(),
      name: aiData['name'] ?? 'Untitled Recipe',
      url: _emptyToNull(aiData['url']?.toString()),
      imageUrl: _emptyToNull(
        (aiData['imageUrl'] ?? aiData['image_url'])?.toString(),
      ),
      ingredients: ingredients,
      tools: tools,
      categoryKey: categoryKey,
      createdDate: now,
      updatedAt: now,
      tags: _parseTags(aiData['tags']),
      steps: steps,
    );
  }

  List<String> _parseTags(dynamic value) {
    if (value is List) return RecipeTags.normalizeAll(value);
    if (value is String) return RecipeTags.normalizeAll(value.split(','));
    return const [];
  }

  bool _isSuccess(Map<String, dynamic> data) {
    return data['success'] == true || data['success'] == 'true';
  }

  List<Ingredient> _parseIngredients(dynamic value) {
    if (value is Map) {
      return _parseIngredients(value['item']);
    }
    if (value is List) {
      return value
          .map((item) {
            if (item is Map) {
              return Ingredient(
                name: item['name']?.toString() ?? '',
                quantity: _toDouble(item['quantity'] ?? item['amount']),
                unit: _parseUnit(item['unit']),
                note: _emptyToNull(item['note']?.toString()),
              );
            }
            return Ingredient(name: item.toString());
          })
          .where((ingredient) => ingredient.name.trim().isNotEmpty)
          .toList();
    }
    return _parseIngredientText(value?.toString() ?? '');
  }

  List<Tool> _parseTools(dynamic value) {
    if (value is List) {
      return value
          .map((item) {
            if (item is Map) {
              return Tool(
                name: item['name']?.toString() ?? '',
                quantity: _toInt(item['quantity']),
              );
            }
            return Tool(name: item.toString());
          })
          .where((tool) => tool.name.trim().isNotEmpty)
          .toList();
    }
    return _parseToolText(value?.toString() ?? '');
  }

  List<Ingredient> _parseIngredientText(String text) {
    return text
        .split(',')
        .map((raw) => raw.trim())
        .where((raw) => raw.isNotEmpty)
        .map((raw) => Ingredient(name: raw))
        .toList();
  }

  List<Tool> _parseToolText(String text) {
    return text
        .split(',')
        .map((raw) => raw.trim())
        .where((raw) => raw.isNotEmpty)
        .map((raw) => Tool(name: raw, quantity: 1))
        .toList();
  }

  MeasurementUnit? _parseUnit(dynamic value) {
    final unit = value?.toString().trim().toLowerCase();
    if (unit == null || unit.isEmpty || unit == 'null') return null;

    for (final candidate in MeasurementUnit.values) {
      if (candidate.name == unit) return candidate;
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String? _emptyToNull(String? value) {
    if (value == null || value.trim().isEmpty || value == 'null') return null;
    return value.trim();
  }

  String _mapCategory(String? aiCategory) {
    if (aiCategory == null || aiCategory.isEmpty) {
      return 'dinner';
    }

    final categoryMap = {
      'breakfast': 'breakfast',
      'lunch': 'lunch',
      'dinner': 'dinner',
      'lazy meals': 'lazy_meals',
      'dessert': 'dessert',
      'drinks': 'drinks',
    };

    final key = aiCategory.toLowerCase();
    return categoryMap[key] ?? 'dinner';
  }

  // String _mapCategory(String? aiCategory) {
  //   if (aiCategory == null || aiCategory.isEmpty) {
  //     return 'dinner';
  //   }

  //   final categoryMap = {
  //     'breakfast': 'breakfast',
  //     'lunch': 'lunch',
  //     'dinner': 'dinner',
  //     'lazy meals': 'lazy_meals',
  //     'dessert': 'dessert',
  //     'drinks': 'drinks',
  //   };

  //   final key = aiCategory.toLowerCase();
  //   return categoryMap[key] ?? 'dinner';
  // }
}
