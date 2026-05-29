// lib/services/seller_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wingapro/services/api_config.dart';

class SellerApiService {
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not logged in');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // -------------------- Customer Orders (Paid) --------------------
  static Future<List<Map<String, dynamic>>> getCustomerOrders() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/seller/customer-orders'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['orders']);
      }
      throw Exception(data['message'] ?? 'Failed to load orders');
    } else if (response.statusCode == 401) {
      throw Exception('Not logged in');
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  static Future<bool> updateDeliveryStatus(int orderId, String newStatus, {String? rejectionReason}) async {
    final headers = await _authHeaders();
    final body = jsonEncode({
      'status': newStatus,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    });
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/seller/orders/$orderId/delivery-status'),
      headers: headers,
      body: body,
    );
    if (response.statusCode == 200) {
      return true;
    } else if (response.statusCode == 401) {
      throw Exception('Not logged in');
    } else {
      throw Exception('Failed to update status');
    }
  }

  // -------------------- Statements --------------------
  static Future<List<Map<String, dynamic>>> getStatements() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/seller/statements'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['statements']);
      }
      throw Exception(data['message'] ?? 'Failed to load statements');
    } else if (response.statusCode == 401) {
      throw Exception('Not logged in');
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  // -------------------- Subscription --------------------
  static Future<Map<String, dynamic>> getSubscriptionStatus() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/seller/subscription'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['subscription'];
      }
      throw Exception(data['message'] ?? 'Failed to load subscription');
    } else if (response.statusCode == 401) {
      throw Exception('Not logged in');
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> paySubscription() async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/seller/subscription/pay'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data;
      }
      throw Exception(data['message'] ?? 'Payment failed');
    } else if (response.statusCode == 401) {
      throw Exception('Not logged in');
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }
}