// lib/screens/seller/sell_bundle_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '/services/api_config.dart';

class SellBundleScreen extends StatefulWidget {
  final Map<String, dynamic>? package; // if provided, we are editing

  const SellBundleScreen({super.key, this.package});

  @override
  State<SellBundleScreen> createState() => _SellBundleScreenState();
}

class _SellBundleScreenState extends State<SellBundleScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _dataSizeController;
  late TextEditingController _validityController;
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.package != null;
    _nameController = TextEditingController(text: widget.package?['name'] ?? '');
    _priceController = TextEditingController(text: widget.package?['price'] ?? '');
    _dataSizeController = TextEditingController(text: widget.package?['dataSize'] ?? '');
    _validityController = TextEditingController(text: widget.package?['validity'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _dataSizeController.dispose();
    _validityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) throw Exception('Not logged in');

      final body = jsonEncode({
        'name': _nameController.text.trim(),
        'price': _priceController.text.trim(),
        'dataSize': _dataSizeController.text.trim(),
        'validity': _validityController.text.trim(),
      });

      http.Response response;
      if (_isEditing) {
        response = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/api/seller/packages/${widget.package!['id']}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body,
        );
      } else {
        response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/packages'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body,
        );
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to ${_isEditing ? 'update' : 'add'} package');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Package' : 'Add New Package'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Package Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (e.g., TZS 1,000)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dataSizeController,
                decoration: const InputDecoration(
                  labelText: 'Data Size (e.g., 500MB)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _validityController,
                decoration: const InputDecoration(
                  labelText: 'Validity (e.g., 24 hours)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2E5C),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(_isEditing ? 'Update Package' : 'Add Package'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}