// lib/screens/seller/seller_customer_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:wingapro/screens/seller/seller_api_service.dart'; // Updated API service

class SellerCustomerOrdersScreen extends StatefulWidget {
  const SellerCustomerOrdersScreen({super.key});

  @override
  State<SellerCustomerOrdersScreen> createState() => _SellerCustomerOrdersScreenState();
}

class _SellerCustomerOrdersScreenState extends State<SellerCustomerOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
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
      final orders = await SellerApiService.getCustomerOrders();
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      if (e.toString().contains('Not logged in') || e.toString().contains('401')) {
        _redirectToLogin();
      }
    }
  }

  void _redirectToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _updateDeliveryStatus(Map<String, dynamic> order, String newStatus) async {
    String? rejectionReason;
    if (newStatus == 'Rejected') {
      rejectionReason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rejection Reason'),
          content: TextField(
            decoration: const InputDecoration(hintText: 'Why is this order rejected?'),
            onSubmitted: (value) => Navigator.pop(ctx, value),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Skip')),
          ],
        ),
      );
      if (rejectionReason == null) return;
    }

    try {
      final success = await SellerApiService.updateDeliveryStatus(order['id'], newStatus, rejectionReason: rejectionReason);
      if (success) {
        await _loadOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order marked as $newStatus'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
      );
      if (e.toString().contains('Not logged in') || e.toString().contains('401')) _redirectToLogin();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Delivered': return Colors.green;
      case 'Pending': return Colors.orange;
      case 'Rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Delivered': return Icons.check_circle;
      case 'Pending': return Icons.pending;
      case 'Rejected': return Icons.cancel;
      default: return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Orders (Paid)'),
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
            ElevatedButton(onPressed: _loadOrders, child: const Text('Retry')),
          ],
        ),
      )
          : _orders.isEmpty
          ? const Center(child: Text('No paid orders yet'))
          : RefreshIndicator(
        onRefresh: _loadOrders,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _orders.length,
          itemBuilder: (ctx, index) {
            final order = _orders[index];
            final deliveryStatus = order['deliveryStatus'];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(deliveryStatus).withOpacity(0.2),
                  child: Icon(_getStatusIcon(deliveryStatus), color: _getStatusColor(deliveryStatus)),
                ),
                title: Text(order['customerName']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order['packageName']),
                    const SizedBox(height: 4),
                    Text('TZS ${order['price']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                trailing: Chip(
                  label: Text(deliveryStatus),
                  backgroundColor: _getStatusColor(deliveryStatus).withOpacity(0.2),
                  labelStyle: TextStyle(color: _getStatusColor(deliveryStatus)),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow('Customer Phone', order['customerPhone']),
                        const Divider(),
                        _infoRow('Package', order['packageName']),
                        _infoRow('Amount Paid', 'TZS ${order['price']}', color: Colors.green),
                        _infoRow('Payment Date', order['paymentDate']),
                        if (order['deliveredAt'] != null) _infoRow('Delivered At', order['deliveredAt']),
                        if (order['rejectionReason'] != null) _infoRow('Rejection Reason', order['rejectionReason'], color: Colors.red),
                        const SizedBox(height: 12),
                        if (deliveryStatus == 'Pending')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _updateDeliveryStatus(order, 'Delivered'),
                                icon: const Icon(Icons.check),
                                label: const Text('Confirm Delivery'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _updateDeliveryStatus(order, 'Rejected'),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey))),
          Expanded(child: Text(value, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}