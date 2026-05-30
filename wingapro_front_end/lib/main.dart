// lib/main.dart
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wingapro/screens/welcome_screen.dart';
import 'package:wingapro/screens/login_screen.dart';
import 'package:wingapro/screens/reset_password_screen.dart';
import 'package:wingapro/screens/seller/seller_dashboard_screen.dart';
import 'package:wingapro/screens/buyer/dashboard_screen.dart';
import 'package:wingapro/screens/admin/admin_dashboard_screen.dart';
import 'package:wingapro/services/token_service.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TokenService _tokenService = TokenService();
  late AppLinks _appLinks;
  bool _isLoading = true;
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _checkAuthAndNavigate();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((Uri uri) {
      print('🔗 Deep link received: $uri');
      if (uri.path == '/reset') {
        final token = uri.queryParameters['token'];
        if (token != null && token.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ResetPasswordScreen(token: token)),
          );
        }
      }
    });
  }

  /// Check if user is already logged in and decide the starting screen
  Future<void> _checkAuthAndNavigate() async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        _initialScreen = const WelcomeScreen();
      } else if (_isTokenExpired(token)) {
        // Token expired: clear it and go to welcome screen
        await _tokenService.deleteToken();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_role');
        _initialScreen = const WelcomeScreen();
      } else {
        // Valid token – get saved role and navigate directly to dashboard
        final prefs = await SharedPreferences.getInstance();
        final role = prefs.getString('user_role') ?? 'customer';
        switch (role) {
          case 'seller':
            _initialScreen = const SellerDashboardScreen();
            break;
          case 'admin':
            _initialScreen = const AdminDashboardScreen();
            break;
          default:
            _initialScreen = const DashboardScreen(); // buyer dashboard
        }
      }
    } catch (e) {
      print('Auth check error: $e');
      _initialScreen = const WelcomeScreen();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Decode JWT and check expiration
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = _decodeBase64(parts[1]);
      if (payload == null) return true;
      final exp = payload['exp'] as int?;
      if (exp == null) return true;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return now >= exp;
    } catch (e) {
      return true;
    }
  }

  Map<String, dynamic>? _decodeBase64(String str) {
    try {
      String normalized = str.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) normalized += '=';
      final bytes = base64Decode(normalized);
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
        debugShowCheckedModeBanner: false,
      );
    }
    return MaterialApp(
      title: 'WingaPro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: _initialScreen,
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/reset': (context) => const ResetPasswordScreen(token: ''),
      },
    );
  }
}