// lib/screens/seller/seller_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wingapro/screens/login_screen.dart';
import 'package:wingapro/screens/seller/sell_bundle_screen.dart';
import 'package:wingapro/screens/seller/seller_wallet_screen.dart';
import 'package:wingapro/screens/seller/seller_orders_screen.dart';
import 'package:wingapro/services/api_config.dart';
import 'package:wingapro/services/token_service.dart';  // ✅ import TokenService

class InternetPackage {
  final int id;
  final String name;
  final String price;
  final String dataSize;
  final String validity;
  final Color color;

  InternetPackage({
    required this.id,
    required this.name,
    required this.price,
    required this.dataSize,
    required this.validity,
    required this.color,
  });

  factory InternetPackage.fromJson(Map<String, dynamic> json) {
    return InternetPackage(
      id: json['id'],
      name: json['name'],
      price: json['price'].toString(),
      dataSize: json['dataSize'],
      validity: json['validity'],
      color: _getColorForPackage(json['name']),
    );
  }

  static Color _getColorForPackage(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('daily')) return const Color(0xFF0066CC);
    if (lower.contains('weekly')) return const Color(0xFF2D9CDB);
    if (lower.contains('monthly')) return const Color(0xFF10B981);
    return const Color(0xFF0A2647);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'dataSize': dataSize,
    'validity': validity,
  };
}

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final TokenService _tokenService = TokenService();  // ✅ use TokenService
  Map<String, dynamic>? _user;
  List<InternetPackage> _packages = [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  String? _error;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _redirectToLogin() async {
    if (_isRedirecting) return;
    _isRedirecting = true;
    await _tokenService.deleteToken();  // ✅ use TokenService
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ✅ Get token from TokenService
      final token = await _tokenService.getToken();
      print("🔑 Token found: ${token != null ? 'Yes' : 'No'}");

      if (token == null) {
        print("❌ No token, redirecting to login");
        await _redirectToLogin();
        return;
      }

      // Load profile
      print("📡 Fetching profile...");
      final profileRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/user/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("📡 Profile response status: ${profileRes.statusCode}");

      if (profileRes.statusCode == 401) {
        print("❌ Unauthorized, redirecting to login");
        await _redirectToLogin();
        return;
      }

      if (profileRes.statusCode != 200) {
        throw Exception('Profile API error: ${profileRes.statusCode}');
      }

      final profileData = jsonDecode(profileRes.body);
      if (profileData['success'] != true) {
        throw Exception(profileData['message'] ?? 'Failed to load profile');
      }

      setState(() {
        _user = profileData['user'];
      });
      print("✅ Profile loaded: ${_user?['username']}");

      // Load packages
      print("📡 Fetching packages...");
      final packagesRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/seller/packages'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("📡 Packages response status: ${packagesRes.statusCode}");

      if (packagesRes.statusCode == 401) {
        print("❌ Unauthorized, redirecting to login");
        await _redirectToLogin();
        return;
      }

      if (packagesRes.statusCode != 200) {
        throw Exception('Packages API error: ${packagesRes.statusCode}');
      }

      final List<dynamic> data = jsonDecode(packagesRes.body);
      setState(() {
        _packages = data.map((p) => InternetPackage.fromJson(p)).toList();
      });
      print("✅ Packages loaded: ${_packages.length}");

      setState(() => _error = null);
    } catch (e, stack) {
      print("❌ ERROR in _loadData: $e");
      print(stack);
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _logout() async {
    await _tokenService.deleteToken();  // ✅ use TokenService
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Widget _buildBalanceCard() {
    final rawBalance = _user?['wallet_balance'];
    final balance = (rawBalance is num)
        ? rawBalance.toDouble()
        : double.tryParse(rawBalance?.toString() ?? '0') ?? 0.0;
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
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
              const Text('WingaPro Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text('TZS ${balance.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Internal digital wallet',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackagesGrid() {
    if (_packages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No packages added yet. Tap + to add.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _packages.length,
        itemBuilder: (context, index) {
          final pkg = _packages[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: pkg.color.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: pkg.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.wifi, size: 24, color: pkg.color),
                    ),
                    const SizedBox(height: 8),
                    Text(pkg.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(pkg.dataSize,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(pkg.price,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0066CC))),
                    const SizedBox(height: 4),
                    Text(pkg.validity,
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                          onPressed: () => _editPackage(pkg),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                          onPressed: () => _deletePackage(pkg.id, pkg.name),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeContent() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066CC)),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF0066CC),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildBalanceCard(),
            const SizedBox(height: 24),
            _buildPackagesGrid(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersTab() => const SellerOrdersScreen();
  Widget _buildWalletTab() => const SellerWalletScreen();

  Widget _buildProfileTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
                radius: 50,
                backgroundColor: Color(0xFF0066CC),
                child: Icon(Icons.store, size: 50, color: Colors.white)),
            const SizedBox(height: 16),
            Text(_user?['username'] ?? 'Seller',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_user?['phone'] ?? 'No phone',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(_user?['email'] ?? 'No email',
                style: const TextStyle(color: Colors.grey)),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.add_box, color: Color(0xFF0066CC)),
              title: const Text('Add New Package'),
              onTap: _navigateToAddPackage,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAddPackage() async {
    final result = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const SellBundleScreen()));
    if (result == true) await _loadData();
  }

  Future<void> _editPackage(InternetPackage pkg) async {
    final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => SellBundleScreen(package: pkg.toJson())));
    if (result == true) await _loadData();
  }

  Future<void> _deletePackage(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Package'),
        content: Text('Delete "$name" permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final token = await _tokenService.getToken();  // ✅ use TokenService
      if (token == null) {
        await _redirectToLogin();
        return;
      }
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/seller/packages/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        await _loadData();
        _showError('Package deleted');
      } else if (response.statusCode == 401) {
        await _redirectToLogin();
      } else {
        _showError('Failed to delete');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Widget _getBodyForIndex(int index) {
    switch (index) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _buildOrdersTab();
      case 2:
        return _buildWalletTab();
      case 3:
        return _buildProfileTab();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: CircleAvatar(
            backgroundColor: Color(0xFF0066CC),
            child: Icon(Icons.store, color: Colors.white),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome back,',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text('${_user?['username'] ?? 'Seller'} 👋',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToAddPackage,
            tooltip: 'Add Package',
          ),
        ],
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: Colors.grey.shade100)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _getBodyForIndex(_selectedIndex)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF0066CC).withOpacity(0.1),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart),
              label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Wallet'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}