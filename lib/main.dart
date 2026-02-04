import 'package:flutter/material.dart';
// import 'package:path_provider/path_provider.dart';
import 'screens/home.dart';
import 'screens/recipe_editor.dart';
import 'data/datasources/isar_datasource.dart';
import 'data/models/recipe.dart';
// import 'data/models/category.dart';
import 'screens/cooking_session.dart';
import 'services/notification.dart';
import 'screens/recipe_detail.dart';
import 'screens/settings.dart';
import 'screens/profile.dart';

void main() async {
  // late Isar isar;
  print('MAIN: Starting app...');
  WidgetsFlutterBinding.ensureInitialized();

  print('MAIN: Initializing Isar...');
  await IsarDatasource.initialize();
  print('MAIN: Isar initialized!');

  print('MAIN: Initializing notifications...');
  await NotificationService.initialize();
  print('MAIN: Running app...');

  runApp(const CookingDaddyApp());
}

class CookingDaddyApp extends StatelessWidget {
  const CookingDaddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'PixelifySans'),
      // Set initial route
      initialRoute: '/',
      // Define all routes
      routes: {
        '/': (context) => const HomePage(),
        '/recipeEditor': (context) {
          final recipe = ModalRoute.of(context)?.settings.arguments as Recipe?;
          return RecipeEditorScreen(recipe: recipe);
        },
        '/recipeDetail': (context) => RecipeDetailScreen(
          recipeId: ModalRoute.of(context)!.settings.arguments as int,
        ),
        '/cookingSession': (context) => CookingSessionScreen(
          recipe: ModalRoute.of(context)!.settings.arguments as Recipe,
        ),
        '/settings': (context) => const SettingsScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
