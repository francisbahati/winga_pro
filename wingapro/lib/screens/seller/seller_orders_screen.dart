// lib/screens/seller/seller_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wingapro/services/api_config.dart';

class Order {
  final int id;
  final String buyerName;
  final String buyerPhone;
  final String packageName;
  final double amount;
  final String status;
  final String recipientPhone;
  final String recipientName;
  final String network;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.buyerName,
    required this.buyerPhone,
    required this.packageName,
    required this.amount,
    required this.status,
    required this.recipientPhone,
    required this.recipientName,
    required this.network,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      buyerName: json['buyer']['username'] ?? 'Unknown',
      buyerPhone: json['buyer']['phone'] ?? 'No phone',
      packageName: json['package']['name'] ?? 'Unknown package',
      amount: double.parse(json['amount'].toString()),
      status: json['status'],
      recipientPhone: json['recipient_phone'] ?? 'Not provided',
      recipientName: json['recipient_name'] ?? 'Not provided',
      network: json['network'] ?? 'N/A',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) throw Exception('Not logged in');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/seller/orders'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> ordersJson = data['orders'];
          setState(() {
            _orders = ordersJson.map((j) => Order.fromJson(j)).toList();
            _loading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load orders');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
            const SizedBox(height: 8),
            Text('Error: $_error'),
            ElevatedButton(
              onPressed: _loadOrders,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _orders.isEmpty
          ? const Center(child: Text('No orders yet'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.packageName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: order.status == 'completed' ? Colors.green.shade100 : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          order.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: order.status == 'completed' ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Buyer: ${order.buyerName} (${order.buyerPhone})'),
                  Text('Amount: TZS ${order.amount.toStringAsFixed(0)}'),
                  const Divider(),
                  Text('Recipient: ${order.recipientName}'),
                  Text('Phone: ${order.recipientPhone}'),
                  Text('Network: ${order.network}'),
                  const SizedBox(height: 4),
                  Text('Date: ${order.createdAt.toLocal().toString().substring(0, 16)}',
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