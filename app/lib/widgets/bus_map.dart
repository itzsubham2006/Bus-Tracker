import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/bus_provider.dart';
import 'bus_marker.dart';

class BusMap extends StatefulWidget {
  const BusMap({super.key});

  @override
  State<BusMap> createState() => _BusMapState();
}

class _BusMapState extends State<BusMap> {
  final MapController _mapController = MapController();

  // A default center (e.g., Bangalore center or your college coordinates)
  final LatLng _defaultCenter = const LatLng(12.9716, 77.5946);

  @override
  Widget build(BuildContext context) {
    // Listen to changes in the buses list
    final buses = context.watch<BusProvider>().buses;
    
    // Create markers only for active buses that have coordinates
    List<Marker> markers = buses
        .where((b) => b.isActive && b.lat != null && b.lng != null)
        .map((b) => Marker(
              point: LatLng(b.lat!, b.lng!),
              width: 80,
              height: 80,
              child: BusMarkerWidget(bus: b),
            ))
        .toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: 13.0,
      ),
      children: [
        // OpenStreetMap tile layer (Free, no API key needed)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.collegebus.tracker',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}
