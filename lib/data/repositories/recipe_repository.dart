import '../models/recipe.dart';
import '../models/category.dart';
import '../datasources/isar_datasource.dart';

class RecipeRepository {
  final IsarDatasource _datasource = IsarDatasource();

  Future<List<Recipe>> getAllRecipes() async {
    return await _datasource.getAllRecipes();
  }

  // Get single recipe by ID
  Future<Recipe?> getRecipe(int id) async {
    return await IsarDatasource.isar.recipes.get(id);
  }

  Future<void> addRecipe(Recipe recipe) async {
    await _datasource.addRecipe(recipe);
  }

  Future<List<Recipe>> searchRecipesByName(String query) async {
    return await _datasource.searchRecipesByName(query);
  }

  Future<void> updateRecipe(Recipe recipe) async {
    await _datasource.updateRecipe(recipe);
  }

  Future<void> deleteRecipe(int id) async {
    await _datasource.deleteRecipe(id);
  }

  Future<void> addCategory(Category category) async {
    await _datasource.addCategory(category);
  }

  Future<List<Recipe>> getRecipesByCategory(String categoryName) async {
    return await _datasource.getRecipesByCategory(categoryName);
  }

  Future<List<String>> getCategoryNames() async {
    return await _datasource.getCategoryNames();
  }

  // Future<String> getCategoryName(int categoryId) async {
  //   return await IsarDatasource().getCategoryNameById(categoryId);
  // }
}
