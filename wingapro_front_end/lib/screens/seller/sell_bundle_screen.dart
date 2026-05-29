// lib/screens/seller/sell_bundle_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wingapro/services/api_config.dart';
import 'package:wingapro/services/token_service.dart';

class SellBundleScreen extends StatefulWidget {
  final Map<String, dynamic>? package;

  const SellBundleScreen({super.key, this.package});

  @override
  State<SellBundleScreen> createState() => _SellBundleScreenState();
}

class _SellBundleScreenState extends State<SellBundleScreen> {
  final TokenService _tokenService = TokenService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _dataSizeController;
  late TextEditingController _validityController;
  String _selectedNetwork = 'Vodacom';
  final List<String> _networks = ['Vodacom', 'Mixby', 'Yas', 'Halotel', 'Airtel'];
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
    if (widget.package != null && widget.package!['network'] != null) {
      _selectedNetwork = widget.package!['network'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _dataSizeController.dispose();
    _validityController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Package name is required';
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) return 'Only letters and spaces allowed';
    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) return 'Price is required';
    final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeric.isEmpty) return 'Enter a valid number';
    return null;
  }

  String? _validateDataSize(String? value) {
    if (value == null || value.trim().isEmpty) return 'Data size is required';
    final lower = value.toLowerCase();
    if (!lower.contains('mb') && !lower.contains('gb')) {
      return 'Must include MB or GB (e.g., 500MB, 2GB)';
    }
    final numberPart = lower.replaceAll(RegExp(r'[^0-9.]'), '');
    if (numberPart.isEmpty) return 'Enter a number before unit';
    return null;
  }

  String? _validateValidity(String? value) {
    if (value == null || value.trim().isEmpty) return 'Validity is required';
    final lower = value.toLowerCase();
    if (!lower.contains('hour') && !lower.contains('day') && !lower.contains('hr') && !lower.contains('days')) {
      return 'Must include hours or days (e.g., 24 hours, 7 days)';
    }
    final numberPart = lower.replaceAll(RegExp(r'[^0-9.]'), '');
    if (numberPart.isEmpty) return 'Enter a number before unit';
    return null;
  }

  Future<void> _redirectToLogin() async {
    if (mounted) {
      await _tokenService.deleteToken();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        await _redirectToLogin();
        return;
      }

      final body = jsonEncode({
        'name': _nameController.text.trim(),
        'price': _priceController.text.trim(),
        'dataSize': _dataSizeController.text.trim(),
        'validity': _validityController.text.trim(),
        'network': _selectedNetwork,
      });

      http.Response response;
      String url;
      if (_isEditing) {
        url = '${ApiConfig.baseUrl}/api/seller/packages/${widget.package!['id']}';
        response = await http.put(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body,
        );
      } else {
        url = '${ApiConfig.baseUrl}/api/seller/packages';
        response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body,
        );
      }

      print('📡 API call to: $url');
      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      if (response.statusCode == 401) {
        await _redirectToLogin();
        return;
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing ? 'Package updated successfully!' : 'Package added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
        return;
      }

      // Handle error responses (including HTML errors)
      String errorMessage;
      try {
        // Try to parse as JSON
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['message'] ?? 'Failed to ${_isEditing ? 'update' : 'add'} package';
      } catch (e) {
        // Response is not JSON (likely HTML error page)
        errorMessage = 'Server error (${response.statusCode}). Please check your connection or contact support.';
        if (response.body.contains('<html')) {
          errorMessage = 'API endpoint error: The server returned an HTML page instead of JSON. Endpoint may be incorrect.';
        }
      }
      throw Exception(errorMessage);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
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
                  helperText: 'Only letters and spaces',
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (e.g., 1000 or 1,000)',
                  border: OutlineInputBorder(),
                  helperText: 'Numbers only',
                ),
                keyboardType: TextInputType.number,
                validator: _validatePrice,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dataSizeController,
                decoration: const InputDecoration(
                  labelText: 'Data Size (e.g., 500MB, 2GB)',
                  border: OutlineInputBorder(),
                  helperText: 'Include MB or GB',
                ),
                validator: _validateDataSize,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _validityController,
                decoration: const InputDecoration(
                  labelText: 'Validity (e.g., 24 hours, 7 days)',
                  border: OutlineInputBorder(),
                  helperText: 'Include hours or days',
                ),
                validator: _validateValidity,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedNetwork,
                items: _networks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                onChanged: (value) => setState(() => _selectedNetwork = value!),
                decoration: const InputDecoration(
                  labelText: 'Mobile Network',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.signal_cellular_alt),
                ),
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