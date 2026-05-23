import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bundle_provider.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bundleProvider = Provider.of<BundleProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Overview',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.shopping_bag),
                title: const Text('Total Bundles'),
                subtitle: Text('${bundleProvider.bundles.length} bundles available'),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.people),
                title: Text('Total Users'),
                subtitle: Text('Admin: 1, Staff: 0, Customers: 0'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'All Bundles (Admin View)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: bundleProvider.bundles.length,
                itemBuilder: (ctx, i) {
                  final b = bundleProvider.bundles[i];
                  return ListTile(
                    leading: b.imagePath.isNotEmpty && File(b.imagePath).existsSync()
                        ? Image.file(File(b.imagePath), width: 50, height: 50, fit: BoxFit.cover)
                        : const Icon(Icons.image),
                    title: Text(b.title),
                    subtitle: Text('${b.price} | Expires: ${b.expiryDate}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}