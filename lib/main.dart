import 'package:flutter/material.dart';
import 'data/datasources/isar_datasource.dart';
import 'data/models/recipe.dart';
// import 'data/models/category.dart';
import 'screens/home.dart';
import 'screens/recipe_editor.dart';
import 'screens/cooking_session.dart';
import 'screens/recipe_detail.dart';
import 'screens/settings.dart';
import 'screens/profile.dart';
import 'screens/ai_features.dart';
import 'services/notification.dart';
import 'package:easy_localization/easy_localization.dart';

void main() async {
  print('MAIN: Starting app...');
  WidgetsFlutterBinding.ensureInitialized();

  // print('MAIN: Initializing Isar...');
  await IsarDatasource.initialize();
  print('MAIN: Isar initialized!');
  await EasyLocalization.ensureInitialized();

  print('MAIN: Initializing notifications...');
  await NotificationService.initialize();
  print('MAIN: Running app...');

  runApp(
    EasyLocalization(
      supportedLocales: [Locale('en'), Locale('vi')],
      path: 'assets/translations',
      fallbackLocale: Locale('en'),
      child: CookingDaddyApp(),
    ),
  );
}

class CookingDaddyApp extends StatelessWidget {
  const CookingDaddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale.languageCode;
    final fontFamily = currentLocale == 'vi' ? 'DarleySans' : 'Caveat';
    return MaterialApp(
      title: 'Cooking Daddy',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: fontFamily),
      initialRoute: '/home',
      routes: {
        '/home': (context) => const HomePage(),
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
        '/aiFeatures': (context) => AIFeaturesScreen(),
      },
    );
  }
}
