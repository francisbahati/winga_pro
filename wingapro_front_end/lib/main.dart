// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/buyer/dashboard_screen.dart';
import 'screens/seller/seller_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');
  final role = prefs.getString('user_role');

  // Determine initial screen
  Widget initialScreen;
  if (token != null && token.isNotEmpty) {
    // User is logged in – go directly to the appropriate dashboard
    switch (role) {
      case 'admin':
        initialScreen = const AdminDashboardScreen();
        break;
      case 'seller':
        initialScreen = const SellerDashboardScreen();
        break;
      default:
        initialScreen = const DashboardScreen(); // buyer / customer
        break;
    }
  } else {
    // No token – show welcome/login flow
    initialScreen = const WelcomeScreen();
  }

  runApp(WingaProApp(initialScreen: initialScreen));
}

class WingaProApp extends StatelessWidget {
  final Widget initialScreen;
  const WingaProApp({super.key, required this.initialScreen});

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
      home: initialScreen,
    );
  }
}