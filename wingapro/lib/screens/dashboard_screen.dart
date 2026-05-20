// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'login_screen.dart';

// ==================== MODELS ====================
class InternetPackage {
  final String id;
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
      id: json['id'].toString(),
      name: json['name'] ?? 'Unnamed',
      price: json['price'] ?? 'TZS 0',
      dataSize: json['dataSize'] ?? '0GB',
      validity: json['validity'] ?? 'N/A',
      color: _getColorForPackage(json['name'] ?? ''),
    );
  }

  static Color _getColorForPackage(String name) {
    switch (name.toLowerCase()) {
      case 'daily bundle':
        return const Color(0xFF0066CC);
      case 'weekly bundle':
        return const Color(0xFF2D9CDB);
      case 'monthly bundle':
        return const Color(0xFF10B981);
      case 'business pro':
        return const Color(0xFF0A2647);
      default:
        return const Color(0xFF0066CC);
    }
  }
}

// ==================== SERVICE ====================
class PackageService {
  // For Android emulator use 10.0.2.2, for real device use your PC's local IP
  static const String baseUrl = 'http://10.0.2.2:5000/api'; // CHANGE THIS

  // GET /api/packages is public – no token required
  Future<List<InternetPackage>> fetchPackages() async {
    final response = await http.get(
      Uri.parse('$baseUrl/packages'),
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

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  int _selectedIndex = 0;

  List<InternetPackage> _packages = [];
  bool _packagesLoading = true;
  String? _packagesError;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // -------------------- USER & TOKEN LOGIC --------------------
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        _redirectToLogin();
        return;
      }
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(utf8.decode(base64Url.decode(parts[1])));
        setState(() {
          _user = {
            'id': payload['id'],
            'username': payload['username'] ?? 'Francis',
            'email': payload['email'] ?? 'francis@winga.com',
            'role': payload['role'] ?? 'customer',
          };
          _isLoading = false;
        });
        // Fetch packages (public endpoint, no token needed)
        await _loadPackages();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    _redirectToLogin();
  }

  Future<void> _onRefresh() async {
    await _loadPackages();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dashboard refreshed successfully'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  // -------------------- DASHBOARD HOME CONTENT --------------------
  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF0066CC),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const BalanceCard(),
            const SizedBox(height: 16),
            _buildInternetPackagesSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildInternetPackagesSection() {
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
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadPackages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_packages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No packages available')),
      );
    }

    final displayPackages = _packages.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Internet Packages',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: displayPackages.length + 1,
            itemBuilder: (context, index) {
              if (index == displayPackages.length) {
                return _buildMorePackagesCard();
              }
              final package = displayPackages[index];
              return PackageCard(
                package: package,
                onBuy: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Buying ${package.name} - ${package.price}'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMorePackagesCard() {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PackagesPage(packages: _packages),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.more_horiz, size: 48, color: Color(0xFF0066CC)),
                  SizedBox(height: 8),
                  Text(
                    'More\nPackages',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0066CC),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------- PACKAGES PAGE (full list) --------------------
  Widget _buildPackagesPage() {
    if (_packagesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_packagesError != null) {
      return Center(child: Text('Error: $_packagesError'));
    }
    if (_packages.isEmpty) {
      return const Center(child: Text('No packages available'));
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
        return PackageCard(
          package: _packages[index],
          onBuy: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Buying ${_packages[index].name} - ${_packages[index].price}'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------- BOTTOM NAVIGATION --------------------
  Widget _getBodyForIndex(int index) {
    switch (index) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _buildPackagesPage();
      case 2:
        return const Center(child: Text('Analytics Page - Coming Soon', style: TextStyle(color: Colors.grey)));
      case 3:
        return const Center(child: Text('Notifications Page - Coming Soon', style: TextStyle(color: Colors.grey)));
      case 4:
        return const Center(child: Text('Profile Page - Coming Soon', style: TextStyle(color: Colors.grey)));
      default:
        return const SizedBox.shrink();
    }
  }

  // -------------------- BUILD UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: CircleAvatar(
            backgroundColor: Color(0xFF0066CC),
            child: Icon(Icons.person, color: Colors.white),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Welcome back,', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text('${_user?['username'] ?? 'Francis'} 👋', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search coming soon'))),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => setState(() => _selectedIndex = 3),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: Colors.grey.shade100)),
      ),
      drawer: _buildDrawer(),
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
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Notifications'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  // -------------------- DRAWER MENU --------------------
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A2647), Color(0xFF0066CC)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(radius: 32, backgroundColor: Colors.white, child: Icon(Icons.person, size: 36, color: Color(0xFF0066CC))),
                  const SizedBox(height: 12),
                  Text(_user?['username'] ?? 'Francis M.', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_user?['role'] == 'seller' ? 'Seller Account' : 'Customer Account', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business_center, size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(_user?['role'] == 'seller' ? 'Seller Access' : 'Customer Access', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(Icons.dashboard_outlined, 'Dashboard', 0),
            _buildDrawerItem(Icons.shopping_bag_outlined, 'Packages', 1),
            _buildDrawerItem(Icons.swap_horiz, 'Transactions', 2),
            _buildDrawerItem(Icons.people_outline, 'Staff Performance', 3),
            _buildDrawerItem(Icons.storefront_outlined, 'Branches', 4),
            _buildDrawerItem(Icons.attach_money, 'Finance', 5),
            _buildDrawerItem(Icons.support_agent, 'Technical Support', 6),
            _buildDrawerItem(Icons.settings_outlined, 'Settings', 7),
            const Divider(height: 24, thickness: 1),
            _buildDrawerItem(Icons.logout, 'Logout', 8, isLogout: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index, {bool isLogout = false}) {
    return ListTile(
      leading: Icon(icon, color: isLogout ? const Color(0xFFEF4444) : Colors.grey.shade600),
      title: Text(title, style: TextStyle(color: isLogout ? const Color(0xFFEF4444) : Colors.black87)),
      onTap: () {
        Navigator.pop(context);
        if (isLogout) {
          _logout();
        } else if (index == 0 || index == 1) {
          setState(() => _selectedIndex = index);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title page coming soon'), duration: const Duration(seconds: 1)));
        }
      },
    );
  }
}

// ==================== PACKAGES PAGE (full screen) ====================
class PackagesPage extends StatelessWidget {
  final List<InternetPackage> packages;
  const PackagesPage({super.key, required this.packages});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Packages'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: packages.length,
        itemBuilder: (context, index) {
          return PackageCard(
            package: packages[index],
            onBuy: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Buying ${packages[index].name} - ${packages[index].price}'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==================== REUSABLE WIDGETS (BalanceCard, SparklinePainter, PackageCard) ====================
class BalanceCard extends StatefulWidget {
  const BalanceCard({super.key});

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> with SingleTickerProviderStateMixin {
  bool _isBalanceVisible = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  void _toggleBalance() {
    setState(() {
      _isBalanceVisible = !_isBalanceVisible;
      _isBalanceVisible ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        child: Stack(
          children: [
            Positioned(
              bottom: 0,
              right: 0,
              child: Opacity(
                opacity: 0.1,
                child: CustomPaint(size: const Size(120, 80), painter: SparklinePainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('WINGA PRO Balance', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                      IconButton(
                        icon: Icon(_isBalanceVisible ? Icons.visibility_off : Icons.visibility, color: Colors.white70, size: 22),
                        onPressed: _toggleBalance,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(_isBalanceVisible ? 'TZS 450,000' : '••••••••', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                        const SizedBox(width: 8),
                        if (_isBalanceVisible) const Text('TSh', style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Available company wallet balance', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up, size: 14, color: Colors.white70),
                        SizedBox(width: 4),
                        Text('+12% from last month', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(0, size.height * 0.6);
    path.cubicTo(size.width * 0.25, size.height * 0.8, size.width * 0.4, size.height * 0.3, size.width * 0.6, size.height * 0.4);
    path.cubicTo(size.width * 0.75, size.height * 0.5, size.width * 0.9, size.height * 0.2, size.width, size.height * 0.3);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PackageCard extends StatelessWidget {
  final InternetPackage package;
  final VoidCallback onBuy;

  const PackageCard({super.key, required this.package, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: package.color.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: package.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.wifi, size: 24, color: package.color),
                ),
                const SizedBox(height: 12),
                Text(package.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text(package.dataSize, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Text(package.price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0066CC))),
                const SizedBox(height: 4),
                Text(package.validity, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onBuy,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: package.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Buy Now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}