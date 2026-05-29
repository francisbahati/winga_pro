import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wingapro/services/api_config.dart';
import 'package:wingapro/services/token_service.dart';  // ✅ Import shared token service

class BuyerOrdersScreen extends StatefulWidget {
  const BuyerOrdersScreen({super.key});

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen> {
  final TokenService _tokenService = TokenService();  // ✅ Use shared service
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _tokenService.getToken();
      if (token == null) throw Exception('Not logged in');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/buyer/orders'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() => _orders = List<Map<String, dynamic>>.from(data['orders']));
        } else {
          throw Exception(data['message'] ?? 'Failed to load orders');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadOrders, child: const Text('Retry')),
          ],
        ),
      )
          : _orders.isEmpty
          ? const Center(child: Text('No orders yet'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (ctx, idx) {
          final order = _orders[idx];
          final amount = (order['amount'] is num)
              ? (order['amount'] as num).toDouble()
              : double.tryParse(order['amount']?.toString() ?? '0') ?? 0.0;
          final statusColor = order['status'] == 'completed'
              ? Colors.green
              : (order['status'] == 'pending' ? Colors.orange : Colors.red);
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order['package']['name'] ?? 'Package',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          order['status'].toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Seller: ${order['seller']['username']}'),
                  Text('Amount: TZS ${amount.toStringAsFixed(0)}'),
                  const Divider(),
                  Text('Recipient: ${order['recipient_name'] ?? 'Not specified'}'),
                  Text('Phone: ${order['recipient_phone'] ?? 'Not specified'}'),
                  Text('Network: ${order['network'] ?? 'N/A'}'),
                  const SizedBox(height: 4),
                  Text('Date: ${order['createdAt']?.substring(0, 16) ?? ''}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}