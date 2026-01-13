import 'package:flutter/material.dart';
import '../screens/home.dart';
import 'screens/recipe_editor.dart';
// import '../screens/cooking_session.dart';

void main() {
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
        // '/cookingEditor': (context) => const CookingSessionScreen(),
      },
    );
  }
}
