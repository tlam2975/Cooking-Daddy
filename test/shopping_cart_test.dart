import 'package:cooking_daddy/data/models/recipe.dart';
import 'package:cooking_daddy/services/shopping_cart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    ShoppingCart.instance.clear();
  });

  test('scales ingredient quantities by target portions', () {
    final recipe = Recipe(
      cloudId: 'recipe-1',
      name: 'Test soup',
      ingredients: [
        Ingredient(name: 'water', quantity: 500, unit: MeasurementUnit.ml),
        Ingredient(name: 'egg', quantity: 1, unit: MeasurementUnit.pcs),
      ],
      tools: const [],
      steps: const [],
      categoryKey: 'dinner',
      createdDate: DateTime(2026, 9, 14),
      updatedAt: DateTime(2026, 9, 14),
      basePortions: 2,
    );

    ShoppingCart.instance.addRecipe(recipe, 4);

    expect(ShoppingCart.instance.items, hasLength(2));
    expect(ShoppingCart.instance.items[0].name, 'egg');
    expect(ShoppingCart.instance.items[0].quantity, 2);
    expect(ShoppingCart.instance.items[1].name, 'water');
    expect(ShoppingCart.instance.items[1].quantity, 1000);
  });

  test('merges matching ingredients in the cart', () {
    final recipe = Recipe(
      cloudId: 'recipe-2',
      name: 'Test salad',
      ingredients: [
        Ingredient(name: 'salt', quantity: 5, unit: MeasurementUnit.g),
      ],
      tools: const [],
      steps: const [],
      categoryKey: 'dinner',
      createdDate: DateTime(2026, 9, 14),
      updatedAt: DateTime(2026, 9, 14),
      basePortions: 1,
    );

    ShoppingCart.instance.addRecipe(recipe, 1);
    ShoppingCart.instance.addRecipe(recipe, 1);

    expect(ShoppingCart.instance.items, hasLength(1));
    expect(ShoppingCart.instance.items.single.quantity, 10);
  });
}
