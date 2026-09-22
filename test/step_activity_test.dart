import 'package:cooking_daddy/data/models/recipe.dart';
import 'package:cooking_daddy/services/step_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stored activity type takes priority over inferred keywords', () {
    final step = Step(
      instruction: 'Bake until golden',
      activityType: StepActivityType.mix,
    );

    expect(StepActivityResolver.resolve(step), StepActivityType.mix);
  });

  test('infers deterministic activity types from English instructions', () {
    expect(
      StepActivityResolver.resolve(Step(instruction: 'Dice the onion finely')),
      StepActivityType.chop,
    );
    expect(
      StepActivityResolver.resolve(
        Step(instruction: 'Whisk the eggs until smooth'),
      ),
      StepActivityType.mix,
    );
    expect(
      StepActivityResolver.resolve(Step(instruction: 'Bake for 20 minutes')),
      StepActivityType.bake,
    );
    expect(
      StepActivityResolver.resolve(Step(instruction: 'Let the dough rest')),
      StepActivityType.wait,
    );
  });

  test('infers Vietnamese instructions after folding diacritics', () {
    expect(
      StepActivityResolver.resolve(Step(instruction: 'Băm nhỏ hành tím')),
      StepActivityType.chop,
    );
    expect(
      StepActivityResolver.resolve(Step(instruction: 'Khuấy đều hỗn hợp')),
      StepActivityType.mix,
    );
    expect(
      StepActivityResolver.resolve(Step(instruction: 'Nướng đến khi vàng')),
      StepActivityType.bake,
    );
  });

  test('running timer and completion override the base activity', () {
    final step = Step(
      instruction: 'Stir the sauce',
      activityType: StepActivityType.mix,
    );

    expect(
      StepActivityResolver.effective(step, timerRunning: true),
      StepActivityType.timer,
    );
    expect(
      StepActivityResolver.effective(step, completed: true),
      StepActivityType.complete,
    );
  });

  test('timed unknown steps use timer and other unknown steps use prep', () {
    expect(
      StepActivityResolver.resolve(
        Step(instruction: 'Keep it there', timer: 5),
      ),
      StepActivityType.timer,
    );
    expect(
      StepActivityResolver.resolve(Step(instruction: 'Do the next thing')),
      StepActivityType.prep,
    );
  });
}
