import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/bus.dart';

/// Service to handle all HTTP requests to our backend API.
/// This is a utility class with only static methods — no instance needed.
class ApiService {

  /// Fetches the current list of all 4 buses from GET /api/buses.
  /// Called once on app startup, then SSE handles live updates.
  static Future<List<Bus>> fetchBuses() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/buses'),
      );
      if (response.statusCode == 200) {
        // The response is a JSON array of bus objects
        List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((j) => Bus.fromJson(j)).toList();
      } else {
        throw Exception('Failed to load buses: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching buses: $e');
      return []; // Return empty list so the app doesn't crash
    }
  }

  /// Verifies a driver token with POST /api/driver/verify.
  /// Returns { valid: true, busId: 1, busName: "Bus 1" } if the token
  /// matches a bus, or { valid: false } if not.
  static Future<Map<String, dynamic>?> verifyToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/driver/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Only return the data if the token was actually valid
        if (data['valid'] == true) {
          return data;
        }
      }
    } catch (e) {
      print('Error verifying token: $e');
    }
    return null;
  }

  /// Sends a GPS location update to POST /api/bus/:id/location.
  /// Called every 7 seconds by the driver provider while a trip is active.
  /// The token is sent in the JSON body (not a header) — that's how the
  /// backend authenticates this request.
  static Future<bool> updateLocation({
    required int busId,
    required String token,
    required double lat,
    required double lng,
    double? heading,
  }) async {
    try {
      final body = {
        'token': token, // Auth via body, not header
        'lat': lat,
        'lng': lng,
      };
      if (heading != null) {
        body['heading'] = heading;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/bus/$busId/location'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating location: $e');
      return false;
    }
  }

  /// Toggles a bus active/inactive via POST /api/bus/:id/toggle.
  /// Called when the driver taps Start Trip (active: true) or End Trip (active: false).
  static Future<bool> toggleBus({
    required int busId,
    required String token,
    required bool active,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/bus/$busId/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': token, // Auth via body, not header
          'active': active,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error toggling bus: $e');
      return false;
    }
  }
}
