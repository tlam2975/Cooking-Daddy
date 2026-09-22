import '../data/models/recipe.dart';

class StepActivityResolver {
  const StepActivityResolver._();

  static StepActivityType resolve(Step step) {
    return step.activityType ??
        infer(
          instruction: step.instruction,
          heat: step.heat,
          seasonings: step.seasonings,
          timer: step.timer,
          notes: step.notes,
          whatToLookFor: step.whatToLookFor,
        );
  }

  static StepActivityType effective(
    Step? step, {
    bool timerRunning = false,
    bool completed = false,
  }) {
    if (completed) return StepActivityType.complete;
    if (timerRunning) return StepActivityType.timer;
    if (step == null) return StepActivityType.prep;
    return resolve(step);
  }

  static StepActivityType infer({
    required String instruction,
    String? heat,
    String? seasonings,
    int? timer,
    String? notes,
    String? whatToLookFor,
  }) {
    final text = _foldVietnamese(
      [
        instruction,
        heat,
        seasonings,
        notes,
        whatToLookFor,
      ].whereType<String>().join(' ').toLowerCase(),
    );

    if (_containsAny(text, const [
      'complete',
      'finished',
      'finish cooking',
      'hoan tat',
    ])) {
      return StepActivityType.complete;
    }
    if (_containsAny(text, const [
      'plate',
      'serve',
      'garnish',
      'trinh bay',
      'don ra',
      'trang tri',
    ])) {
      return StepActivityType.plate;
    }
    if (_containsAny(text, const ['bake', 'roast', 'oven', 'broil', 'nuong'])) {
      return StepActivityType.bake;
    }
    if (_containsAny(text, const [
      'chop',
      'slice',
      'dice',
      'mince',
      'peel',
      'cut ',
      'cutting',
      'bam',
      'cat ',
      'thai',
      'got',
    ])) {
      return StepActivityType.chop;
    }
    if (_containsAny(text, const [
      'mix',
      'stir',
      'whisk',
      'mash',
      'fold',
      'beat',
      'knead',
      'toss',
      'blend',
      'combine',
      'tron',
      'khuay',
      'danh',
      'nghien',
      'nhao',
      'dao deu',
    ])) {
      return StepActivityType.mix;
    }
    if (_containsAny(text, const [
      'wait',
      'rest',
      'marinate',
      'chill',
      'cool',
      'set aside',
      'proof',
      'rise',
      'cho',
      'nghi',
      'uop',
      'lam lanh',
      'de nguoi',
      'de yen',
    ])) {
      return StepActivityType.wait;
    }
    if (_containsAny(text, const [
      'heat',
      'boil',
      'simmer',
      'fry',
      'sear',
      'saute',
      'warm',
      'cook',
      'melt',
      'steam',
      'poach',
      'grill',
      'toast',
      'dun',
      'nau',
      'luoc',
      'chien',
      'xao',
      'ran',
      'hap',
      'ham',
      'rang',
    ])) {
      return StepActivityType.heat;
    }
    if (_containsAny(text, const [
      'prepare',
      'prep',
      'wash',
      'rinse',
      'measure',
      'gather',
      'season',
      'crack',
      'drain',
      'chuan bi',
      'rua',
      'do luong',
      'nem',
    ])) {
      return StepActivityType.prep;
    }
    if (timer != null && timer > 0) return StepActivityType.timer;
    return StepActivityType.prep;
  }

  static bool _containsAny(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }

  static String _foldVietnamese(String value) {
    const groups = {
      'a': 'aàáạảãâầấậẩẫăằắặẳẵ',
      'e': 'eèéẹẻẽêềếệểễ',
      'i': 'iìíịỉĩ',
      'o': 'oòóọỏõôồốộổỗơờớợởỡ',
      'u': 'uùúụủũưừứựửữ',
      'y': 'yỳýỵỷỹ',
      'd': 'dđ',
    };
    var result = value;
    for (final entry in groups.entries) {
      for (final character in entry.value.split('')) {
        result = result.replaceAll(character, entry.key);
      }
    }
    return result;
  }
}
