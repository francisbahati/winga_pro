// lib/screens/seller/sell_bundle_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wingapro/services/api_config.dart';
import 'package:wingapro/services/token_service.dart';

class SellBundleScreen extends StatefulWidget {
  final Map<String, dynamic>? package; // for editing

  const SellBundleScreen({super.key, this.package});

  @override
  State<SellBundleScreen> createState() => _SellBundleScreenState();
}

class _SellBundleScreenState extends State<SellBundleScreen> {
  final TokenService _tokenService = TokenService();
  final _formKey = GlobalKey<FormState>();

  // Text controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _dataSizeNumberController = TextEditingController();
  final TextEditingController _validityNumberController = TextEditingController();

  // Dropdown selections
  String _selectedNetwork = 'Vodacom';
  final List<String> _networks = ['Vodacom', 'Mixby', 'Yas', 'Halotel', 'Airtel'];

  String _selectedDataUnit = 'GB';      // options: MB, GB
  final List<String> _dataUnits = ['MB', 'GB'];

  String _selectedValidityUnit = 'Days'; // options: Hours, Days, Weeks
  final List<String> _validityUnits = ['Hours', 'Days', 'Weeks'];

  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.package != null;

    // If editing, pre‑fill fields
    if (widget.package != null) {
      final pkg = widget.package!;
      _nameController.text = pkg['name'] ?? '';

      // Price: remove any non‑digit characters to get raw number
      final priceRaw = pkg['price']?.toString() ?? '';
      _priceController.text = priceRaw.replaceAll(RegExp(r'[^0-9]'), '');

      // Parse dataSize string (e.g., "500MB" -> number=500, unit=MB)
      final dataSizeStr = pkg['dataSize']?.toString() ?? '';
      final dataMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(MB|GB)', caseSensitive: false).firstMatch(dataSizeStr);
      if (dataMatch != null) {
        _dataSizeNumberController.text = dataMatch.group(1)!;
        _selectedDataUnit = dataMatch.group(2)!.toUpperCase();
      }

      // Parse validity string (e.g., "24 hours" -> number=24, unit=Hours)
      final validityStr = pkg['validity']?.toString().toLowerCase() ?? '';
      if (validityStr.contains('hour')) {
        final match = RegExp(r'(\d+)').firstMatch(validityStr);
        if (match != null) _validityNumberController.text = match.group(1)!;
        _selectedValidityUnit = 'Hours';
      } else if (validityStr.contains('week')) {
        final match = RegExp(r'(\d+)').firstMatch(validityStr);
        if (match != null) _validityNumberController.text = match.group(1)!;
        _selectedValidityUnit = 'Weeks';
      } else if (validityStr.contains('day')) {
        final match = RegExp(r'(\d+)').firstMatch(validityStr);
        if (match != null) _validityNumberController.text = match.group(1)!;
        _selectedValidityUnit = 'Days';
      }

      // Network
      if (pkg['network'] != null && _networks.contains(pkg['network'])) {
        _selectedNetwork = pkg['network'];
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _dataSizeNumberController.dispose();
    _validityNumberController.dispose();
    super.dispose();
  }

  // Validators
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Package name is required';
    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) return 'Price is required';
    final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeric.isEmpty) return 'Enter a valid number';
    return null;
  }

  String? _validateDataSizeNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Data size number is required';
    final num = double.tryParse(value);
    if (num == null || num <= 0) return 'Enter a positive number';
    return null;
  }

  String? _validateValidityNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Validity number is required';
    final num = double.tryParse(value);
    if (num == null || num <= 0) return 'Enter a positive number';
    return null;
  }

  // Helper to build full dataSize string (e.g., "500 MB")
  String _buildDataSizeString() {
    final number = _dataSizeNumberController.text.trim();
    final unit = _selectedDataUnit;
    return '$number $unit';
  }

  // Helper to build full validity string (e.g., "24 Hours", "7 Days", "2 Weeks")
  String _buildValidityString() {
    final number = _validityNumberController.text.trim();
    String unit = _selectedValidityUnit.toLowerCase();
    // Make plural if number > 1
    if (int.tryParse(number) != null && int.parse(number) > 1) {
      if (unit == 'hour') unit = 'hours';
      else if (unit == 'day') unit = 'days';
      else if (unit == 'week') unit = 'weeks';
    } else {
      if (unit == 'hours') unit = 'hour';
      else if (unit == 'days') unit = 'day';
      else if (unit == 'weeks') unit = 'week';
    }
    return '$number $unit';
  }

  // Submit package
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        _redirectToLogin();
        return;
      }

      final body = jsonEncode({
        'name': _nameController.text.trim(),
        'price': _priceController.text.trim(),         // raw number string
        'dataSize': _buildDataSizeString(),
        'validity': _buildValidityString(),
        'network': _selectedNetwork,
      });

      http.Response response;
      String url;
      if (_isEditing) {
        url = '${ApiConfig.baseUrl}/api/seller/packages/${widget.package!['id']}';
        response = await http.put(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: body,
        );
      } else {
        url = '${ApiConfig.baseUrl}/api/seller/packages';
        response = await http.post(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: body,
        );
      }

      if (response.statusCode == 401) {
        _redirectToLogin();
        return;
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing ? 'Package updated!' : 'Package added!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
        return;
      }

      // Error handling
      String errorMessage;
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['message'] ?? 'Operation failed';
      } catch (_) {
        errorMessage = 'Server error (${response.statusCode})';
      }
      throw Exception(errorMessage);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _redirectToLogin() {
    if (mounted) {
      _tokenService.deleteToken();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Package' : 'Add Package'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Package Name (manual)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Package Name',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Daily 500MB Bundle',
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 16),

              // Price (only numbers, TZS)
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (TZS)',
                  border: OutlineInputBorder(),
                  prefixText: 'TZS ',
                  hintText: 'e.g., 1000',
                ),
                keyboardType: TextInputType.number,
                validator: _validatePrice,
              ),
              const SizedBox(height: 16),

              // Data Size: number + unit dropdown
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _dataSizeNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Data Size',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., 500',
                      ),
                      keyboardType: TextInputType.number,
                      validator: _validateDataSizeNumber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedDataUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: _dataUnits.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
                      onChanged: (value) => setState(() => _selectedDataUnit = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Validity: number + unit dropdown
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _validityNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Validity',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., 24, 7, 2',
                      ),
                      keyboardType: TextInputType.number,
                      validator: _validateValidityNumber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedValidityUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: _validityUnits.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
                      onChanged: (value) => setState(() => _selectedValidityUnit = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Network dropdown
              DropdownButtonFormField<String>(
                value: _selectedNetwork,
                decoration: const InputDecoration(
                  labelText: 'Mobile Network',
                  border: OutlineInputBorder(),
                ),
                items: _networks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                onChanged: (value) => setState(() => _selectedNetwork = value!),
              ),
              const SizedBox(height: 32),

              // Submit button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2E5C),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isEditing ? 'Update Package' : 'Create Package',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}