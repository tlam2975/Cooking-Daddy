import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/recipe_editor.dart';
import 'data/datasources/isar_datasource.dart';
import 'data/models/recipe.dart';
import 'screens/cooking_session.dart';
import 'services/notification.dart';
import 'screens/recipe_detail.dart';

void main() async {
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
        '/recipeEditor': (context) => const RecipeEditorScreen(),
        '/recipeDetail': (context) => const RecipeDetailScreen(recipeId: 0),
        '/cookingSession': (context) => CookingSessionScreen(
          recipe: ModalRoute.of(context)!.settings.arguments as Recipe,
        ),
      },
    );
  }
}
