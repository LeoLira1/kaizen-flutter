import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';

void main() {
  runApp(const CorpoEmEvolucaoApp());
}

class CorpoEmEvolucaoApp extends StatelessWidget {
  const CorpoEmEvolucaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Corpo em evolução',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFDF8F2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4AADA0),
          brightness: Brightness.light,
          surface: const Color(0xFFFDF8F2),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF2C2A26), height: 1.1),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2C2A26)),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2C2A26)),
          bodyLarge: TextStyle(fontSize: 15, color: Color(0xFF4C4945), height: 1.45),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF5E5A55), height: 1.4),
          bodySmall: TextStyle(fontSize: 12, color: Color(0xFF7A746E)),
        ),
      ),
      home: const BodyDashboardPage(),
    );
  }
}
