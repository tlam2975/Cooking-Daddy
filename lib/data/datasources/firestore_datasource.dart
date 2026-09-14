import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/recipe.dart';

class FirestoreRecipeDocument {
  final String cloudId;
  final Recipe? recipe;
  final DateTime? deletedAt;

  const FirestoreRecipeDocument({
    required this.cloudId,
    this.recipe,
    this.deletedAt,
  });
}

class FirestoreDatasource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _recipesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('recipes');
  }

  Future<List<FirestoreRecipeDocument>> fetchRecipes(String uid) async {
    final snapshot = await _recipesRef(uid).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final deletedAt = _dateTimeFrom(data['deletedAt']);
      final cloudId = data['cloudId'] as String? ?? doc.id;

      if (deletedAt != null) {
        return FirestoreRecipeDocument(cloudId: cloudId, deletedAt: deletedAt);
      }

      return FirestoreRecipeDocument(
        cloudId: cloudId,
        recipe: _recipeFromMap({...data, 'cloudId': cloudId}),
      );
    }).toList();
  }

  Future<void> pushRecipe(String uid, Recipe recipe) async {
    await _recipesRef(uid).doc(recipe.cloudId).set(_recipeToMap(recipe));
  }

  Future<void> markRecipeDeleted(String uid, Recipe recipe) async {
    final now = DateTime.now();
    await _recipesRef(uid).doc(recipe.cloudId).set({
      'cloudId': recipe.cloudId,
      'name': recipe.name,
      'updatedAt': Timestamp.fromDate(now),
      'deletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Map<String, dynamic> _recipeToMap(Recipe recipe) {
    return {
      'cloudId': recipe.cloudId,
      'name': recipe.name,
      'url': recipe.url,
      'imageUrl': recipe.imageUrl,
      'ingredients': recipe.ingredients.map(_ingredientToMap).toList(),
      'tools': recipe.tools.map(_toolToMap).toList(),
      'steps': recipe.steps.map(_stepToMap).toList(),
      'categoryKey': recipe.categoryKey,
      'tags': recipe.tags,
      'createdDate': Timestamp.fromDate(recipe.createdDate),
      'updatedAt': Timestamp.fromDate(recipe.updatedAt),
      'basePortions': recipe.basePortions,
      'isFavorite': recipe.isFavorite,
      'isSeed': recipe.isSeed,
      'sourceRecipeId': recipe.sourceRecipeId,
      'energyNote': recipe.energyNote,
      'deletedAt': null,
    };
  }

  Recipe _recipeFromMap(Map<String, dynamic> data) {
    return Recipe(
      cloudId: data['cloudId'] as String,
      name: data['name'] as String? ?? 'Untitled Recipe',
      url: data['url'] as String?,
      imageUrl: data['imageUrl'] as String?,
      ingredients: _listFrom(
        data['ingredients'],
      ).map(_ingredientFromMap).toList(),
      tools: _listFrom(data['tools']).map(_toolFromMap).toList(),
      steps: _listFrom(data['steps']).map(_stepFromMap).toList(),
      categoryKey: data['categoryKey'] as String? ?? 'dinner',
      tags: _listFrom(data['tags']).map((tag) => tag.toString()).toList(),
      createdDate: _dateTimeFrom(data['createdDate']) ?? DateTime.now(),
      updatedAt: _dateTimeFrom(data['updatedAt']) ?? DateTime.now(),
      basePortions: (data['basePortions'] as num?)?.toInt() ?? 1,
      isFavorite: data['isFavorite'] as bool? ?? false,
      isSeed: data['isSeed'] as bool? ?? false,
      sourceRecipeId: data['sourceRecipeId'] as String?,
      energyNote: data['energyNote'] as String?,
    );
  }

  Map<String, dynamic> _ingredientToMap(Ingredient ingredient) {
    return {
      'name': ingredient.name,
      'quantity': ingredient.quantity,
      'unit': ingredient.unit?.name,
      'note': ingredient.note,
    };
  }

  Ingredient _ingredientFromMap(dynamic raw) {
    final data = Map<String, dynamic>.from(raw as Map);
    return Ingredient(
      name: data['name'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toDouble(),
      unit: _unitFrom(data['unit']),
      note: data['note'] as String?,
    );
  }

  Map<String, dynamic> _toolToMap(Tool tool) {
    return {'name': tool.name, 'quantity': tool.quantity};
  }

  Tool _toolFromMap(dynamic raw) {
    final data = Map<String, dynamic>.from(raw as Map);
    return Tool(
      name: data['name'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> _stepToMap(Step step) {
    return {
      'instruction': step.instruction,
      'heat': step.heat,
      'index': step.index,
      'seasonings': step.seasonings,
      'timer': step.timer,
      'notes': step.notes,
      'whatToLookFor': step.whatToLookFor,
    };
  }

  Step _stepFromMap(dynamic raw) {
    final data = Map<String, dynamic>.from(raw as Map);
    return Step(
      instruction: data['instruction'] as String? ?? '',
      heat: data['heat'] as String?,
      index: (data['index'] as num?)?.toInt() ?? 0,
      seasonings: data['seasonings'] as String?,
      timer: (data['timer'] as num?)?.toInt(),
      notes: data['notes'] as String?,
      whatToLookFor: data['whatToLookFor'] as String? ?? '',
    );
  }

  List<dynamic> _listFrom(dynamic value) {
    return value is List ? value : const [];
  }

  MeasurementUnit? _unitFrom(dynamic value) {
    final unit = value?.toString();
    if (unit == null) return null;
    for (final candidate in MeasurementUnit.values) {
      if (candidate.name == unit) return candidate;
    }
    return null;
  }

  DateTime? _dateTimeFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
