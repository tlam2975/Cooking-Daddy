import 'package:isar/isar.dart';

import '../data/datasources/firestore_datasource.dart';
import '../data/datasources/isar_datasource.dart';
import '../data/models/recipe.dart';
import 'app_log_service.dart';
import 'recipe_sync_status.dart';

class RecipeSyncService {
  final FirestoreDatasource _firestore = FirestoreDatasource();
  final RecipeSyncStatusController _syncStatus =
      RecipeSyncStatusController.instance;

  Future<void> sync(String uid) async {
    _syncStatus.markSyncing();
    AppLogService.instance.info('Recipe sync started');

    try {
      final repairedCount = await IsarDatasource.repairMissingRecipeCloudIds();
      if (repairedCount > 0) {
        AppLogService.instance.info(
          'Recipe sync repaired $repairedCount missing cloud IDs',
        );
      }
      final localRecipes = await IsarDatasource.isar.recipes.where().findAll();
      final localByCloudId = {
        for (final recipe in localRecipes) recipe.cloudId: recipe,
      };

      final remoteDocuments = await _firestore.fetchRecipes(uid);
      AppLogService.instance.info(
        'Recipe sync fetched ${remoteDocuments.length} cloud records for '
        '${localRecipes.length} local recipes',
      );
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
          remoteRecipe.photoSources = localRecipe.photoSources;
          await _putLocal(remoteRecipe);
        } else if (localRecipe.updatedAt.isAfter(remoteRecipe.updatedAt)) {
          await _firestore.pushRecipe(uid, localRecipe, includePhotos: false);
        }
      }

      for (final localRecipe in localRecipes) {
        if (!remoteCloudIds.contains(localRecipe.cloudId)) {
          await _firestore.pushRecipe(uid, localRecipe, includePhotos: false);
        }
      }

      _syncStatus.markSynced();
      AppLogService.instance.info('Recipe sync completed');
    } catch (error, stackTrace) {
      _syncStatus.markFailed(error, stackTrace);
      rethrow;
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
