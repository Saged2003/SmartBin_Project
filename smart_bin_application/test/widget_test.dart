import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bin_eng/main.dart';

void main() {
  testWidgets('Login screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartBinApp());
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}