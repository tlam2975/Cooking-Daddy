import 'dart:async';

import 'package:flutter/services.dart';

import '../data/models/recipe.dart';
import 'app_log_service.dart';

class CookingLiveActivitySnapshot {
  final String recipeName;
  final int stepIndex;
  final int totalSteps;
  final String instruction;
  final StepActivityType activityType;
  final DateTime? timerEnd;
  final bool isCompleted;

  const CookingLiveActivitySnapshot({
    required this.recipeName,
    required this.stepIndex,
    required this.totalSteps,
    required this.instruction,
    required this.activityType,
    this.timerEnd,
    this.isCompleted = false,
  });

  Map<String, Object?> toMap() {
    final safeTotal = totalSteps < 1 ? 1 : totalSteps;
    final safeStep = stepIndex.clamp(0, safeTotal);
    return {
      'recipeName': recipeName,
      'stepIndex': safeStep,
      'totalSteps': safeTotal,
      'instruction': instruction,
      'activityType': activityType.name,
      'progress': isCompleted ? 1.0 : safeStep / safeTotal,
      'timerEndEpochMilliseconds': timerEnd?.millisecondsSinceEpoch,
      'isCompleted': isCompleted,
    };
  }
}

abstract class LiveActivityPlatform {
  Future<bool> isSupported();

  Future<void> start(Map<String, Object?> state);

  Future<void> update(Map<String, Object?> state);

  Future<void> end(Map<String, Object?> state);
}

class MethodChannelLiveActivityPlatform implements LiveActivityPlatform {
  static const _channel = MethodChannel('com.tlam.cookingdaddy/live_activity');

  @override
  Future<bool> isSupported() async {
    return await _channel.invokeMethod<bool>('isSupported') ?? false;
  }

  @override
  Future<void> start(Map<String, Object?> state) {
    return _channel.invokeMethod<void>('start', state);
  }

  @override
  Future<void> update(Map<String, Object?> state) {
    return _channel.invokeMethod<void>('update', state);
  }

  @override
  Future<void> end(Map<String, Object?> state) {
    return _channel.invokeMethod<void>('end', state);
  }
}

class CookingLiveActivityService {
  final LiveActivityPlatform _platform;
  Future<void> _operation = Future.value();
  bool _active = false;
  bool _endRequested = false;

  CookingLiveActivityService({LiveActivityPlatform? platform})
    : _platform = platform ?? MethodChannelLiveActivityPlatform();

  bool get isActive => _active;

  Future<void> start(CookingLiveActivitySnapshot snapshot) {
    _endRequested = false;
    return _enqueue(() async {
      try {
        if (_endRequested || !await _platform.isSupported()) return;
        await _platform.start(snapshot.toMap());
        _active = true;
        AppLogService.instance.info(
          'Cooking Live Activity started for ${snapshot.recipeName}',
        );
      } catch (error, stackTrace) {
        _active = false;
        AppLogService.instance.error(
          'Cooking Live Activity start failed: $error',
          stackTrace,
        );
      }
    });
  }

  Future<void> update(CookingLiveActivitySnapshot snapshot) {
    if (_endRequested) return Future.value();
    return _enqueue(() async {
      if (!_active || _endRequested) return;
      try {
        await _platform.update(snapshot.toMap());
      } catch (error, stackTrace) {
        AppLogService.instance.error(
          'Cooking Live Activity update failed: $error',
          stackTrace,
        );
      }
    });
  }

  Future<void> end(CookingLiveActivitySnapshot snapshot) {
    _endRequested = true;
    return _enqueue(() async {
      if (!_active) return;
      try {
        await _platform.end(snapshot.toMap());
        AppLogService.instance.info(
          'Cooking Live Activity ended for ${snapshot.recipeName}',
        );
      } catch (error, stackTrace) {
        AppLogService.instance.error(
          'Cooking Live Activity end failed: $error',
          stackTrace,
        );
      } finally {
        _active = false;
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    _operation = _operation.then(
      (_) => operation(),
      onError: (_) => operation(),
    );
    return _operation;
  }
}
