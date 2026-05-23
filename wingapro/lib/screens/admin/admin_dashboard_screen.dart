// lib/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wingapro/screens/login_screen.dart';
import 'package:wingapro/services/api_config.dart'; // ✅ shared ApiConfig (no local duplicate)

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _users = [];
  List<dynamic> _transactions = [];
  List<dynamic> _packages = []; // all packages
  double _totalBalance = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // new tab: Packages
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) throw Exception('Not logged in');

      // Fetch users
      final usersRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/users'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (usersRes.statusCode != 200) throw Exception('Failed to load users');
      final usersData = jsonDecode(usersRes.body);
      if (!usersData['success']) throw Exception(usersData['message']);
      _users = usersData['users'];

      // Fetch total balance
      final balanceRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/total-balance'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (balanceRes.statusCode == 200) {
        final balanceData = jsonDecode(balanceRes.body);
        if (balanceData['success']) _totalBalance = balanceData['totalBalance'].toDouble();
      }

      // Fetch transactions
      final transRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/transactions'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (transRes.statusCode == 200) {
        final transData = jsonDecode(transRes.body);
        if (transData['success']) _transactions = transData['transactions'];
      }

      // Fetch all packages (public endpoint, but admin can use same)
      final packagesRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/packages'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (packagesRes.statusCode == 200) {
        _packages = jsonDecode(packagesRes.body);
      } else {
        throw Exception('Failed to load packages');
      }

      setState(() { _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // Delete any package (admin)
  Future<void> _deletePackage(int packageId, String packageName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Package'),
        content: Text('Delete "$packageName" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/packages/$packageId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        _loadData(); // refresh all
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package deleted'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Failed to delete');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleUserActive(int userId, bool currentActive) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final res = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/users/$userId/toggle-active'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User status updated'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteUser(int userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete $username permanently? All their data will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/users/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Transactions'),
            Tab(text: 'Packages'),
            Tab(text: 'Summary'),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              color: Colors.red,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 32, backgroundColor: Colors.white, child: Icon(Icons.admin_panel_settings, size: 36, color: Colors.red)),
                  SizedBox(height: 12),
                  Text('Admin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: _logout),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : TabBarView(
        controller: _tabController,
        children: [
          // Users Tab (unchanged)
          RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (ctx, idx) {
                final u = _users[idx];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(u['username'][0].toUpperCase())),
                    title: Text(u['username']),
                    subtitle: Text('${u['email']}\nRole: ${u['role']} | Wallet: TZS ${u['wallet_balance']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(u['is_active'] ? Icons.block : Icons.check_circle, color: u['is_active'] ? Colors.orange : Colors.green),
                          onPressed: () => _toggleUserActive(u['id'], u['is_active']),
                          tooltip: u['is_active'] ? 'Restrict' : 'Unrestrict',
                        ),
                        if (u['role'] != 'admin')
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteUser(u['id'], u['username']),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Transactions Tab (unchanged)
          RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              itemCount: _transactions.length,
              itemBuilder: (ctx, idx) {
                final t = _transactions[idx];
                final statusColor = t['status'] == 'completed' ? Colors.green : (t['status'] == 'pending' ? Colors.orange : Colors.red);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text('${t['package']['name']} - TZS ${t['amount']}'),
                    subtitle: Text('Buyer: ${t['buyer']['username']} | Seller: ${t['seller']['username']}\nStatus: ${t['status']} | ${t['createdAt']}'),
                    leading: Icon(Icons.receipt, color: statusColor),
                  ),
                );
              },
            ),
          ),
          // Packages Tab (new)
          RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              itemCount: _packages.length,
              itemBuilder: (ctx, idx) {
                final p = _packages[idx];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.wifi, color: Colors.blue),
                    title: Text(p['name']),
                    subtitle: Text('${p['price']}  |  ${p['dataSize']}  |  ${p['validity']}\nSeller ID: ${p['createdBy']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePackage(p['id'], p['name']),
                      tooltip: 'Delete package',
                    ),
                  ),
                );
              },
            ),
          ),
          // Summary Tab (unchanged)
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Total System Balance', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        Text('TZS ${_totalBalance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Users Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Total Users', _users.length),
                        _buildSummaryRow('Sellers', _users.where((u) => u['role'] == 'seller').length),
                        _buildSummaryRow('Buyers', _users.where((u) => u['role'] == 'customer').length),
                        _buildSummaryRow('Restricted Accounts', _users.where((u) => !u['is_active']).length),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Transaction Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Completed', _transactions.where((t) => t['status'] == 'completed').length),
                        _buildSummaryRow('Pending', _transactions.where((t) => t['status'] == 'pending').length),
                        _buildSummaryRow('Failed/Cancelled', _transactions.where((t) => t['status'] == 'failed' || t['status'] == 'cancelled').length),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Packages Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Total Packages', _packages.length),
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

  Widget _buildSummaryRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(count.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}