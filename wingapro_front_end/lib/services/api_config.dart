// lib/services/api_config.dart
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Set to true only when testing with a local backend on your computer
  static const bool useLocalNetwork = false;

  static String get baseUrl {
    if (useLocalNetwork && !kReleaseMode) {
      // For local development on a real device: use your computer's local IP
      // Run 'ipconfig' (Windows) or 'ifconfig' (Mac/Linux) to find your IP
      // Example: 'http://192.168.1.100:5000' - CHANGE THIS to your actual local IP
      return 'http://192.168.1.100:5000';
    } else {
      // Production Railway backend (HTTPS)
      return 'https://wingaprobackend-production-49cf.up.railway.app';
    }
  }

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
  };
}