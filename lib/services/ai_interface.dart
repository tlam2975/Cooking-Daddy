import '../data/models/recipe.dart';

/// Abstract interface for AI recipe generation
abstract class AIInterface {
  Future<AIGenerationResult> generateFromIngredients({
    required String ingredients,
    String? tools,
    String? dish,
    String sessionLength = 'normal',
    String difficulty = 'normal',
  });

  Future<AIGenerationResult> generateFromUrl(String url);
  Future<AIGenerationResult> remixRecipe({
    required Recipe source,
    required String instructions,
    required String languageCode,
  });
  Future<bool> checkHealth();
  Future<QuotaInfo?> getQuota();
}

class AIGenerationResult {
  final bool success;
  final Recipe? recipe;
  final String? error;
  final int? remainingQuota;

  AIGenerationResult({
    required this.success,
    this.recipe,
    this.error,
    this.remainingQuota,
  });
}

class QuotaInfo {
  final int remaining;
  final int limit;

  QuotaInfo({required this.remaining, required this.limit});
}
