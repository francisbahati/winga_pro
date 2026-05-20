// lib/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

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
      appBar: AppBar(title: const Text('Admin Dashboard'), backgroundColor: Colors.red),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(decoration: BoxDecoration(color: Colors.red), child: Text('Admin Menu', style: TextStyle(color: Colors.white, fontSize: 24))),
            ListTile(title: const Text('Manage Users'), onTap: () {}),
            ListTile(title: const Text('All Packages'), onTap: () {}),
            ListTile(title: const Text('System Logs'), onTap: () {}),
            ListTile(title: const Text('Logout'), onTap: () => _logout(context)),
          ],
        ),
      ),
      body: const Center(child: Text('Admin Dashboard - Coming Soon', style: TextStyle(fontSize: 24))),
    );
  }
}