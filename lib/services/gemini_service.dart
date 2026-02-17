import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/recipe.dart';
import 'ai_interface.dart';

class GeminiService implements AIInterface {
  //make sure its the damn right IP address alright?
  final String baseUrl = 'http://192.168.100.80:2975';

  @override
  Future<AIGenerationResult> generateFromIngredients({
    required String ingredients,
    String? tools,
    String? dish,
    String sessionLength = 'short',
    String difficulty = 'normal',
  }) async {
    try {
      final body = {
        'ingredients': ingredients,
        'sessionLength': sessionLength,
        'difficulty': difficulty,
      };

      if (tools != null && tools.isNotEmpty) body['tools'] = tools;
      if (dish != null && dish.isNotEmpty) body['dish'] = dish;

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/generate-from-ingredients'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final recipe = _convertToRecipe(data['recipe']);
          return AIGenerationResult(
            success: true,
            recipe: recipe,
            remainingQuota: data['remaining_quota'],
          );
        }
      } else if (response.statusCode == 429) {
        return AIGenerationResult(
          success: false,
          error: 'Daily quota exceeded',
        );
      }

      final data = jsonDecode(response.body);
      return AIGenerationResult(
        success: false,
        error: data['error'] ?? 'Generation failed',
      );
    } catch (e) {
      return AIGenerationResult(
        success: false,
        error: 'Connection failed. Is server running?',
      );
    }
  }

  @override
  Future<AIGenerationResult> generateFromUrl(String url) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/generate-from-url'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final recipe = _convertToRecipe(data['recipe']);
          return AIGenerationResult(
            success: true,
            recipe: recipe,
            remainingQuota: data['remaining_quota'],
          );
        }
      } else if (response.statusCode == 429) {
        return AIGenerationResult(
          success: false,
          error: 'Daily quota exceeded',
        );
      }

      final data = jsonDecode(response.body);
      return AIGenerationResult(
        success: false,
        error: data['error'] ?? 'Generation failed',
      );
    } catch (e) {
      return AIGenerationResult(
        success: false,
        error: 'Connection failed. Is server running?',
      );
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
    final aiSteps = aiData['steps'] as List;
    final steps = aiSteps.asMap().entries.map((entry) {
      final index = entry.key;
      final step = entry.value;
      final timeInSeconds = step['time'] as int? ?? 0;

      return Step(
        instruction: step['instruction'] ?? '',
        heat: step['heat'],
        index: index,
        seasonings: step['seasoning'],
        timer: timeInSeconds,
        notes: step['notes'],
        whatToLookFor: step['whatToLookFor'] ?? '',
      );
    }).toList();

    return Recipe(
      name: aiData['name'] ?? 'Untitled Recipe',
      url: null,
      category: aiData['category'] ?? 'Dinner',
      ingredients: aiData['ingredients'] ?? '',
      tools: aiData['tools'] ?? '',
      createdDate: DateTime.now(),
      steps: steps,
    );
  }
}
