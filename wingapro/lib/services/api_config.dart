import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kDebugMode) {
      // For physical device on same WiFi – replace with your PC's IP
      return 'http://192.168.1.18:5000';
      // For Android emulator: 'http://10.0.2.2:5000'
    } else {
      // Production URL (after deployment)
      return 'https://your-api.onrender.com';
    }
  }

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
  };
}