import 'package:isar/isar.dart';

part 'recipe.g.dart';

@collection
class Recipe {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String cloudId; // client-generated UUID, stable across devices

  late String name;
  String? url;
  String? imageUrl; // hero image, reference-only, URL stored not downloaded
  List<String> photoSources = []; // ordered local paths or uploaded URLs

  List<Ingredient> ingredients = [];
  List<Tool> tools = [];
  List<Step> steps = [];

  @Index()
  late String categoryKey;

  List<String> tags = []; // dashboard grouping, e.g. "quick", "healthy"

  late DateTime createdDate;
  late DateTime updatedAt; // bump on ANY edit — drives sync delta

  int basePortions = 1;
  bool isFavorite = false;
  bool isSeed = false;
  List<DateTime> cookedAt = [];

  String? sourceRecipeId; // set when this recipe was created via Remix
  String? energyNote; // free-text blurb, generated on-demand only

  Recipe({
    required this.cloudId,
    required this.name,
    this.url,
    this.imageUrl,
    this.photoSources = const [],
    this.ingredients = const [],
    this.tools = const [],
    this.steps = const [],
    required this.categoryKey,
    this.tags = const [],
    required this.createdDate,
    required this.updatedAt,
    this.basePortions = 1,
    this.isFavorite = false,
    this.isSeed = false,
    this.cookedAt = const [],
    this.sourceRecipeId,
    this.energyNote,
  });

  String? get thumbnailSource {
    if (photoSources.isNotEmpty) return photoSources.first;
    return imageUrl;
  }

  List<String> get displayImageSources {
    if (photoSources.isNotEmpty) return photoSources;
    if (imageUrl != null && imageUrl!.isNotEmpty) return [imageUrl!];
    return const [];
  }
}

@embedded
class Ingredient {
  String name = '';
  double? quantity;

  @Enumerated(EnumType.name)
  MeasurementUnit? unit; // enum — reliable scaling math for shopping cart

  String? note; // e.g. "chopped", "to taste"

  Ingredient({this.name = '', this.quantity, this.unit, this.note});
}

enum MeasurementUnit { g, kg, ml, l, tsp, tbsp, cup, pcs }

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
