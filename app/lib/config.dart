/// Single source of truth for the backend URL.
/// Change this when deploying to production.
class AppConfig {
  // Android emulator -> host localhost
  static const String baseUrl = 'http://10.0.2.2:3000';
  
  // For physical device testing, use your computer's local IP:
  // static const String baseUrl = 'http://192.168.x.x:3000';
  
  // For production:
  // static const String baseUrl = 'https://your-server.railway.app';
}
