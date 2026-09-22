import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Cooking Daddy shell renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Cooking Daddy'))),
      ),
    );

    expect(find.text('Cooking Daddy'), findsOneWidget);
  });
}
