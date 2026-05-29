// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wingapro/screens/login_screen.dart';

void main() {
  testWidgets('Login screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('WINGA PRO'), findsOneWidget);
  });
}