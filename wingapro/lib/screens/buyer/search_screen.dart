import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wingapro/services/api_config.dart';
import 'package:wingapro/screens/buyer/dashboard_screen.dart' as buyer;

class SearchScreen extends StatefulWidget {
  final Function(buyer.InternetPackage) onBuy;

  const SearchScreen({super.key, required this.onBuy});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<buyer.InternetPackage> _allPackages = [];
  List<buyer.InternetPackage> _filteredPackages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPackages();
  }

  Future<void> _fetchPackages() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/packages'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _allPackages = data.map((j) => buyer.InternetPackage.fromJson(j)).toList();
          _filteredPackages = _allPackages;
          _loading = false;
        });
      } else {
        throw Exception('Failed to load packages');
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _search(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPackages = _allPackages;
      } else {
        _filteredPackages = _allPackages.where((pkg) =>
        pkg.name.toLowerCase().contains(query.toLowerCase()) ||
            pkg.sellerName.toLowerCase().contains(query.toLowerCase()) ||
            pkg.price.contains(query)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Packages'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search by package name, seller...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filteredPackages.isEmpty
          ? const Center(child: Text('No packages found'))
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _filteredPackages.length,
        itemBuilder: (context, index) {
          final pkg = _filteredPackages[index];
          return buyer.PackageCard(
            package: pkg,
            onBuy: () => widget.onBuy(pkg),
          );
        },
      ),
    );
  }
}