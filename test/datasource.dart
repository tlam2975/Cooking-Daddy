import 'package:cooking_daddy/data/datasources/isar_datasource.dart';

void testDatasource() async {
  await IsarDatasource.initialize();

  final datasource = IsarDatasource();
  final recipes = await datasource.getAllRecipes();

  print('Recipes: ${recipes.length}');
}
