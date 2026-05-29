// lib/screens/seller/seller_subscription_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wingapro/services/api_config.dart';
import 'package:wingapro/screens/seller/seller_api_service.dart';

class SellerSubscriptionScreen extends StatefulWidget {
  const SellerSubscriptionScreen({super.key});

  @override
  State<SellerSubscriptionScreen> createState() => _SellerSubscriptionScreenState();
}

class _SellerSubscriptionScreenState extends State<SellerSubscriptionScreen> {
  Map<String, dynamic>? _subscription;
  double _walletBalance = 0;
  bool _loading = true;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Get wallet balance
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) throw Exception('Not logged in');
      final profileRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/user/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (profileRes.statusCode == 200) {
        final profileData = jsonDecode(profileRes.body);
        if (profileData['success'] == true) {
          setState(() => _walletBalance = (profileData['user']['wallet_balance'] ?? 0).toDouble());
        }
      }

      // Get subscription using real API
      final sub = await SellerApiService.getSubscriptionStatus();
      setState(() {
        _subscription = sub;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      if (e.toString() == 'Not logged in') {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _paySubscription() async {
    if (_walletBalance < 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance. Please deposit first.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final result = await SellerApiService.paySubscription();
      setState(() => _processing = false);
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.green),
        );
        await _loadData();
      } else {
        throw Exception(result['message'] ?? 'Payment failed');
      }
    } catch (e) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      if (e.toString() == 'Not logged in') Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... same UI as before (no changes needed)
    // Just use _subscription and _walletBalance
    final isActive = _subscription?['isActive'] ?? false;
    final expiryDate = _subscription?['expiryDate'] ?? 'N/A';
    final nextPayment = _subscription?['nextPaymentDue'] ?? 'N/A';
    final amount = _subscription?['amount'] ?? 5000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Card
            Card(
              color: isActive ? Colors.green.shade50 : Colors.red.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      isActive ? Icons.verified : Icons.warning,
                      size: 48,
                      color: isActive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Expires on: $expiryDate'),
                    if (!isActive) const Text('Your subscription has expired. Pay to continue.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Subscription Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _infoRow('Monthly Fee', 'TZS $amount'),
                    _infoRow('Next Payment Due', nextPayment),
                    _infoRow('Wallet Balance', 'TZS ${_walletBalance.toStringAsFixed(0)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!isActive || _walletBalance >= amount)
              ElevatedButton.icon(
                onPressed: _processing ? null : _paySubscription,
                icon: _processing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.payment),
                label: Text(_processing ? 'Processing...' : 'Pay TZS $amount'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066CC),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Subscription ensures your packages are visible to customers. Pay monthly to stay active.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}