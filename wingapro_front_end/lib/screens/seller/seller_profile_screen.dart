// lib/screens/seller/seller_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wingapro/services/api_config.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({super.key});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) throw Exception('Not logged in');
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/user/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _user = data['user']);
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(radius: 48, child: Icon(Icons.store, size: 48)),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Username'),
                subtitle: Text(_user?['username'] ?? ''),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(_user?['email'] ?? ''),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Phone'),
                subtitle: Text(_user?['phone'] ?? ''),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Wallet Balance'),
                subtitle: Text('TZS ${(_user?['wallet_balance'] ?? 0).toStringAsFixed(0)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}