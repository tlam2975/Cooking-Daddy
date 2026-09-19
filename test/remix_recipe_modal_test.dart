import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cooking_daddy/data/models/recipe.dart';
import 'package:cooking_daddy/services/ai_interface.dart';
import 'package:cooking_daddy/widgets/remix_recipe_modal.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AI extends Fake implements AIInterface {
  Completer<AIGenerationResult> pending = Completer();
  int calls = 0;
  String? instructions;
  String? language;

  @override
  Future<AIGenerationResult> remixRecipe({
    required Recipe source,
    required String instructions,
    required String languageCode,
  }) {
    calls++;
    this.instructions = instructions;
    language = languageCode;
    return pending.future;
  }
}

class _Translations extends AssetLoader {
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final language in ['en', 'vi']) {
    testWidgets('$language: suggestion, loading, retry, and draft return', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ai = _AI();
      final source = Recipe(
        cloudId: 'source',
        name: 'Original',
        categoryKey: 'dinner',
        createdDate: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      Recipe? returned;
      await _open(tester, ai, source, language, (result) => returned = result);
      await tester.tap(
        find.widgetWithText(
          ActionChip,
          language == 'en' ? 'Vegetarian' : 'Món chay',
        ),
      );
      await tester.tap(find.bySubtype<FilledButton>());
      await tester.pump();
      expect(ai.calls, 1);
      expect(ai.instructions, isNotEmpty);
      expect(ai.language, language);
      expect(
        tester.widget<FilledButton>(find.bySubtype<FilledButton>()).onPressed,
        isNull,
      );
      ai.pending.complete(
        AIGenerationResult(success: false, error: 'remix_generation_error'),
      );
      await tester.pumpAndSettle();
      expect(find.text('remix_generation_error'.tr()), findsOneWidget);
      expect(returned, isNull);
      ai.pending = Completer();
      await tester.tap(find.bySubtype<FilledButton>());
      await tester.pump();
      ai.pending.complete(AIGenerationResult(success: true, recipe: source));
      await tester.pumpAndSettle();
      expect(ai.calls, 2);
      expect(returned, same(source));
      expect(find.byType(RemixRecipeModal), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'dismissal ignores a response arriving during the closing animation',
    (tester) async {
      final ai = _AI();
      final source = Recipe(
        cloudId: 'source',
        name: 'Original',
        categoryKey: 'dinner',
        createdDate: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      Recipe? returned;
      await _open(tester, ai, source, 'en', (result) => returned = result);
      await tester.tap(find.bySubtype<FilledButton>());
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
      ai.pending.complete(AIGenerationResult(success: true, recipe: source));
      await tester.pumpAndSettle();
      expect(returned, isNull);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _open(
  WidgetTester tester,
  _AI ai,
  Recipe source,
  String language,
  ValueChanged<Recipe?> onResult,
) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('vi')],
      startLocale: Locale(language),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: _Translations(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  onResult(
                    await showModalBottomSheet<Recipe>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          RemixRecipeModal(source: source, aiService: ai),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
