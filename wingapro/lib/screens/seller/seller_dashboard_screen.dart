// lib/screens/seller_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wingapro/screens/login_screen.dart';
import 'package:wingapro/screens/seller/sell_bundle_screen.dart';
import 'package:wingapro/screens/seller/seller_wallet_screen.dart';
import 'package:wingapro/services/api_config.dart';

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
      price: json['price'],
      dataSize: json['dataSize'],
      validity: json['validity'],
      color: _getColorForPackage(json['name']),
    );
  }

  static Color _getColorForPackage(String name) {
    switch (name.toLowerCase()) {
      case 'daily 500mb': return const Color(0xFF0066CC);
      case 'weekly 3gb': return const Color(0xFF2D9CDB);
      case 'monthly 10gb': return const Color(0xFF10B981);
      case 'business 50gb': return const Color(0xFF0A2647);
      default: return const Color(0xFF0066CC);
    }
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
  Map<String, dynamic>? _user;
  List<InternetPackage> _packages = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) throw Exception('Not logged in');

      // Load profile
      final profileRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/user/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (profileRes.statusCode == 200) {
        final profileData = jsonDecode(profileRes.body);
        if (profileData['success'] == true) {
          setState(() => _user = profileData['user']);
        }
      }

      // Load seller's packages
      final packagesRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/seller/packages'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (packagesRes.statusCode == 200) {
        final List<dynamic> data = jsonDecode(packagesRes.body);
        setState(() {
          _packages = data.map((p) => InternetPackage.fromJson(p)).toList();
        });
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  // -------------------- HOME TAB --------------------
  Widget _buildHomeContent() {
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
            _buildPackagesSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final rawBalance = _user?['wallet_balance'];
    final balance = (rawBalance is num) ? rawBalance.toDouble() : double.tryParse(rawBalance?.toString() ?? '0') ?? 0.0;
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
              const Text('WingaPro Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('TZS ${balance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 8),
                  const Text('TSh', style: TextStyle(fontSize: 14, color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Internal digital wallet', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackagesSection() {
    final displayPackages = _packages.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Packages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Swipe →', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: displayPackages.length + 1,
            itemBuilder: (context, index) {
              if (index == displayPackages.length) {
                return _buildMorePackagesCard();
              }
              final pkg = displayPackages[index];
              return _buildPackageCard(pkg);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPackageCard(InternetPackage pkg) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
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
                  decoration: BoxDecoration(color: pkg.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.wifi, size: 20, color: pkg.color),
                ),
                const SizedBox(height: 8),
                Text(pkg.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(pkg.dataSize, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(pkg.price, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: pkg.color)),
                const SizedBox(height: 2),
                Text(pkg.validity, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                      onPressed: () => _editPackage(pkg),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                      onPressed: () => _deletePackage(pkg.id, pkg.name),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMorePackagesCard() {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 1),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grid_view, size: 32, color: Color(0xFF0066CC)),
                SizedBox(height: 8),
                Text('All\nPackages', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------- PACKAGES TAB (Full Grid) --------------------
  Widget _buildPackagesPage() {
    if (_packages.isEmpty) {
      return const Center(child: Text('No packages added yet'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _packages.length,
      itemBuilder: (context, index) {
        final pkg = _packages[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: pkg.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.wifi, size: 24, color: pkg.color),
                ),
                const SizedBox(height: 12),
                Text(pkg.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(pkg.dataSize, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(pkg.price, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pkg.color)),
                const SizedBox(height: 4),
                Text(pkg.validity, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.blue), onPressed: () => _editPackage(pkg)),
                    IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _deletePackage(pkg.id, pkg.name)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // -------------------- WALLET TAB --------------------
  Widget _buildWalletTab() {
    return SellerWalletScreen();
  }

  // -------------------- PROFILE TAB --------------------
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const CircleAvatar(radius: 50, backgroundColor: Color(0xFF0066CC), child: Icon(Icons.store, size: 50, color: Colors.white)),
          const SizedBox(height: 16),
          Text(_user?['username'] ?? 'Seller', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_user?['phone'] ?? 'No phone', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(_user?['email'] ?? 'No email', style: const TextStyle(color: Colors.grey)),
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
    );
  }

  // -------------------- HELPER METHODS --------------------
  void _navigateToAddPackage() async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const SellBundleScreen()));
    if (result == true) await _loadData();
  }

  Future<void> _editPackage(InternetPackage pkg) async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => SellBundleScreen(package: pkg.toJson())));
    if (result == true) await _loadData();
  }

  Future<void> _deletePackage(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Package'),
        content: Text('Delete "$name" permanently?'),
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
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/seller/packages/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        await _loadData();
        _showError('Package deleted');
      } else {
        _showError('Failed to delete');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Widget _getBodyForIndex(int index) {
    switch (index) {
      case 0: return _buildHomeContent();
      case 1: return _buildPackagesPage();
      case 2: return _buildWalletTab();    // Orders removed
      case 3: return _buildProfileTab();   // Wallet moved to index 2, profile to 3
      default: return const SizedBox.shrink();
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
            const Text('Welcome back,', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text('${_user?['username'] ?? 'Seller'} 👋', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: Colors.grey.shade100)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: _getBodyForIndex(_selectedIndex)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF0066CC).withOpacity(0.1),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'Packages'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}