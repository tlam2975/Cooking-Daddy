import 'dart:convert';
import 'dart:io';

import 'package:cooking_daddy/screens/auth/sign_in_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('sign-in screen supports large text on iPhone SE portrait', (
    tester,
  ) async {
    await _pumpSignIn(tester, const Size(320, 568));

    expect(tester.takeException(), isNull);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('sign-in screen supports large text on iPhone SE landscape', (
    tester,
  ) async {
    await _pumpSignIn(tester, const Size(568, 320));

    expect(tester.takeException(), isNull);
    expect(find.byType(SignInScreen), findsOneWidget);
  });
}

Future<void> _pumpSignIn(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('vi')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      assetLoader: _Translations(),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const SignInScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
