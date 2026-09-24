import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

/// Provider for managing everything about driver mode:
/// - Token authentication (login/logout)
/// - Trip state (active/inactive)
/// - Location broadcasting (periodic GPS → backend)
///
/// This provider is created once and lives for the app's lifetime.
/// On creation, it checks if a saved token exists from a previous session
/// so the driver doesn't have to re-enter their token every time.
class DriverProvider extends ChangeNotifier {
  // flutter_secure_storage encrypts the token on-device (Android Keystore / iOS Keychain)
  // Much safer than SharedPreferences for credentials
  final _storage = const FlutterSecureStorage();

  // --- State ---
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  String? _token;
  int? _busId;
  String? _busName;

  int? get busId => _busId;
  String? get busName => _busName;

  bool _isTripActive = false;
  bool get isTripActive => _isTripActive;

  // The timer that fires every 7 seconds to send GPS coordinates
  Timer? _locationTimer;

  // Track the last sent position for display purposes
  double? _lastLat;
  double? _lastLng;
  double? get lastLat => _lastLat;
  double? get lastLng => _lastLng;

  DriverProvider() {
    // On app start, check if there's a saved token from a previous session
    loadSavedToken();
  }

  /// Checks if a valid token is stored on the device from a previous session.
  /// If it is, verifies it's still valid with the backend (in case it was regenerated).
  Future<void> loadSavedToken() async {
    try {
      final token = await _storage.read(key: 'driver_token');
      if (token != null && token.isNotEmpty) {
        // Verify the token is still valid (admin might have regenerated it)
        final data = await ApiService.verifyToken(token);
        if (data != null && data['valid'] == true) {
          _isLoggedIn = true;
          _token = token;
          _busId = data['busId'] as int;
          _busName = data['busName'] as String;
          notifyListeners();
        } else {
          // Token is no longer valid — clear it
          await _storage.delete(key: 'driver_token');
        }
      }
    } catch (e) {
      print('Error loading saved token: $e');
    }
  }

  /// Attempts to log in with a token entered by the driver.
  /// Returns true if the token is valid, false otherwise.
  Future<bool> login(String token) async {
    final data = await ApiService.verifyToken(token);
    if (data != null && data['valid'] == true) {
      _isLoggedIn = true;
      _token = token;
      _busId = data['busId'] as int;
      _busName = data['busName'] as String;

      // Save the token securely so the driver doesn't need to enter it again
      await _storage.write(key: 'driver_token', value: token);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Logs the driver out: stops any active trip, clears stored token.
  /// This is intentionally buried in the UI — drivers shouldn't need to do this often.
  Future<void> logout() async {
    await endTrip(); // Stop sending location if trip is active
    _isLoggedIn = false;
    _token = null;
    _busId = null;
    _busName = null;
    _lastLat = null;
    _lastLng = null;
    await _storage.delete(key: 'driver_token');
    notifyListeners();
  }

  /// Starts the trip: requests location permission, tells the backend this bus is active,
  /// and begins sending GPS coordinates every 7 seconds.
  ///
  /// Returns false if:
  /// - Location permission was denied
  /// - Location services are disabled
  /// - Backend rejected the toggle request
  Future<bool> startTrip() async {
    if (_busId == null || _token == null) return false;

    // --- Step 1: Check if GPS/Location Services are even enabled on the phone ---
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled');
      return false;
    }

    // --- Step 2: Check and request location permission ---
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // First time asking — show the system permission dialog
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permission denied by user');
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      // User permanently denied — they need to go to Settings to fix this
      print('Location permission permanently denied — open app settings');
      return false;
    }

    // --- Step 3: Tell the backend this bus is now active ---
    final success = await ApiService.toggleBus(
      busId: _busId!,
      token: _token!,
      active: true,
    );

    if (success) {
      _isTripActive = true;

      // Send location immediately (don't wait 7 seconds for the first one)
      _sendLocation();

      // Then send every 7 seconds while the trip is active
      _locationTimer = Timer.periodic(
        const Duration(seconds: 7),
        (_) => _sendLocation(),
      );

      notifyListeners();
    }
    return success;
  }

  /// Ends the trip: stops sending GPS, tells the backend this bus is inactive.
  Future<void> endTrip() async {
    if (!_isTripActive) return;

    // Stop the location timer first
    _locationTimer?.cancel();
    _locationTimer = null;

    // Tell the backend to mark this bus as inactive
    // (this clears the bus's location so students don't see a stale pin)
    if (_busId != null && _token != null) {
      await ApiService.toggleBus(
        busId: _busId!,
        token: _token!,
        active: false,
      );
    }

    _isTripActive = false;
    notifyListeners();
  }

  /// Gets current GPS position and POSTs it to the backend.
  /// Called every 7 seconds by the periodic timer during an active trip.
  Future<void> _sendLocation() async {
    if (_busId == null || _token == null) return;

    try {
      // Get current GPS position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Send to backend
      await ApiService.updateLocation(
        busId: _busId!,
        token: _token!,
        lat: position.latitude,
        lng: position.longitude,
        heading: position.heading,
      );

      // Store for display in the driver UI
      _lastLat = position.latitude;
      _lastLng = position.longitude;
      notifyListeners();
    } catch (e) {
      print('Failed to get/send location: $e');
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }
}
