import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app_log_service.dart';

enum RecipeSyncState { idle, savedLocally, syncing, synced, failed }

class RecipeSyncStatusController extends ChangeNotifier {
  RecipeSyncStatusController._();

  static final RecipeSyncStatusController instance =
      RecipeSyncStatusController._();

  RecipeSyncState _state = RecipeSyncState.idle;
  DateTime? _lastLocalSaveAt;
  DateTime? _lastSyncedAt;
  Object? _lastError;

  RecipeSyncState get state => _state;
  DateTime? get lastLocalSaveAt => _lastLocalSaveAt;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  Object? get lastError => _lastError;
  String? get errorDescription => _describeError(_lastError);

  void markSavedLocally() {
    _state = RecipeSyncState.savedLocally;
    _lastLocalSaveAt = DateTime.now();
    _lastError = null;
    notifyListeners();
  }

  void markSyncing() {
    _state = RecipeSyncState.syncing;
    notifyListeners();
  }

  void markSynced() {
    _state = RecipeSyncState.synced;
    _lastSyncedAt = DateTime.now();
    _lastError = null;
    notifyListeners();
  }

  void markFailed(Object error, [StackTrace? stackTrace]) {
    _state = RecipeSyncState.failed;
    _lastError = error;
    final description = _describeError(error) ?? error.toString();
    AppLogService.instance.error(
      'Recipe sync failed: $description',
      stackTrace,
    );
    developer.log(
      description,
      name: 'RecipeSync',
      error: error,
      stackTrace: stackTrace,
    );
    notifyListeners();
  }

  String? _describeError(Object? error) {
    if (error == null) return null;
    if (error is FirebaseException) {
      final message = error.message?.trim();
      final details = message == null || message.isEmpty ? '' : ': $message';
      return '${error.plugin}/${error.code}$details';
    }
    return error.toString();
  }
}
