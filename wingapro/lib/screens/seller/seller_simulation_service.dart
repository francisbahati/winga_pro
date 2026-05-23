// lib/screens/seller/seller_simulation_service.dart
import 'dart:math';

class SellerSimulationService {
  // ==================== PACKAGE METHODS ====================
  static Future<List<Map<String, dynamic>>> getMyPackages() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      {'id': 1, 'name': 'Daily 500MB', 'price': 'TZS 1,000', 'dataSize': '500MB', 'validity': '24 hours'},
      {'id': 2, 'name': 'Weekly 3GB', 'price': 'TZS 5,000', 'dataSize': '3GB', 'validity': '7 days'},
      {'id': 3, 'name': 'Monthly 10GB', 'price': 'TZS 15,000', 'dataSize': '10GB', 'validity': '30 days'},
      {'id': 4, 'name': 'Business 50GB', 'price': 'TZS 50,000', 'dataSize': '50GB', 'validity': '30 days'},
      {'id': 5, 'name': 'Daily 1GB', 'price': 'TZS 2,000', 'dataSize': '1GB', 'validity': '24 hours'},
      {'id': 6, 'name': 'Night Bundle', 'price': 'TZS 500', 'dataSize': '2GB', 'validity': '12 hours'},
      {'id': 7, 'name': 'Weekend Plus', 'price': 'TZS 3,000', 'dataSize': '5GB', 'validity': '2 days'},
      {'id': 8, 'name': 'Monthly 20GB', 'price': 'TZS 25,000', 'dataSize': '20GB', 'validity': '30 days'},
      {'id': 9, 'name': 'Social Bundle', 'price': 'TZS 800', 'dataSize': '500MB', 'validity': '24 hours'},
      {'id': 10, 'name': 'Unlimited Lite', 'price': 'TZS 40,000', 'dataSize': 'Unlimited', 'validity': '30 days'},
    ];
  }

  static Future<bool> deletePackage(int packageId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  static Future<bool> savePackage(Map<String, dynamic> package, {bool isEdit = false}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  // ==================== CUSTOMER ORDERS ====================
  static Future<List<Map<String, dynamic>>> getCustomerOrders() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      {
        'id': 1001,
        'customerName': 'John Mwita',
        'customerPhone': '0712345678',
        'packageId': 1,
        'packageName': 'Daily 500MB',
        'price': 1000,
        'paymentStatus': 'Paid',
        'paymentDate': '2025-05-20 10:30',
        'deliveryStatus': 'Pending',
        'rejectionReason': null,
        'deliveredAt': null,
      },
      {
        'id': 1002,
        'customerName': 'Asha Salim',
        'customerPhone': '0723456789',
        'packageId': 2,
        'packageName': 'Weekly 3GB',
        'price': 5000,
        'paymentStatus': 'Paid',
        'paymentDate': '2025-05-19 15:45',
        'deliveryStatus': 'Delivered',
        'rejectionReason': null,
        'deliveredAt': '2025-05-19 16:20',
      },
      {
        'id': 1004,
        'customerName': 'Mwajuma Hassan',
        'customerPhone': '0745678901',
        'packageId': 3,
        'packageName': 'Monthly 10GB',
        'price': 15000,
        'paymentStatus': 'Paid',
        'paymentDate': '2025-05-21 08:15',
        'deliveryStatus': 'Pending',
        'rejectionReason': null,
        'deliveredAt': null,
      },
    ];
  }

  static Future<bool> updateDeliveryStatus(int orderId, String newStatus, {String? rejectionReason}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  // ==================== STATEMENTS ====================
  static Future<List<Map<String, dynamic>>> getStatements() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      {'id': 1, 'type': 'Credit', 'amount': 5000, 'description': 'Sale of Weekly 3GB to John', 'date': '2025-05-10 14:30', 'balance_after': 12500},
      {'id': 2, 'type': 'Debit', 'amount': 2000, 'description': 'Purchase of Daily 1GB from Admin', 'date': '2025-05-11 09:15', 'balance_after': 10500},
      {'id': 3, 'type': 'Credit', 'amount': 10000, 'description': 'Sale of Monthly 10GB to Asha', 'date': '2025-05-12 18:45', 'balance_after': 20500},
      {'id': 4, 'type': 'Credit', 'amount': 1500, 'description': 'Commission from referral', 'date': '2025-05-13 11:00', 'balance_after': 22000},
      {'id': 5, 'type': 'Debit', 'amount': 5000, 'description': 'Withdrawal to M-Pesa', 'date': '2025-05-14 08:20', 'balance_after': 17000},
    ];
  }

  // ==================== WALLET METHODS ====================
  static Future<Map<String, dynamic>> depositFunds(double amount, String method) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final newBalance = 100000 + amount;
    return {
      'success': true,
      'message': 'Deposit of TZS ${amount.toStringAsFixed(0)} successful via $method',
      'newBalance': newBalance,
    };
  }

  static Future<Map<String, dynamic>> withdrawFunds(double amount, String phoneNumber, String network) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final currentBalance = 100000;
    if (amount > currentBalance) {
      return {
        'success': false,
        'message': 'Insufficient balance. Your current balance is TZS ${currentBalance.toStringAsFixed(0)}',
      };
    }
    return {
      'success': true,
      'message': 'Withdrawal request of TZS ${amount.toStringAsFixed(0)} sent to $network $phoneNumber. Funds will be sent within 24 hours.',
      'newBalance': currentBalance - amount,
    };
  }

  // ==================== SUBSCRIPTION METHODS ====================
  static Future<Map<String, dynamic>> getSubscriptionStatus() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'isActive': true,
      'expiryDate': '2025-06-22',
      'lastPaymentDate': '2025-05-22',
      'nextPaymentDue': '2025-06-22',
      'amount': 5000,
    };
  }

  static Future<Map<String, dynamic>> paySubscription() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return {
      'success': true,
      'message': 'Subscription renewed successfully for another month.',
      'newExpiryDate': '2025-07-22',
    };
  }
}