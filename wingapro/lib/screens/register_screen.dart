// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart' show ApiConfig;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'customer'; // default buyer (customer)
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'password': _passwordController.text.trim(),
          'role': _selectedRole, // send the selected role
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful! Please login.'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        _showError(data['message'] ?? data['error'] ?? 'Registration failed');
      }
    } catch (e) {
      _showError('Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account'), backgroundColor: const Color(0xFF0A2E5C), foregroundColor: Colors.white),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0A2E5C), Color(0xFF1E88E5)]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('WINGA PRO', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0A2E5C)), textAlign: TextAlign.center),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
                          validator: (v) => v!.trim().isEmpty ? 'Username required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                          validator: (v) => v!.trim().isEmpty ? 'Email required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v!.trim().isEmpty ? 'Password required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v != _passwordController.text.trim() ? 'Passwords do not match' : null,
                        ),
                        const SizedBox(height: 16),
                        // Role selection
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Register as',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'customer', child: Text('Buyer (Customer)')),
                            DropdownMenuItem(value: 'seller', child: Text('Seller')),
                          ],
                          onChanged: (value) => setState(() => _selectedRole = value!),
                          validator: (v) => v == null ? 'Please select a role' : null,
                        ),
                        const SizedBox(height: 24),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A2E5C), minimumSize: const Size(double.infinity, 50)),
                          child: const Text('Register', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Already have an account? Login'),
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
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}