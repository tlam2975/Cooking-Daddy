import 'package:flutter/foundation.dart';

class AppNavigationController extends ChangeNotifier {
  AppNavigationController._();

  static final AppNavigationController instance = AppNavigationController._();

  int _selectedTabIndex = 0;

  int get selectedTabIndex => _selectedTabIndex;

  void selectTab(int index) {
    if (_selectedTabIndex == index) return;
    _selectedTabIndex = index;
    notifyListeners();
  }

  void selectDashboard() => selectTab(0);

  void selectRecipes() => selectTab(1);
}
