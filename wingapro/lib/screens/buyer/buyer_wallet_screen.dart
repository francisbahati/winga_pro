// lib/screens/buyer/buyer_wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wingapro/services/api_config.dart';

class BuyerWalletScreen extends StatefulWidget {
  const BuyerWalletScreen({super.key});

  @override
  State<BuyerWalletScreen> createState() => _BuyerWalletScreenState();
}

class _BuyerWalletScreenState extends State<BuyerWalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _balance = 0;
  bool _loading = true;

  // Deposit
  final _depositAmountController = TextEditingController();
  final _depositMethodController = TextEditingController();
  final List<String> _depositMethods = ['M-Pesa', 'Tigo Pesa', 'Airtel Money', 'Bank Transfer'];

  // Withdraw
  final _withdrawAmountController = TextEditingController();
  final _withdrawPhoneController = TextEditingController();
  String _selectedNetwork = 'M-Pesa';
  final List<String> _networks = ['M-Pesa', 'Tigo Pesa', 'Airtel Money'];

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBalance();
  }

  Future<void> _loadBalance() async {
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
        if (data['success'] == true) {
          final raw = data['user']['wallet_balance'];
          setState(() => _balance = (raw is num) ? raw.toDouble() : double.tryParse(raw?.toString() ?? '0') ?? 0.0);
        }
      }
    } catch (e) {
      _showSnackBar('Error loading balance: $e', Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deposit() async {
    final amount = double.tryParse(_depositAmountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnackBar('Enter a valid amount', Colors.red);
      return;
    }
    final method = _depositMethodController.text.trim();
    if (method.isEmpty) {
      _showSnackBar('Select a deposit method', Colors.red);
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/wallet/deposit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'amount': amount, 'method': method}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _showSnackBar(data['message'], Colors.green);
        _depositAmountController.clear();
        await _loadBalance();
      } else {
        _showSnackBar(data['message'] ?? 'Deposit failed', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _withdraw() async {
    final amount = double.tryParse(_withdrawAmountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnackBar('Enter a valid amount', Colors.red);
      return;
    }
    final phone = _withdrawPhoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackBar('Enter phone number', Colors.red);
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/wallet/withdraw'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'amount': amount, 'phoneNumber': phone, 'network': _selectedNetwork}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _showSnackBar(data['message'], Colors.green);
        _withdrawAmountController.clear();
        _withdrawPhoneController.clear();
        await _loadBalance();
      } else {
        _showSnackBar(data['message'] ?? 'Withdrawal failed', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Deposit', icon: Icon(Icons.arrow_downward)),
            Tab(text: 'Withdraw', icon: Icon(Icons.arrow_upward)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          // Deposit
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildBalanceCard(),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _depositAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Amount (TZS)', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _depositMethodController.text.isNotEmpty ? _depositMethodController.text : null,
                          hint: const Text('Select Payment Method'),
                          items: _depositMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (value) => _depositMethodController.text = value!,
                          decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 24),
                        _isProcessing
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                          onPressed: _deposit,
                          icon: const Icon(Icons.add_circle),
                          label: const Text('Deposit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0066CC),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Withdraw
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildBalanceCard(),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _withdrawAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Amount (TZS)', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedNetwork,
                          items: _networks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                          onChanged: (value) => setState(() => _selectedNetwork = value!),
                          decoration: const InputDecoration(labelText: 'Mobile Network', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _withdrawPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 24),
                        _isProcessing
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                          onPressed: _withdraw,
                          icon: const Icon(Icons.logout),
                          label: const Text('Withdraw'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A2647), Color(0xFF0066CC), Color(0xFF2D9CDB)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                'TZS ${_balance.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _depositAmountController.dispose();
    _depositMethodController.dispose();
    _withdrawAmountController.dispose();
    _withdrawPhoneController.dispose();
    super.dispose();
  }
}