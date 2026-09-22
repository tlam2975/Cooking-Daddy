import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'data/datasources/isar_datasource.dart';
import 'data/models/recipe.dart';
import 'firebase_options.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/coming_soon_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/recipe_editor.dart';
import 'screens/cooking_session.dart';
import 'screens/recipe_detail.dart';
import 'screens/settings.dart';
import 'screens/favorites_screen.dart';
import 'screens/shopping_cart_screen.dart';
import 'screens/profile.dart';
import 'screens/ai_features.dart';
import 'screens/app_logs_screen.dart';
import 'services/app_log_service.dart';
import 'services/notification.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';
import 'package:easy_localization/easy_localization.dart';
import 'theme/theme_controller.dart';

void main() {
  runZonedGuarded(
    () async {
      print('MAIN: Starting app...');
      WidgetsFlutterBinding.ensureInitialized();
      await AppLogService.instance.initialize();

      FlutterError.onError = (details) {
        AppLogService.instance.error(
          'Flutter error: ${details.exceptionAsString()}',
          details.stack,
        );
        FlutterError.presentError(details);
      };
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        AppLogService.instance.error(
          'Uncaught platform error: $error',
          stackTrace,
        );
        return true;
      };

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await IsarDatasource.initialize();

      print('MAIN: Isar initialized!');
      await EasyLocalization.ensureInitialized();

      await NotificationService.initialize();

      await ThemeController.instance.load();

      print('MAIN: Running app...');

      runApp(
        EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('vi')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en'),
          child: const CookingDaddyApp(),
        ),
      );
    },
    (error, stackTrace) {
      AppLogService.instance.error('Uncaught zone error: $error', stackTrace);
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        AppLogService.instance.info(line);
        parent.print(zone, line);
      },
    ),
  );
}

class CookingDaddyApp extends StatelessWidget {
  const CookingDaddyApp({super.key});
  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();
  // final RecipeRepository _repository = RecipeRepository();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Cooking Daddy',
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          initialRoute: '/home',
          routes: {
            '/home': (context) => AuthGate(),
            '/signIn': (context) => const SignInScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/recipeEditor': (context) {
              final recipe =
                  ModalRoute.of(context)?.settings.arguments as Recipe?;
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
            '/appLogs': (context) => const AppLogsScreen(),
            // Not built yet — these route to honest "coming soon" placeholders
            // rather than 404ing, so the app doesn't crash if something links
            // to them ahead of the actual feature being built.
            '/shopping': (context) =>
                const Scaffold(body: ShoppingCartScreen()),
            '/favorites': (context) => const Scaffold(body: FavoritesScreen()),
            '/video': (context) => const ComingSoonScreen(
              icon: Icons.play_circle_outline,
              title: 'Video',
              message: 'Tính năng video hướng dẫn đang được xây dựng.',
              showAppBar: true,
            ),
            '/scaleRecipe': (context) => const ComingSoonScreen(
              icon: Icons.balance_outlined,
              title: 'Scale công thức',
              message:
                  'Màn hình scale công thức riêng đang được xây dựng — '
                  'hiện tại việc scale nằm trong màn hình chi tiết công thức.',
              showAppBar: true,
            ),
          },
        );
      },
    );
  }
}
