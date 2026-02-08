import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/category.dart';
import '../models/recipe.dart';

class IsarDatasource {
  static late Isar isar;

  static Future<void> initialize() async {
    print('IsarDatasource: Starting initialization...');
    final dir = await getApplicationDocumentsDirectory();
    print('IsarDatasource: Got directory: ${dir.path}');

    isar = await Isar.open([CategorySchema, RecipeSchema], directory: dir.path);
    print('IsarDatasource: Isar opened successfully!');

    await _addDefaultDataIfEmpty();
    print('IsarDatasource: Initialization complete!');
  }

  static Future<void> _addDefaultDataIfEmpty() async {
    final recipeCount = await isar.recipes.count();
    if (recipeCount == 0) {
      await addDefaultRecipes();
    }
  }

  static Future<void> addDefaultRecipes() async {
    await isar.writeTxn(() async {
      final scrambledEggs = Recipe(
        name: 'Scrambled Eggs',
        ingredients: '2 eggs, Salt, Pepper, Butter',
        tools: 'Pan, Spatula, Bowl',
        category: 'Breakfast', // Changed from categoryId to category
        createdDate: DateTime.now(),
        steps: [
          Step(
            instruction: 'Crack eggs into bowl and whisk',
            whatToLookFor: 'Eggs are well mixed',
            index: 0,
          ),
          Step(
            instruction: 'Heat pan with butter on medium heat',
            whatToLookFor: 'Butter is melted but not brown',
            heat: 'Medium',
            index: 1,
            timer: 60,
          ),
          Step(
            instruction: 'Pour eggs and gently stir',
            whatToLookFor: 'Eggs are soft and fluffy',
            heat: 'Medium',
            index: 2,
            timer: 120,
          ),
        ],
      );
      await isar.recipes.put(scrambledEggs);

      final pasta = Recipe(
        name: 'Simple Pasta',
        ingredients: '200g pasta, Salt, Olive oil, Garlic',
        tools: 'Pot, Colander, Pan',
        category: 'Dinner', // Changed from categoryId to category
        createdDate: DateTime.now(),
        steps: [
          Step(
            instruction: 'Boil water with salt',
            whatToLookFor: 'Water is rapidly boiling',
            heat: 'High',
            index: 0,
          ),
          Step(
            instruction: 'Add pasta and cook',
            whatToLookFor: 'Pasta is al dente',
            heat: 'High',
            index: 1,
            timer: 480,
          ),
          Step(
            instruction: 'Drain and toss with olive oil',
            whatToLookFor: 'Pasta is coated evenly',
            index: 2,
          ),
        ],
      );
      await isar.recipes.put(pasta);

      final softboiledEgg = Recipe(
        name: 'Soft Boiled Egg',
        ingredients: 'Egg, Water, Salt',
        tools: 'Pot, Spoon',
        category: 'Lazy meals',
        createdDate: DateTime.now(),
        steps: [
          Step(
            instruction: 'Boil the water',
            heat: 'High',
            whatToLookFor: 'Boiled water',
          ),
          Step(
            instruction: 'Gently drop the eggs in',
            heat: 'Medium low',
            notes: "Don't break it",
            whatToLookFor: 'Boiled eggs',
            timer: 360,
          ),
          Step(
            instruction: 'Take the eggs out and put in cold water',
            heat: 'Cool',
            whatToLookFor: 'Chilled eggs',
            notes:
                'This step is to stop the eggs from continuingly being cooked by the remaining heat',
            timer: 120,
          ),
        ],
      );
      await isar.recipes.put(softboiledEgg);
    });
  }

  Future<List<Recipe>> getAllRecipes() async {
    return await isar.recipes.where().findAll();
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

  Future<void> addCategory(Category category) async {
    await isar.writeTxn(() async {
      await isar.categorys.put(category);
    });
  }

  Future<List<Recipe>> getRecipesByCategory(String categoryName) async {
    return await isar.recipes.filter().categoryEqualTo(categoryName).findAll();
  }

  Future<List<Recipe>> searchRecipesByName(String query) async {
    return await isar.recipes
        .filter()
        .nameContains(query, caseSensitive: false)
        .findAll();
  }

  Future<List<String>> getCategoryNames() async {
    final categories = await isar.categorys.where().findAll();
    return categories.map((c) => c.name).toList();
  }

  Future<String> getCategoryNameById(int categoryId) async {
    final category = await isar.categorys.get(categoryId);
    return category?.name ?? 'Unknown';
  }
}
