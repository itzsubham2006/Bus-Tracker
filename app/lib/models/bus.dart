import 'package:flutter/material.dart';

/// Represents a single bus and its current tracking status.
///
/// The backend sends JSON with snake_case keys (e.g., "is_active", "last_updated").
/// This model converts them to Dart-style camelCase properties.
class Bus {
  final int id;
  final String name;
  final bool isActive;
  final double? lat;
  final double? lng;
  final double? heading;
  final int? lastUpdated; // Unix timestamp in milliseconds from backend
  final bool stale;        // true if bus is active but hasn't sent updates in >45s

  Bus({
    required this.id,
    required this.name,
    required this.isActive,
    this.lat,
    this.lng,
    this.heading,
    this.lastUpdated,
    required this.stale,
  });

  /// Factory constructor to create a Bus from the JSON we get from the backend.
  ///
  /// Example JSON from backend:
  /// {
  ///   "id": 1,
  ///   "name": "Bus 1 (North Route)",
  ///   "is_active": true,      ← note: snake_case!
  ///   "lat": 12.9716,
  ///   "lng": 77.5946,
  ///   "heading": 180.5,
  ///   "last_updated": 1695551234567,
  ///   "stale": false
  /// }
  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['id'] as int,
      name: json['name'] as String,
      // Backend uses snake_case "is_active", not camelCase
      isActive: json['is_active'] ?? false,
      // Parse coordinates as double (backend might send int or double)
      lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
      heading: json['heading'] != null ? (json['heading'] as num).toDouble() : null,
      // Backend uses snake_case "last_updated"
      lastUpdated: json['last_updated'] as int?,
      stale: json['stale'] ?? false,
    );
  }

  /// Creates a copy of this Bus with some fields replaced.
  /// Used by the provider when updating a single bus in the list.
  Bus copyWith({
    int? id,
    String? name,
    bool? isActive,
    double? lat,
    double? lng,
    double? heading,
    int? lastUpdated,
    bool? stale,
  }) {
    return Bus(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      heading: heading ?? this.heading,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      stale: stale ?? this.stale,
    );
  }

  /// Human-readable status text for display in the UI.
  String get statusText {
    if (!isActive) return 'Not running';
    if (stale) return 'Signal lost';
    return 'Running';
  }

  /// How long ago this bus was last seen, as a human-readable string.
  /// Returns null if the bus has no last_updated timestamp.
  String? get lastSeenText {
    if (lastUpdated == null) return null;
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastUpdated!),
    );
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }

  /// Clean display name that removes any '(Route)' annotations so it renders as 'Bus 1', 'Bus 2', etc.
  String get displayName {
    return name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  }

  /// Distinct color assigned to each bus so students can identify them on the map.
  Color get themeColor {
    switch (id) {
      case 1:
        return const Color(0xFF1565C0); // Royal Blue for Bus 1
      case 2:
        return const Color(0xFF2E7D32); // Emerald Green for Bus 2
      case 3:
        return const Color(0xFF6A1B9A); // Deep Purple for Bus 3
      case 4:
        return const Color(0xFFD84315); // Crimson Orange for Bus 4
      default:
        return const Color(0xFF00838F); // Teal fallback
    }
  }

  /// Distinct vehicle/car/bus icon assigned to each bus.
  IconData get vehicleIcon {
    switch (id) {
      case 1:
        return Icons.directions_car_filled; // Car icon for Bus 1
      case 2:
        return Icons.airport_shuttle;       // Shuttle Van icon for Bus 2
      case 3:
        return Icons.local_taxi;            // Taxi/Sedan icon for Bus 3
      case 4:
        return Icons.directions_bus_filled; // Bus icon for Bus 4
      default:
        return Icons.directions_car;
    }
  }

  /// Whether this bus has valid coordinates to show on the map.
  bool get hasLocation => lat != null && lng != null;
}
