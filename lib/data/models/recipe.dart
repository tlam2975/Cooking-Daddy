import 'package:isar/isar.dart';

part 'recipe.g.dart';

@collection
class Recipe {
  Id id = Isar.autoIncrement;
  late String name;
  String? url;
  late String ingredients;
  late String tools;

  @Index() // Add index for fast filtering
  late String category; // Changed from categoryId to category (String)

  late DateTime createdDate;
  List<Step> steps = [];

  Recipe({
    required this.name,
    this.url,
    required this.ingredients,
    required this.tools,
    required this.category, // Changed
    required this.createdDate,
    this.steps = const [],
  });
}

@embedded
class Step {
  String instruction;
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
