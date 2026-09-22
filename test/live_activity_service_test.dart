import 'dart:async';

import 'package:cooking_daddy/data/models/recipe.dart';
import 'package:cooking_daddy/services/live_activity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const firstStep = CookingLiveActivitySnapshot(
    recipeName: 'Mashed potatoes',
    stepIndex: 1,
    totalSteps: 5,
    instruction: 'Mash until smooth',
    activityType: StepActivityType.mix,
  );

  test('starts, updates, and ends with stable payloads', () async {
    final platform = _FakeLiveActivityPlatform();
    final service = CookingLiveActivityService(platform: platform);

    await service.start(firstStep);
    final timerEnd = DateTime(2026, 9, 22, 9, 45);
    await service.update(
      CookingLiveActivitySnapshot(
        recipeName: 'Mashed potatoes',
        stepIndex: 2,
        totalSteps: 5,
        instruction: 'Warm over low heat',
        activityType: StepActivityType.timer,
        timerEnd: timerEnd,
      ),
    );
    await service.end(
      const CookingLiveActivitySnapshot(
        recipeName: 'Mashed potatoes',
        stepIndex: 5,
        totalSteps: 5,
        instruction: 'Done',
        activityType: StepActivityType.complete,
        isCompleted: true,
      ),
    );

    expect(service.isActive, isFalse);
    expect(platform.calls, ['start', 'update', 'end']);
    expect(platform.states[0]['activityType'], 'mix');
    expect(platform.states[0]['progress'], 0.2);
    expect(
      platform.states[1]['timerEndEpochMilliseconds'],
      timerEnd.millisecondsSinceEpoch,
    );
    expect(platform.states[2]['progress'], 1.0);
    expect(platform.states[2]['isCompleted'], isTrue);
  });

  test('does nothing when Live Activities are disabled', () async {
    final platform = _FakeLiveActivityPlatform(supported: false);
    final service = CookingLiveActivityService(platform: platform);

    await service.start(firstStep);
    await service.update(firstStep);
    await service.end(firstStep);

    expect(platform.calls, isEmpty);
  });

  test(
    'an exit requested during start cannot leave an activity behind',
    () async {
      final gate = Completer<void>();
      final platform = _FakeLiveActivityPlatform(startGate: gate);
      final service = CookingLiveActivityService(platform: platform);

      final starting = service.start(firstStep);
      await Future<void>.delayed(Duration.zero);
      final ending = service.end(
        const CookingLiveActivitySnapshot(
          recipeName: 'Mashed potatoes',
          stepIndex: 5,
          totalSteps: 5,
          instruction: 'Done',
          activityType: StepActivityType.complete,
          isCompleted: true,
        ),
      );
      gate.complete();
      await Future.wait([starting, ending]);

      expect(platform.calls, ['start', 'end']);
      expect(platform.states.last['isCompleted'], isTrue);
      expect(service.isActive, isFalse);
    },
  );
}

class _FakeLiveActivityPlatform implements LiveActivityPlatform {
  final bool supported;
  final Completer<void>? startGate;
  final List<String> calls = [];
  final List<Map<String, Object?>> states = [];

  _FakeLiveActivityPlatform({this.supported = true, this.startGate});

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<void> start(Map<String, Object?> state) async {
    calls.add('start');
    states.add(state);
    await startGate?.future;
  }

  @override
  Future<void> update(Map<String, Object?> state) async {
    calls.add('update');
    states.add(state);
  }

  @override
  Future<void> end(Map<String, Object?> state) async {
    calls.add('end');
    states.add(state);
  }
}
