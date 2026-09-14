import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models/recipe.dart';

class EnergyNoteService {
  final String baseUrl;

  const EnergyNoteService({this.baseUrl = 'http://localhost:2975'});

  Future<String> generate(Recipe recipe) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/energy-note'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(_recipeToJson(recipe)),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final note = data['energyNote'] as String?;
        if (note != null && note.trim().isNotEmpty) return note.trim();
      }
    } catch (_) {
      // Keep detail screen useful if the local Flask server is not running.
    }

    return _fallbackNote(recipe);
  }

  Map<String, dynamic> _recipeToJson(Recipe recipe) {
    return {
      'name': recipe.name,
      'category': recipe.categoryKey,
      'tags': recipe.tags,
      'ingredients': recipe.ingredients
          .map(
            (ingredient) => {
              'name': ingredient.name,
              'quantity': ingredient.quantity,
              'unit': ingredient.unit?.name,
              'note': ingredient.note,
            },
          )
          .toList(),
    };
  }

  String _fallbackNote(Recipe recipe) {
    final tags = recipe.tags.join(', ');
    final ingredientCount = recipe.ingredients.length;
    final tagText = tags.isEmpty ? '' : ' Tags: $tags.';
    return 'A quick energy read: this recipe uses $ingredientCount ingredients, so portion size and cooking fat will matter most. Add vegetables or a lighter side if you want it to feel easier after eating.$tagText';
  }
}
