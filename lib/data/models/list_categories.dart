class CategoryData {
  static const List<String> categoryKeys = [
    'breakfast',
    'lunch',
    'dinner',
    'lazy_meals',
    'dessert',
    'drinks',
  ];

  static const List<String> categoriesEN = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Lazy meals',
    'Dessert',
    'Drinks',
  ];

  static const List<String> categoriesVI = [
    'Bữa sáng',
    'Bữa trưa',
    'Bữa tối',
    'Món lười',
    'Tráng miệng',
    'Đồ uống',
  ];

  // Helper method to get the right list
  static List<String> getCategories(String languageCode) {
    return languageCode == 'vi' ? categoriesVI : categoriesEN;
  }
}
