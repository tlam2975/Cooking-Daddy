class RecipeTags {
  RecipeTags._();

  static const values = [
    'quick',
    'healthy',
    'budget',
    'comfort',
    'spicy',
    'vegetarian',
    'high-protein',
    'light',
    'kid-friendly',
    'one-pot',
    'no-cook',
    'meal-prep',
    'breakfast',
    'lunch',
    'dinner',
    'dessert',
    'drink',
  ];

  static List<String> normalizeAll(Iterable<dynamic> rawTags) {
    final seen = <String>{};
    final normalized = <String>[];

    for (final raw in rawTags) {
      final tag = normalize(raw?.toString() ?? '');
      if (tag == null || seen.contains(tag)) continue;
      seen.add(tag);
      normalized.add(tag);
      if (normalized.length == 5) break;
    }

    return normalized;
  }

  static String? normalize(String raw) {
    final tag = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    if (tag.isEmpty) return null;
    if (values.contains(tag)) return tag;
    return null;
  }
}
