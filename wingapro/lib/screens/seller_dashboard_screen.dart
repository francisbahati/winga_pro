// lib/screens/seller_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class SellerDashboardScreen extends StatelessWidget {
  const SellerDashboardScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    if (context.mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller Dashboard'), backgroundColor: Colors.orange),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(decoration: BoxDecoration(color: Colors.orange), child: Text('Seller Menu', style: TextStyle(color: Colors.white, fontSize: 24))),
            ListTile(title: const Text('My Packages'), onTap: () {}),
            ListTile(title: const Text('Add Package'), onTap: () {}),
            ListTile(title: const Text('Sales Report'), onTap: () {}),
            ListTile(title: const Text('Logout'), onTap: () => _logout(context)),
          ],
        ),
      ),
      body: const Center(child: Text('Seller Dashboard - Coming Soon', style: TextStyle(fontSize: 24))),
    );
  }
}