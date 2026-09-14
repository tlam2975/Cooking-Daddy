import 'package:isar/isar.dart';

import '../data/datasources/firestore_datasource.dart';
import '../data/datasources/isar_datasource.dart';
import '../data/models/recipe.dart';

class RecipeSyncService {
  final FirestoreDatasource _firestore = FirestoreDatasource();

  Future<void> sync(String uid) async {
    final localRecipes = await IsarDatasource.isar.recipes.where().findAll();
    final localByCloudId = {
      for (final recipe in localRecipes) recipe.cloudId: recipe,
    };

    final remoteDocuments = await _firestore.fetchRecipes(uid);
    final remoteCloudIds = <String>{};

    for (final document in remoteDocuments) {
      final remoteRecipe = document.recipe;

      if (remoteRecipe == null) {
        final tombstoneWins = await _applyRemoteTombstone(
          document,
          localByCloudId,
        );
        if (tombstoneWins) {
          remoteCloudIds.add(document.cloudId);
        }
        continue;
      }

      remoteCloudIds.add(remoteRecipe.cloudId);
      final localRecipe = localByCloudId[remoteRecipe.cloudId];

      if (localRecipe == null) {
        await _putLocal(remoteRecipe);
      } else if (remoteRecipe.updatedAt.isAfter(localRecipe.updatedAt)) {
        remoteRecipe.id = localRecipe.id;
        await _putLocal(remoteRecipe);
      } else if (localRecipe.updatedAt.isAfter(remoteRecipe.updatedAt)) {
        await _firestore.pushRecipe(uid, localRecipe);
      }
    }

    for (final localRecipe in localRecipes) {
      if (!remoteCloudIds.contains(localRecipe.cloudId)) {
        await _firestore.pushRecipe(uid, localRecipe);
      }
    }
  }

  Future<bool> _applyRemoteTombstone(
    FirestoreRecipeDocument document,
    Map<String, Recipe> localByCloudId,
  ) async {
    final deletedAt = document.deletedAt;
    if (deletedAt == null) return false;

    final localRecipe = localByCloudId[document.cloudId];
    if (localRecipe == null) return true;

    if (!deletedAt.isBefore(localRecipe.updatedAt)) {
      await IsarDatasource.isar.writeTxn(() async {
        await IsarDatasource.isar.recipes.delete(localRecipe.id);
      });
      return true;
    }

    return false;
  }

  Future<void> _putLocal(Recipe recipe) async {
    await IsarDatasource.isar.writeTxn(() async {
      await IsarDatasource.isar.recipes.put(recipe);
    });
  }
}
