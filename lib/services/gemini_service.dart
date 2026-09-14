import 'dart:convert';
import '../data/models/recipe_tags.dart';
import 'package:http/http.dart' as http;
import '../data/models/recipe.dart';
import 'ai_interface.dart';
import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';

class GeminiService implements AIInterface {
  final String baseUrl = 'http://localhost:2975';

  @override
  Future<AIGenerationResult> generateFromIngredients({
    required String ingredients,
    String? tools,
    String? dish,
    String sessionLength = 'normal',
    String difficulty = 'normal',
    String location = 'Hanoi',
  }) async {
    try {
      print('🔵 ===== GEMINI SERVICE =====');
      print('🔵 Calling: $baseUrl/api/smart-generate');
      print('🔵 Ingredients: "$ingredients"');
      print('🔵 Tools: "$tools"');
      print('🔵 Dish: "$dish"');
      print('🔵 Session: $sessionLength');
      print('🔵 Difficulty: $difficulty');

      // Build request body
      final body = {
        'ingredients': ingredients,
        'sessionLength': sessionLength,
        'difficulty': difficulty,
        'location': location,
      };

      // Add optional fields only if provided
      if (tools != null && tools.isNotEmpty) {
        body['tools'] = tools;
      }
      if (dish != null && dish.isNotEmpty) {
        body['dish'] = dish;
      }

      print('🔵 Request body: ${jsonEncode(body)}');
      print('🔵 ==========================');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/smart-generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      print(response.statusCode);
      print(response.body);
      print('🔵 Response received from server: ${response}');
      print('🟢 Response status: ${response.statusCode}');
      print('🟢 Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (_isSuccess(data)) {
        print('Fetched data successfullly!');

        if (data['recipe'] != null) {
          final recipe = _convertToRecipe(data['recipe']);
          print('✅ Recipe converted: ${recipe.name}');

          return AIGenerationResult(
            success: true,
            recipe: recipe,
            remainingQuota: data['remaining_quota'],
          );
        } else {
          print('❌ Server returned success=false or no recipe');
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
        print(' Error status: ${response.statusCode}');
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
      print('🔴 EXCEPTION: $e');
      print('🔴 TYPE: ${e.runtimeType}');
      return AIGenerationResult(success: false, error: 'Error: $e');
    }
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

      return Step(
        instruction: step['instruction'] ?? '',
        heat: step['heat'],
        seasonings: step['seasoning'],
        timer: step['time'],
        notes: step['notes'],
        whatToLookFor: step['whatToLookFor'] ?? '',
        index: index,
      );
    }).toList();

    final now = DateTime.now();
    return Recipe(
      cloudId: const Uuid().v4(),
      name: aiData['name'] ?? 'Untitled Recipe',
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
