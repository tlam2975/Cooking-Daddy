import 'package:isar/isar.dart';

part 'category.g.dart';

@collection
class Category {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String key; // "breakfast", "lunch", "user_custom_123"

  late bool isBuiltIn; // true = system category, false = user-created

  late DateTime createdDate;

  Category({
    required this.key,
    required this.isBuiltIn,
    required this.createdDate,
  });
}
