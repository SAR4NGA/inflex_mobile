import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financial_tracker_app/main.dart'; // <-- change YOUR_APP_NAME

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const FinancialTrackerApp());

    // Check that our login screen is shown
    expect(find.text('Login Test'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
