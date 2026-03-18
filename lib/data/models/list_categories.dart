class CategoryData {
  // Keys (stored in database - never change)
  static const List<String> categoryKeys = [
    'breakfast',
    'lunch',
    'dinner',
    'lazy_meals',
    'dessert',
    'drinks',
  ];

  // English display names
  static const Map<String, String> categoriesEN = {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'lazy_meals': 'Lazy meals',
    'dessert': 'Dessert',
    'drinks': 'Drinks',
  };

  // Vietnamese display names
  static const Map<String, String> categoriesVI = {
    'breakfast': 'Bữa sáng',
    'lunch': 'Bữa trưa',
    'dinner': 'Bữa tối',
    'lazy_meals': 'Món lười',
    'dessert': 'Tráng miệng',
    'drinks': 'Đồ uống',
  };

  // Get display name from key
  static String getDisplayName(String key, String languageCode) {
    final map = languageCode == 'vi' ? categoriesVI : categoriesEN;
    return map[key] ?? key;
  }

  // Get all display names for dropdown (in order)
  static List<String> getDisplayNames(String languageCode) {
    final map = languageCode == 'vi' ? categoriesVI : categoriesEN;
    return categoryKeys.map((key) => map[key]!).toList();
  }

  // Convert display name back to key (for saving)
  static String getKeyFromDisplay(String displayName, String languageCode) {
    final map = languageCode == 'vi' ? categoriesVI : categoriesEN;

    // Find the key that has this display name
    for (var entry in map.entries) {
      if (entry.value == displayName) {
        return entry.key;
      }
    }

    // Fallback: try to convert display name to key
    return displayName.toLowerCase().replaceAll(' ', '_');
  }

  // Get key from old display name (for migration)
  static String migrateOldCategory(String oldCategory) {
    // Map old English names to keys
    const migration = {
      'Breakfast': 'breakfast',
      'Lunch': 'lunch',
      'Dinner': 'dinner',
      'Lazy meals': 'lazy_meals',
      'Dessert': 'dessert',
      'Drinks': 'drinks',
    };

    return migration[oldCategory] ??
        oldCategory.toLowerCase().replaceAll(' ', '_');
  }
}
