import 'package:flutter/material.dart';
import 'screens/splash_gate.dart';

void main() {
  runApp(const FinancialTrackerApp());
}

class FinancialTrackerApp extends StatelessWidget {
  const FinancialTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashGate(),
    );
  }
}
