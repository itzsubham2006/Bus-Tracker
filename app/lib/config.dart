import 'package:flutter/foundation.dart';

/// Single source of truth for the backend URL.
/// Automatically detects whether the app is running in Web/Desktop (localhost)
/// or Android emulator (10.0.2.2).
class AppConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    // Android emulator -> host machine localhost
    return 'http://10.0.2.2:3000';
    
    // For physical device testing, use your computer's local IP:
    // return 'http://192.168.x.x:3000';
    
    // For production:
    // return 'https://your-server.railway.app';
  }
}
