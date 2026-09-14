import 'package:flutter/foundation.dart';

import '../data/models/recipe.dart';

class ShoppingCartItem {
  final String name;
  final MeasurementUnit? unit;
  final String? note;
  double? quantity;
  bool isChecked;

  ShoppingCartItem({
    required this.name,
    this.quantity,
    this.unit,
    this.note,
    this.isChecked = false,
  });

  String get key => [
    name.trim().toLowerCase(),
    unit?.name ?? '',
    note?.trim().toLowerCase() ?? '',
  ].join('|');
}

class ShoppingCart extends ChangeNotifier {
  ShoppingCart._();

  static final ShoppingCart instance = ShoppingCart._();

  final List<ShoppingCartItem> _items = [];

  List<ShoppingCartItem> get items => List.unmodifiable(_items);

  int get uncheckedCount => _items.where((item) => !item.isChecked).length;

  void addRecipe(Recipe recipe, int portions) {
    final scaledItems = recipe.ingredients
        .map(
          (ingredient) =>
              scaleIngredient(ingredient, recipe.basePortions, portions),
        )
        .where((item) => item.name.trim().isNotEmpty);

    for (final item in scaledItems) {
      _mergeItem(item);
    }

    _sortItems();
    notifyListeners();
  }

  void toggleItem(ShoppingCartItem item, bool isChecked) {
    item.isChecked = isChecked;
    notifyListeners();
  }

  void removeItem(ShoppingCartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  ShoppingCartItem scaleIngredient(
    Ingredient ingredient,
    int basePortions,
    int targetPortions,
  ) {
    final safeBase = basePortions <= 0 ? 1 : basePortions;
    final multiplier = targetPortions / safeBase;
    final quantity = ingredient.quantity == null
        ? null
        : roundQuantity(ingredient.quantity! * multiplier, ingredient.unit);

    return ShoppingCartItem(
      name: ingredient.name,
      quantity: quantity,
      unit: ingredient.unit,
      note: ingredient.note,
    );
  }

  String formatItem(ShoppingCartItem item) {
    final parts = <String>[];
    if (item.quantity != null) parts.add(_formatNumber(item.quantity!));
    if (item.unit != null) parts.add(item.unit!.name);
    parts.add(item.name);
    final line = parts.join(' ').trim();

    if (item.note != null && item.note!.trim().isNotEmpty) {
      return '$line (${item.note})';
    }
    return line;
  }

  double roundQuantity(double quantity, MeasurementUnit? unit) {
    if (quantity <= 0) return quantity;

    switch (unit) {
      case MeasurementUnit.g:
      case MeasurementUnit.ml:
        if (quantity < 10) return _roundTo(quantity, 0.5);
        if (quantity < 100) return _roundTo(quantity, 1);
        return _roundTo(quantity, 5);
      case MeasurementUnit.kg:
      case MeasurementUnit.l:
        return _roundTo(quantity, 0.05);
      case MeasurementUnit.tsp:
      case MeasurementUnit.tbsp:
      case MeasurementUnit.cup:
        return _roundTo(quantity, 0.25);
      case MeasurementUnit.pcs:
        return quantity.ceilToDouble();
      case null:
        return _roundTo(quantity, 1);
    }
  }

  void _mergeItem(ShoppingCartItem item) {
    final index = _items.indexWhere((current) => current.key == item.key);
    if (index == -1) {
      _items.add(item);
      return;
    }

    final current = _items[index];
    if (current.quantity == null || item.quantity == null) {
      current.quantity ??= item.quantity;
      return;
    }

    current.quantity = roundQuantity(
      current.quantity! + item.quantity!,
      current.unit,
    );
  }

  void _sortItems() {
    _items.sort((a, b) {
      if (a.isChecked != b.isChecked) return a.isChecked ? 1 : -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  double _roundTo(double value, double step) {
    return (value / step).round() * step;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}
