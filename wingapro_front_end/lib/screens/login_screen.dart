// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';  // for kDebugMode
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// ✅ Import the shared TokenService
import 'package:wingapro/services/token_service.dart';  // adjust path if needed
import '../widgets/custom_button.dart';
import 'buyer/dashboard_screen.dart';
import 'seller/seller_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'register_screen.dart';
import 'package:wingapro/services/api_config.dart';

/// Secure auth service using the shared TokenService for JWT token
class AuthService {
  final TokenService _tokenService = TokenService();  // ✅ use shared service
  final _prefs = SharedPreferencesAsync();

  Future<Map<String, dynamic>> login(String username, String password) async {
    // Sanitize inputs
    final sanitizedUsername = username.trim().toLowerCase();
    if (sanitizedUsername.isEmpty || password.isEmpty) {
      throw Exception('Username/email/phone and password are required');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/api/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': sanitizedUsername,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('Login response status: ${response.statusCode}');
        print('Login response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['token'] != null) {
          // ✅ use TokenService to store token
          await _tokenService.setToken(data['token']);
          await _prefs.setString('user_role', data['user']['role']);
          return data;
        } else {
          throw Exception(data['message'] ?? 'Invalid credentials');
        }
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          throw Exception(errorBody['message'] ?? 'Login failed (${response.statusCode})');
        } catch (_) {
          throw Exception('Server error: ${response.statusCode}');
        }
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: Unable to reach server. Check your internet connection.');
    } on FormatException {
      throw Exception('Invalid server response. Please try again later.');
    } catch (e) {
      throw Exception('Login failed: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> logout() async {
    // ✅ use TokenService to delete token
    await _tokenService.deleteToken();
    await _prefs.remove('user_role');
  }

  Future<String?> getToken() async {
    // ✅ use TokenService to read token
    return await _tokenService.getToken();
  }
}

// ---- Everything below this line is UNCHANGED ----
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();
  final AuthService _auth = AuthService();
  bool _isLoading = false;
  bool _isNetworkError = false;

  @override
  void initState() {
    super.initState();
    _checkAndClearInvalidToken();
  }

  Future<void> _checkAndClearInvalidToken() async {
    // Optional: clear token if you want to force login every time
  }

  Future<void> _handleLogin() async {
    setState(() => _isNetworkError = false);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final responseData = await _auth.login(
        _identifierController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        final role = responseData['user']['role'];
        Widget nextScreen;
        switch (role) {
          case 'admin':
            nextScreen = const AdminDashboardScreen();
            break;
          case 'seller':
            nextScreen = const SellerDashboardScreen();
            break;
          default:
            nextScreen = const DashboardScreen();
        }

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => nextScreen,
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (errorMsg.toLowerCase().contains('network')) {
        setState(() => _isNetworkError = true);
        _showError('No internet connection. Please check your WiFi or mobile data.');
      } else {
        _showError(errorMsg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleForgotPassword() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Password Reset'),
        content: const Text(
          'why do you forget your pasword\n'
              'contact me immediately 0621215286.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A2E5C), Color(0xFF1E88E5)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo & Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                'assets/images/wingapro.png',
                                width: 62,
                                height: 62,
                                errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.wifi_tethering, size: 50, color: Color(0xFF0A2E5C)),
                              ),
                            ),
                            const Text(
                              'WINGA PRO',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A2E5C),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Network error banner
                        if (_isNetworkError)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.wifi_off, color: Colors.red.shade700, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No internet connection',
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Username / Email / Phone field
                        TextFormField(
                          controller: _identifierController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Email or Phone Number',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email or phone number';
                            }
                            if (value.trim().length < 3) {
                              return 'Too short';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 4) {
                              return 'Password too short';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _handleForgotPassword,
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF1E88E5)),
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Login button
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : CustomButton(
                          label: 'Login',
                          onPressed: _handleLogin,
                          isGradient: true,
                        ),
                        const SizedBox(height: 12),

                        // Register button
                        OutlinedButton(
                          onPressed: _navigateToRegister,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0A2E5C),
                            side: const BorderSide(color: Color(0xFF0A2E5C)),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('Create New Account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}