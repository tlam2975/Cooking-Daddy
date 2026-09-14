import '../models/recipe.dart';
import '../models/category.dart';
import '../datasources/isar_datasource.dart';
import '../datasources/firestore_datasource.dart';
import 'auth_repository.dart';

class RecipeRepository {
  final IsarDatasource _datasource = IsarDatasource();
  final FirestoreDatasource _firestore = FirestoreDatasource();
  final AuthRepository _authRepository = AuthRepository();

  // ========== RECIPE METHODS ==========

  Future<List<Recipe>> getAllRecipes() async {
    return await _datasource.getAllRecipes();
  }

  Future<Recipe?> getRecipe(int id) async {
    return await IsarDatasource.isar.recipes.get(id);
  }

  Future<void> addRecipe(Recipe recipe) async {
    await _datasource.addRecipe(recipe);
    await _tryPushRecipe(recipe);
  }

  Future<void> updateRecipe(Recipe recipe) async {
    await _datasource.updateRecipe(recipe);
    await _tryPushRecipe(recipe);
  }

  Future<void> deleteRecipe(int id) async {
    final recipe = await getRecipe(id);
    await _datasource.deleteRecipe(id);
    if (recipe != null) {
      await _tryMarkRecipeDeleted(recipe);
    }
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

  Future<void> _tryPushRecipe(Recipe recipe) async {
    final user = _authRepository.currentUser;
    if (user == null) return;

    try {
      await _firestore.pushRecipe(user.uid, recipe);
    } catch (error) {
      print('Firestore recipe push failed: $error');
    }
  }

  Future<void> _tryMarkRecipeDeleted(Recipe recipe) async {
    final user = _authRepository.currentUser;
    if (user == null) return;

    try {
      await _firestore.markRecipeDeleted(user.uid, recipe);
    } catch (error) {
      print('Firestore recipe tombstone failed: $error');
    }
  }
}
