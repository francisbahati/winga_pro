// lib/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wingapro/screens/login_screen.dart';
import 'package:wingapro/services/api_config.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController; // for main tabs (Users, Transactions, Packages, Summary)
  int _selectedBottomNavIndex = 0;

  List<Map<String, dynamic>> _buyers = [];
  List<Map<String, dynamic>> _sellers = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _packages = [];
  double _totalBalance = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) throw Exception('Not logged in');

      // Fetch all users
      final usersRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/users'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (usersRes.statusCode != 200) throw Exception('Failed to load users');
      final usersData = jsonDecode(usersRes.body);
      if (!usersData['success']) throw Exception(usersData['message']);

      final List<dynamic> allUsers = usersData['users'];
      // Separate buyers (role = customer) and sellers (role = seller)
      _buyers = allUsers.where((u) => u['role'] == 'customer').cast<Map<String, dynamic>>().toList();
      _sellers = allUsers.where((u) => u['role'] == 'seller').cast<Map<String, dynamic>>().toList();

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
        if (transData['success']) {
          _transactions = List<Map<String, dynamic>>.from(transData['transactions']);
        }
      }

      // Fetch all packages
      final packagesRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/packages'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (packagesRes.statusCode == 200) {
        _packages = List<Map<String, dynamic>>.from(jsonDecode(packagesRes.body));
      } else {
        throw Exception('Failed to load packages');
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ---------- Block/Unblock User ----------
  Future<void> _toggleUserActive(int userId, bool currentActive) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final res = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/users/$userId/toggle-active'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User status updated'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Failed to update status');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ---------- Delete User (only non-admin) ----------
  Future<void> _deleteUser(int userId, String username, String role) async {
    if (role == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete admin'), backgroundColor: Colors.red),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete $username permanently? All their data (packages, transactions) will be removed.'),
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
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Failed to delete user');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ---------- Delete Package (admin can delete any) ----------
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
        Uri.parse('${ApiConfig.baseUrl}/api/admin/packages/$packageId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package deleted'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Failed to delete package');
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

  // ---------- Build User List (shared for buyers and sellers) ----------
  Widget _buildUserList(List<Map<String, dynamic>> users, String roleTitle) {
    if (users.isEmpty) {
      return Center(child: Text('No $roleTitle found'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (ctx, idx) {
        final u = users[idx];
        final balance = (u['wallet_balance'] is num)
            ? (u['wallet_balance'] as num).toDouble()
            : double.tryParse(u['wallet_balance']?.toString() ?? '0') ?? 0.0;
        final isActive = u['is_active'] ?? true;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF0066CC).withOpacity(0.1),
              child: Text(u['username'][0].toUpperCase(), style: const TextStyle(color: Color(0xFF0066CC), fontWeight: FontWeight.bold)),
            ),
            title: Text(u['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u['email']),
                Text('Phone: ${u['phone'] ?? 'Not set'} | Wallet: TZS ${balance.toStringAsFixed(0)}'),
                if (!isActive) const Text('BLOCKED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isActive ? Icons.block : Icons.check_circle, color: isActive ? Colors.orange : Colors.green),
                  onPressed: () => _toggleUserActive(u['id'], isActive),
                  tooltip: isActive ? 'Block User' : 'Unblock User',
                ),
                if (u['role'] != 'admin')
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteUser(u['id'], u['username'], u['role']),
                    tooltip: 'Delete User',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- Build Transactions Tab ----------
  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return const Center(child: Text('No transactions yet'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _transactions.length,
      itemBuilder: (ctx, idx) {
        final t = _transactions[idx];
        final statusColor = t['status'] == 'completed'
            ? Colors.green
            : (t['status'] == 'pending' ? Colors.orange : Colors.red);
        final amount = (t['amount'] is num)
            ? (t['amount'] as num).toDouble()
            : double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ListTile(
            leading: Icon(Icons.receipt, color: statusColor),
            title: Text('${t['package']['name']} - TZS ${amount.toStringAsFixed(0)}'),
            subtitle: Text(
              'Buyer: ${t['buyer']['username']} | Seller: ${t['seller']['username']}\n'
                  'Status: ${t['status']} | ${t['createdAt']}',
            ),
          ),
        );
      },
    );
  }

  // ---------- Build Packages Tab ----------
  Widget _buildPackagesTab() {
    if (_packages.isEmpty) {
      return const Center(child: Text('No packages available'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _packages.length,
      itemBuilder: (ctx, idx) {
        final p = _packages[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ListTile(
            leading: const Icon(Icons.wifi, color: Color(0xFF0066CC)),
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
    );
  }

  // ---------- Build Summary Tab ----------
  Widget _buildSummaryTab() {
    final totalBuyers = _buyers.length;
    final totalSellers = _sellers.length;
    final restricted = _buyers.where((u) => u['is_active'] == false).length +
        _sellers.where((u) => u['is_active'] == false).length;
    final completedTransactions = _transactions.where((t) => t['status'] == 'completed').length;
    final pendingTransactions = _transactions.where((t) => t['status'] == 'pending').length;
    final failedTransactions = _transactions.where((t) => t['status'] == 'failed' || t['status'] == 'cancelled').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Total Balance Card (gradient)
          Card(
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
                  children: [
                    const Text('Total System Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('TZS ${_totalBalance.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
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
                  _buildSummaryRow('Total Buyers', totalBuyers),
                  _buildSummaryRow('Total Sellers', totalSellers),
                  _buildSummaryRow('Restricted Accounts', restricted),
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
                  _buildSummaryRow('Completed', completedTransactions),
                  _buildSummaryRow('Pending', pendingTransactions),
                  _buildSummaryRow('Failed/Cancelled', failedTransactions),
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

  // ---------- Build Users Section with two tabs (Buyers & Sellers) ----------
  Widget _buildUsersSection() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Color(0xFF0066CC),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF0066CC),
            tabs: [
              Tab(text: 'Buyers', icon: Icon(Icons.people)),
              Tab(text: 'Sellers', icon: Icon(Icons.store)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                RefreshIndicator(onRefresh: _loadData, child: _buildUserList(_buyers, 'buyers')),
                RefreshIndicator(onRefresh: _loadData, child: _buildUserList(_sellers, 'sellers')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Main Body (depends on selected bottom nav) ----------
  Widget _getBodyForIndex(int index) {
    switch (index) {
      case 0:
        return _buildUsersSection();
      case 1:
        return RefreshIndicator(onRefresh: _loadData, child: _buildTransactionsTab());
      case 2:
        return RefreshIndicator(onRefresh: _loadData, child: _buildPackagesTab());
      case 3:
        return _buildSummaryTab();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
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
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      )
          : _getBodyForIndex(_selectedBottomNavIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedBottomNavIndex,
        onDestinationSelected: (index) => setState(() => _selectedBottomNavIndex = index),
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF0066CC).withOpacity(0.1),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.wifi_outlined), selectedIcon: Icon(Icons.wifi), label: 'Packages'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Summary'),
        ],
      ),
    );
  }
}