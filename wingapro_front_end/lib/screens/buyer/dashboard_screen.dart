import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wingapro/screens/login_screen.dart';
import 'package:wingapro/screens/buyer/buyer_wallet_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wingapro/screens/buyer/buyer_profile_screen.dart';
import 'package:wingapro/screens/buyer/buyer_orders_screen.dart';
import 'package:wingapro/services/api_config.dart';
import 'package:wingapro/services/token_service.dart';

// ==================== MODELS ====================
class InternetPackage {
  final int id;
  final String name;
  final String price;
  final String dataSize;
  final String validity;
  final String sellerName;
  final String sellerPhone;
  final Color color;

  InternetPackage({
    required this.id,
    required this.name,
    required this.price,
    required this.dataSize,
    required this.validity,
    required this.sellerName,
    required this.sellerPhone,
    required this.color,
  });

  factory InternetPackage.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'] ?? {};
    return InternetPackage(
      id: json['id'],
      name: json['name'] ?? 'Unnamed',
      price: json['price'] ?? 'TZS 0',
      dataSize: json['dataSize'] ?? '0GB',
      validity: json['validity'] ?? 'N/A',
      sellerName: seller['username'] ?? 'Unknown Seller',
      sellerPhone: seller['phone'] ?? 'No phone',
      color: _getColorForPackage(json['name'] ?? ''),
    );
  }

  static Color _getColorForPackage(String name) {
    switch (name.toLowerCase()) {
      case 'daily bundle': return const Color(0xFF0066CC);
      case 'weekly bundle': return const Color(0xFF2D9CDB);
      case 'monthly bundle': return const Color(0xFF10B981);
      case 'business pro': return const Color(0xFF0A2647);
      default: return const Color(0xFF0066CC);
    }
  }
}

// ==================== PACKAGE CARD ====================
class PackageCard extends StatelessWidget {
  final InternetPackage package;
  final VoidCallback onBuy;

  const PackageCard({super.key, required this.package, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: package.color.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: package.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.wifi, size: 24, color: package.color),
              ),
              const SizedBox(height: 8),
              Text(package.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(package.dataSize, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(package.price, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0066CC))),
              const SizedBox(height: 4),
              Text(package.validity, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const Divider(height: 16),
              Text('Seller: ${package.sellerName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              Text(package.sellerPhone, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onBuy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: package.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Buy Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== SERVICE ====================
class PackageService {
  Future<List<InternetPackage>> fetchPackages() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/packages'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => InternetPackage.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load packages: ${response.statusCode}');
    }
  }
}

// ==================== MAIN SCREEN ====================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TokenService _tokenService = TokenService();  // ✅ Use shared service
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  int _selectedIndex = 0; // 0: Home, 1: Orders, 2: Wallet, 3: Profile

  List<InternetPackage> _packages = [];
  bool _packagesLoading = true;
  String? _packagesError;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        _redirectToLogin();
        return;
      }
      await _loadUserProfile(token);
      await _loadPackages();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  Future<void> _loadUserProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/user/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _user = data['user'];
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPackages() async {
    setState(() {
      _packagesLoading = true;
      _packagesError = null;
    });
    try {
      final packages = await PackageService().fetchPackages();
      setState(() {
        _packages = packages;
        _packagesLoading = false;
      });
    } catch (e) {
      setState(() {
        _packagesError = e.toString();
        _packagesLoading = false;
      });
    }
  }

  void _redirectToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _logout() async {
    await _tokenService.deleteToken();   // ✅ Delete token via service
    // Also remove role from SharedPreferences if stored there
    // (assuming role is still stored in SharedPreferences – optional cleanup)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    _redirectToLogin();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // -------------------- PURCHASE WITH RECIPIENT DETAILS --------------------
  Future<void> _buyPackage(InternetPackage package) async {
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    String selectedNetwork = 'Vodacom';
    final List<String> networks = ['Vodacom', 'Airtel', 'Tigo', 'Halotel', 'Mixby', 'Yas'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Buy ${package.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Price: ${package.price}'),
              Text('Data: ${package.dataSize}'),
              Text('Validity: ${package.validity}'),
              const Divider(),
              Text('Seller: ${package.sellerName}\nPhone: ${package.sellerPhone}'),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Recipient Name (jina la mteja)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Recipient Phone Number (namba ya sim card)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedNetwork,
                items: networks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                onChanged: (value) => selectedNetwork = value!,
                decoration: const InputDecoration(
                  labelText: 'Mobile Network',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.network_cell),
                ),
              ),
              const SizedBox(height: 16),
              Text('Your balance: TZS ${(_user?['wallet_balance'] ?? 0).toStringAsFixed(0)}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm Purchase')),
        ],
      ),
    );

    if (confirmed != true) return;

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await _tokenService.getToken();
      if (token == null) throw Exception('Not logged in');
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/purchase'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'packageId': package.id,
          'recipientName': name,
          'recipientPhone': phone,
          'network': selectedNetwork,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        await _loadUserProfile(token);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']), backgroundColor: Colors.green),
        );
      } else {
        throw Exception(data['message'] ?? 'Purchase failed');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // -------------------- HOME TAB --------------------
  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: () async {
        final token = await _tokenService.getToken();
        if (token != null) await _loadUserProfile(token);
        await _loadPackages();
      },
      color: const Color(0xFF0066CC),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildUserInfoCard(),
            const SizedBox(height: 16),
            _buildPackagesGrid(),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    final balance = (_user?['wallet_balance'] is num)
        ? (_user?['wallet_balance'] as num).toDouble()
        : double.tryParse(_user?['wallet_balance']?.toString() ?? '0') ?? 0.0;
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
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Color(0xFF0066CC)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_user?['username'] ?? 'User',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(_user?['phone'] ?? 'No phone',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Wallet Balance', style: TextStyle(color: Colors.white70)),
                  Text('TZS ${balance.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackagesGrid() {
    if (_packagesLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_packagesError != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text('Error: $_packagesError'),
            ElevatedButton(onPressed: _loadPackages, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_packages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No packages available from sellers.')),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _packages.length,
        itemBuilder: (context, index) {
          return PackageCard(
            package: _packages[index],
            onBuy: () => _buyPackage(_packages[index]),
          );
        },
      ),
    );
  }

  // -------------------- OTHER TABS --------------------
  Widget _buildOrdersTab() => const BuyerOrdersScreen();
  Widget _buildWalletTab() => const BuyerWalletScreen();
  Widget _buildProfileTab() => const BuyerProfileScreen();

  Widget _getBodyForIndex(int index) {
    switch (index) {
      case 0: return _buildHomeContent();
      case 1: return _buildOrdersTab();
      case 2: return _buildWalletTab();
      case 3: return _buildProfileTab();
      default: return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.account_circle),
          onPressed: () => setState(() => _selectedIndex = 3),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_user?['username'] ?? 'User',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(_user?['phone'] ?? 'No phone',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Optional: implement search screen later
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search coming soon')));
            },
          ),
        ],
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade100),
        ),
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
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}