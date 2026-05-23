// lib/screens/seller/seller_statements_screen.dart
import 'package:flutter/material.dart';
import 'seller_simulation_service.dart';

class SellerStatementsScreen extends StatefulWidget {
  const SellerStatementsScreen({super.key});

  @override
  State<SellerStatementsScreen> createState() => _SellerStatementsScreenState();
}

class _SellerStatementsScreenState extends State<SellerStatementsScreen> {
  List<Map<String, dynamic>> _statements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final data = await SellerSimulationService.getStatements();
    setState(() {
      _statements = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statements'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _statements.isEmpty
          ? const Center(child: Text('No transactions yet.'))
          : ListView.builder(
        itemCount: _statements.length,
        itemBuilder: (ctx, index) {
          final s = _statements[index];
          final isCredit = s['type'] == 'Credit';
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              leading: Icon(isCredit ? Icons.arrow_upward : Icons.arrow_downward, color: isCredit ? Colors.green : Colors.red),
              title: Text(s['description']),
              subtitle: Text('${s['date']}  |  Balance after: TZS ${s['balance_after']}'),
              trailing: Text(
                '${isCredit ? '+' : '-'} TZS ${s['amount']}',
                style: TextStyle(color: isCredit ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}