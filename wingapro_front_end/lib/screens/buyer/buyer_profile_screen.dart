import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wingapro/services/api_config.dart';
import 'package:wingapro/screens/login_screen.dart';
import 'package:wingapro/services/token_service.dart';  // ✅ Import shared token service

class BuyerProfileScreen extends StatefulWidget {
  const BuyerProfileScreen({super.key});

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  final TokenService _tokenService = TokenService();  // ✅ Use shared service
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        throw Exception('Not logged in. Please login again.');
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/user/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _user = data['user'];
            _loading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load profile');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Helper function to safely get wallet balance as double
  double _getWalletBalance() {
    final balance = _user?['wallet_balance'];
    if (balance == null) return 0.0;
    if (balance is num) return balance.toDouble();
    if (balance is String) return double.tryParse(balance) ?? 0.0;
    return 0.0;
  }

  // ---------- Logout Method ----------
  Future<void> _logout() async {
    await _tokenService.deleteToken();  // ✅ Delete token via service
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');   // ✅ Clean up role
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfile,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProfile,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 48,
              child: Icon(Icons.person, size: 48),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Username'),
                subtitle: Text(_user?['username'] ?? 'Not set'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(_user?['email'] ?? 'Not set'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Phone'),
                subtitle: Text(_user?['phone'] ?? 'Not set'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Wallet Balance'),
                subtitle: Text('TZS ${_getWalletBalance().toStringAsFixed(0)}'),
              ),
            ),
            const SizedBox(height: 24),
            // Logout Button
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}