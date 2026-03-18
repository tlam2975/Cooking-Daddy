import 'package:isar/isar.dart';
import '../data/models/recipe.dart';
import '../data/models/list_categories.dart';

Future<void> migrateCategoryKeys(Isar isar) async {
  print('🔄 Starting category migration...');

  final recipes = await isar.recipes.where().findAll();

  if (recipes.isEmpty) {
    print('✅ No recipes to migrate');
    return;
  }

  await isar.writeTxn(() async {
    for (var recipe in recipes) {
      // Get old category value
      final oldCategory =
          recipe.categoryKey; // Still has old value like "Breakfast"

      // Convert to new key
      final newKey = CategoryData.migrateOldCategory(oldCategory);

      print('Migrating: "${recipe.name}" → "$oldCategory" → "$newKey"');

      // Update
      recipe.categoryKey = newKey;
      await isar.recipes.put(recipe);
    }
  });

  print('✅ Migration complete!');
}
