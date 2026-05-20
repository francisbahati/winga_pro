// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const WingaProApp());
}

class WingaProApp extends StatelessWidget {
  const WingaProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WINGA PRO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          primary: const Color(0xFF0A2E5C), // dark blue
          secondary: const Color(0xFF1E88E5), // ocean blue
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}