import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/register'),
      headers: ApiConfig.headers,
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/login'),
      headers: ApiConfig.headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (data['success'] == true && data['token'] != null) {
      await storage.write(key: 'jwt_token', value: data['token']);
    }
    return data;
  }

  Future<String?> getToken() async {
    return await storage.read(key: 'jwt_token');
  }

  Future<void> logout() async {
    await storage.delete(key: 'jwt_token');
  }
}