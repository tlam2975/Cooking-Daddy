import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/recipe.dart';
import 'ai_interface.dart';
import 'dart:async';
import 'dart:io';

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

      if (response.body.contains('"success": true')) {
        final data = jsonDecode(response.body);
        print('Fetched data successfullly!');

        if (response.body.contains('"success": true') &&
            data['recipe'] != null) {
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

        if (data['success'] == true && data['recipe'] != null) {
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

    // Handle ingredients (could be String, List, or Object)
    String ingredients;
    if (aiData['ingredients'] is Map) {
      // Handle {"item": "beef, chicken..."}
      final ingredientsMap = aiData['ingredients'] as Map;
      ingredients = ingredientsMap['item'] ?? '';
    } else if (aiData['ingredients'] is List) {
      ingredients = (aiData['ingredients'] as List).join(', ');
    } else {
      ingredients = aiData['ingredients'] as String? ?? '';
    }

    print('🔵 Converted ingredients: "$ingredients"');

    // Convert tools
    String tools;
    if (aiData['tools'] is List) {
      tools = (aiData['tools'] as List).join(', ');
    } else {
      tools = aiData['tools'] as String? ?? '';
    }

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

    return Recipe(
      name: aiData['name'] ?? 'Untitled Recipe',
      ingredients: ingredients,
      tools: tools,
      categoryKey: categoryKey,
      createdDate: DateTime.now(),
      steps: steps,
    );
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
