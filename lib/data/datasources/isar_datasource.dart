import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/recipe.dart';
import '../models/category.dart';
import '../models/list_categories.dart';
import 'package:uuid/uuid.dart';

class IsarDatasource {
  static late Isar isar;

  static Future<void> migrateCategoryKeys() async {
    print('🔄 Fixing empty category keys...');

    final recipes = await isar.recipes.where().findAll();

    if (recipes.isEmpty) {
      print('✅ No recipes to migrate');
      return;
    }

    await isar.writeTxn(() async {
      for (var recipe in recipes) {
        // If categoryKey is empty, assign default
        if (recipe.categoryKey.isEmpty) {
          // Assign default category based on recipe name
          String defaultKey = 'dinner'; // Default fallback

          if (recipe.name.toLowerCase().contains('egg')) {
            defaultKey = 'breakfast';
          } else if (recipe.name.toLowerCase().contains('coffee')) {
            defaultKey = 'drinks';
          } else if (recipe.name.toLowerCase().contains('cookie')) {
            defaultKey = 'dessert';
          }

          print('Fixing: "${recipe.name}" → empty → "$defaultKey"');
          recipe.categoryKey = defaultKey;
          await isar.recipes.put(recipe);
        }
      }
    });

    print('✅ Migration complete!');
  }

  static Future<void> initialize() async {
    print('IsarDatasource: Starting initialization...');
    final dir = await getApplicationDocumentsDirectory();
    print('IsarDatasource: Got directory: ${dir.path}');

    // Add CategorySchema
    isar = await Isar.open([RecipeSchema, CategorySchema], directory: dir.path);
    print('IsarDatasource: Isar opened successfully!');

    await repairMissingRecipeCloudIds();
    await repairRecipePhotoPaths(dir.path);
    await _seedBuiltInCategories();
    await _addDefaultDataIfEmpty();
    print('IsarDatasource: Initialization complete!');
  }

  static Future<int> repairMissingRecipeCloudIds() async {
    final recipes = await isar.recipes.where().findAll();
    final missingIds = recipes
        .where((recipe) => recipe.cloudId.trim().isEmpty)
        .toList();
    if (missingIds.isEmpty) return 0;

    const uuid = Uuid();
    await isar.writeTxn(() async {
      for (final recipe in missingIds) {
        recipe.cloudId = uuid.v4();
        await isar.recipes.put(recipe);
      }
    });

    print(
      'IsarDatasource: Assigned cloud IDs to ${missingIds.length} '
      'legacy recipes',
    );
    return missingIds.length;
  }

  static Future<int> repairRecipePhotoPaths(String documentsPath) async {
    final recipes = await isar.recipes.where().findAll();
    final changedRecipes = <Recipe>[];

    for (final recipe in recipes) {
      var changed = false;
      final repairedSources = recipe.photoSources.map((source) {
        final repaired = _rebasedPhotoPath(source, documentsPath);
        if (repaired != source) changed = true;
        return repaired;
      }).toList();

      if (changed) {
        recipe.photoSources = repairedSources;
        changedRecipes.add(recipe);
      }
    }

    if (changedRecipes.isEmpty) return 0;
    await isar.writeTxn(() async {
      await isar.recipes.putAll(changedRecipes);
    });
    print(
      'IsarDatasource: Repaired photo paths for '
      '${changedRecipes.length} recipes',
    );
    return changedRecipes.length;
  }

  static String _rebasedPhotoPath(String source, String documentsPath) {
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return source;
    }

    final localPath = uri?.scheme == 'file' ? uri!.toFilePath() : source;
    if (File(localPath).existsSync()) return localPath;

    const marker = '/Documents/';
    final markerIndex = localPath.indexOf(marker);
    if (markerIndex < 0) return source;

    final relativePath = localPath.substring(markerIndex + marker.length);
    final candidate = '$documentsPath/$relativePath';
    return File(candidate).existsSync() ? candidate : source;
  }

  // Seed built-in categories on first launch
  static Future<void> _seedBuiltInCategories() async {
    final count = await isar.categorys.count();

    if (count == 0) {
      print('🌱 Seeding built-in categories...');

      await isar.writeTxn(() async {
        for (var key in CategoryData.categoryKeys) {
          final category = Category(
            key: key,
            isBuiltIn: true,
            createdDate: DateTime.now(),
          );
          await isar.categorys.put(category);
        }
      });

      print('✅ Built-in categories seeded');
    }
  }

  static Future<void> _addDefaultDataIfEmpty() async {
    final recipeCount = await isar.recipes.count();
    if (recipeCount == 0) {
      await addDefaultRecipes();
    }
  }

  static Future<void> addDefaultRecipes() async {
    const uuid = Uuid();
    final now = DateTime.now();

    await isar.writeTxn(() async {
      final scrambledEggs = Recipe(
        cloudId: uuid.v4(),
        name: 'Scrambled Eggs',
        ingredients: [
          Ingredient(name: 'eggs', quantity: 2, unit: MeasurementUnit.pcs),
          Ingredient(name: 'salt'),
          Ingredient(name: 'pepper'),
          Ingredient(name: 'butter'),
        ],
        tools: [
          Tool(name: 'Pan', quantity: 1),
          Tool(name: 'Spatula', quantity: 1),
          Tool(name: 'Bowl', quantity: 1),
        ],
        categoryKey: 'breakfast',
        tags: const ['quick', 'breakfast', 'budget'],
        createdDate: now,
        updatedAt: now,
        isSeed: true,
        steps: [
          Step(
            instruction: 'Crack eggs into bowl and whisk',
            whatToLookFor: 'Eggs are well mixed',
            index: 0,
            activityType: StepActivityType.mix,
          ),
          Step(
            instruction: 'Heat pan with butter on medium heat',
            whatToLookFor: 'Butter is melted but not brown',
            heat: 'Medium',
            index: 1,
            timer: 60,
            activityType: StepActivityType.heat,
          ),
          Step(
            instruction: 'Pour eggs and gently stir',
            whatToLookFor: 'Eggs are soft and fluffy',
            heat: 'Medium',
            index: 2,
            timer: 120,
            activityType: StepActivityType.mix,
          ),
        ],
      );
      await isar.recipes.put(scrambledEggs);

      final pasta = Recipe(
        cloudId: uuid.v4(),
        name: 'Simple Pasta',
        ingredients: [
          Ingredient(name: 'pasta', quantity: 200, unit: MeasurementUnit.g),
          Ingredient(name: 'salt'),
          Ingredient(name: 'olive oil'),
          Ingredient(name: 'garlic'),
        ],
        tools: [
          Tool(name: 'Pot', quantity: 1),
          Tool(name: 'Colander', quantity: 1),
          Tool(name: 'Pan', quantity: 1),
        ],
        categoryKey: 'dinner',
        tags: const ['quick', 'budget', 'dinner'],
        createdDate: now,
        updatedAt: now,
        isSeed: true,
        steps: [
          Step(
            instruction: 'Boil water with salt',
            whatToLookFor: 'Water is rapidly boiling',
            heat: 'High',
            index: 0,
            activityType: StepActivityType.heat,
          ),
          Step(
            instruction: 'Add pasta and cook',
            whatToLookFor: 'Pasta is al dente',
            heat: 'High',
            index: 1,
            timer: 480,
            activityType: StepActivityType.heat,
          ),
          Step(
            instruction: 'Drain and toss with olive oil',
            whatToLookFor: 'Pasta is coated evenly',
            index: 2,
            activityType: StepActivityType.mix,
          ),
        ],
      );
      await isar.recipes.put(pasta);

      final softboiledEgg = Recipe(
        cloudId: uuid.v4(),
        name: 'Soft Boiled Egg',
        ingredients: [
          Ingredient(name: 'egg', quantity: 1, unit: MeasurementUnit.pcs),
          Ingredient(name: 'water'),
          Ingredient(name: 'salt'),
        ],
        tools: [
          Tool(name: 'Pot', quantity: 1),
          Tool(name: 'Spoon', quantity: 1),
        ],
        categoryKey: 'lazy_meals',
        tags: const ['quick', 'light', 'breakfast'],
        createdDate: now,
        updatedAt: now,
        isSeed: true,
        steps: [
          Step(
            instruction: 'Boil the water',
            heat: 'High',
            whatToLookFor: 'Boiled water',
            activityType: StepActivityType.heat,
          ),
          Step(
            instruction: 'Gently drop the eggs in',
            heat: 'Medium low',
            notes: "Don't break it",
            whatToLookFor: 'Boiled eggs',
            timer: 360,
            activityType: StepActivityType.heat,
          ),
          Step(
            instruction: 'Take the eggs out and put in cold water',
            heat: 'Cool',
            whatToLookFor: 'Chilled eggs',
            notes:
                'This step is to stop the eggs from continuingly being cooked by the remaining heat',
            timer: 120,
            activityType: StepActivityType.wait,
          ),
        ],
      );
      await isar.recipes.put(softboiledEgg);
    });
  }

  // ========== CATEGORY CRUD ==========

  Future<List<Category>> getAllCategories() async {
    return await isar.categorys.where().sortByCreatedDate().findAll();
  }

  Future<List<Category>> getBuiltInCategories() async {
    return await isar.categorys.filter().isBuiltInEqualTo(true).findAll();
  }

  Future<List<Category>> getCustomCategories() async {
    return await isar.categorys.filter().isBuiltInEqualTo(false).findAll();
  }

  Future<Category?> getCategoryByKey(String key) async {
    return await isar.categorys.filter().keyEqualTo(key).findFirst();
  }

  Future<void> addCustomCategory(String key) async {
    await isar.writeTxn(() async {
      final category = Category(
        key: key,
        isBuiltIn: false,
        createdDate: DateTime.now(),
      );
      await isar.categorys.put(category);
    });
  }

  Future<void> deleteCustomCategory(String key) async {
    final category = await getCategoryByKey(key);
    if (category != null && !category.isBuiltIn) {
      await isar.writeTxn(() async {
        await isar.categorys.delete(category.id);
      });
    }
  }

  // ========== RECIPE CRUD ==========

  Future<List<Recipe>> getAllRecipes() async {
    return await isar.recipes.where().findAll();
  }

  Stream<List<Recipe>> watchAllRecipes() {
    return isar.recipes.where().watch(fireImmediately: true);
  }

  Future<void> addRecipe(Recipe recipe) async {
    await isar.writeTxn(() async {
      await isar.recipes.put(recipe);
    });
  }

  Future<void> updateRecipe(Recipe recipe) async {
    await isar.writeTxn(() async {
      await isar.recipes.put(recipe);
    });
  }

  Future<void> deleteRecipe(int id) async {
    await isar.writeTxn(() async {
      await isar.recipes.delete(id);
    });
  }

  Future<List<Recipe>> getRecipesByCategory(String categoryKey) async {
    return await isar.recipes
        .filter()
        .categoryKeyEqualTo(categoryKey)
        .findAll();
  }

  Future<List<Recipe>> searchRecipesByName(String query) async {
    return await isar.recipes
        .filter()
        .nameContains(query, caseSensitive: false)
        .findAll();
  }
}
