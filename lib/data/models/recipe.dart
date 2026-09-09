import 'package:isar/isar.dart';

part 'recipe.g.dart';

@collection
class Recipe {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String cloudId; // client-generated UUID, stable across devices

  late String name;
  String? url;

  List<Ingredient> ingredients = [];
  List<Tool> tools = [];
  List<Step> steps = [];

  @Index()
  late String categoryKey;

  late DateTime createdDate;
  late DateTime updatedAt;

  int basePortions = 1;
  bool isFavorite = false;
  bool isSeed = false;

  String? sourceRecipeId; // reserved for Phase 4 cloning

  Recipe({
    required this.cloudId,
    required this.name,
    this.url,
    this.ingredients = const [],
    this.tools = const [],
    this.steps = const [],
    required this.categoryKey,
    required this.createdDate,
    required this.updatedAt,
    this.basePortions = 1,
    this.isFavorite = false,
    this.isSeed = false,
    this.sourceRecipeId,
  });
}

@embedded
class Ingredient {
  String name = '';
  double? quantity;
  String? unit;
  String? note; // e.g. "chopped", "to taste"

  Ingredient({this.name = '', this.quantity, this.unit, this.note});
}

@embedded
class Tool {
  String name = '';
  int? quantity;

  Tool({this.name = '', this.quantity});
}

@embedded
class Step {
  String instruction = '';
  String? heat;
  int index = 0;
  String? seasonings;
  int? timer;
  String? notes;
  String whatToLookFor = '';

  Step({
    this.instruction = '',
    this.heat,
    this.index = 0,
    this.seasonings,
    this.timer,
    this.notes,
    this.whatToLookFor = '',
  });
}
