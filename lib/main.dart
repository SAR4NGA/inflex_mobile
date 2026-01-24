import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const FinancialTrackerApp());
}

class FinancialTrackerApp extends StatelessWidget {
  const FinancialTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Financial Tracker',
      theme: ThemeData(useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}
