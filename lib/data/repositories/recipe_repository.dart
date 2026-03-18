import '../models/recipe.dart';
import '../models/category.dart';
import '../datasources/isar_datasource.dart';

class RecipeRepository {
  final IsarDatasource _datasource = IsarDatasource();

  // ========== RECIPE METHODS ==========

  Future<List<Recipe>> getAllRecipes() async {
    return await _datasource.getAllRecipes();
  }

  Future<Recipe?> getRecipe(int id) async {
    return await IsarDatasource.isar.recipes.get(id);
  }

  Future<void> addRecipe(Recipe recipe) async {
    await _datasource.addRecipe(recipe);
  }

  Future<void> updateRecipe(Recipe recipe) async {
    await _datasource.updateRecipe(recipe);
  }

  Future<void> deleteRecipe(int id) async {
    await _datasource.deleteRecipe(id);
  }

  Future<List<Recipe>> getRecipesByCategory(String categoryKey) async {
    return await _datasource.getRecipesByCategory(categoryKey);
  }

  Future<List<Recipe>> searchRecipesByName(String query) async {
    return await _datasource.searchRecipesByName(query);
  }

  // ========== CATEGORY METHODS ==========

  Future<List<Category>> getAllCategories() async {
    return await _datasource.getAllCategories();
  }

  Future<List<Category>> getBuiltInCategories() async {
    return await _datasource.getBuiltInCategories();
  }

  Future<List<Category>> getCustomCategories() async {
    return await _datasource.getCustomCategories();
  }

  Future<Category?> getCategoryByKey(String key) async {
    return await _datasource.getCategoryByKey(key);
  }

  Future<void> addCustomCategory(String key) async {
    await _datasource.addCustomCategory(key);
  }

  Future<void> deleteCustomCategory(String key) async {
    await _datasource.deleteCustomCategory(key);
  }
}
