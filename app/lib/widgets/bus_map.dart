import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/bus_provider.dart';
import '../models/bus.dart';

class BusMap extends StatefulWidget {
  const BusMap({super.key});

  @override
  State<BusMap> createState() => _BusMapState();
}

class _BusMapState extends State<BusMap> {
  GoogleMapController? _mapController;
  StreamSubscription<Bus>? _focusSubscription;

  // Current map type: defaults to normal, toggles to hybrid/satellite
  MapType _currentMapType = MapType.normal;

  // Center coordinate between Girls College Kokrajhar and Simbargaon Rd
  final LatLng _kokrajharCenter = const LatLng(26.4385, 90.2845);

  // Region bounds strictly between Girls College Kokrajhar (SW) and Simbargaon Rd (NE)
  final LatLngBounds _kokrajharBounds = LatLngBounds(
    southwest: const LatLng(26.3895, 90.2630),
    northeast: const LatLng(26.486532010995568, 90.30555318584854),
  );

  // Track if initial camera auto-fit has completed on app startup
  bool _initialFitDone = false;

  @override
  void initState() {
    super.initState();
    // Listen to focus requests from BusListPanel to zoom into a specific bus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusSubscription = context.read<BusProvider>().focusBusStream.listen((bus) {
        if (_mapController != null && bus.hasLocation) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(bus.lat!, bus.lng!),
                zoom: 16.5,
              ),
            ),
          );
          _mapController!.showMarkerInfoWindow(MarkerId(bus.id.toString()));
        }
      });
    });
  }

  @override
  void dispose() {
    _focusSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.hybrid // Hybrid displays satellite photography with clear street names
          : MapType.normal;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in the buses list
    final buses = context.watch<BusProvider>().buses;

    // Create markers only for active buses that have coordinates
    Set<Marker> markers = buses
        .where((b) => b.isActive && b.lat != null && b.lng != null)
        .map((b) => Marker(
              markerId: MarkerId(b.id.toString()),
              position: LatLng(b.lat!, b.lng!),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  b.stale ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(
                title: b.displayName,
                snippet: b.statusText,
              ),
              onTap: () {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${b.displayName} - ${b.statusText}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ))
        .toSet();

    return Stack(
      children: [
        GoogleMap(
          key: const ValueKey('kokrajhar_google_map'),
          initialCameraPosition: CameraPosition(
            target: _kokrajharCenter,
            zoom: 12.5,
          ),
          mapType: _currentMapType,
          minMaxZoomPreference: const MinMaxZoomPreference(10.0, 20.0),
          cameraTargetBounds: CameraTargetBounds.unbounded,
          markers: markers,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (controller) {
            _mapController = controller;
            // Auto-fit camera between Kokrajhar Police Station and Simbargaon Rd ONLY on initial launch
            if (!_initialFitDone) {
              _initialFitDone = true;
              Future.delayed(const Duration(milliseconds: 250), () {
                if (mounted) {
                  controller.animateCamera(
                    CameraUpdate.newLatLngBounds(_kokrajharBounds, 48),
                  );
                }
              });
            }
          },
        ),

        // Floating Satellite / Layer Toggle Button (top right)
        Positioned(
          top: 16,
          right: 16,
          child: Material(
            elevation: 4,
            shape: const CircleBorder(),
            color: Colors.white,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _toggleMapType,
              child: Tooltip(
                message: _currentMapType == MapType.normal
                    ? 'Switch to Satellite Mode'
                    : 'Switch to Default Map',
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _currentMapType != MapType.normal
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _currentMapType == MapType.normal
                        ? Icons.satellite_alt_outlined
                        : Icons.map_outlined,
                    color: _currentMapType != MapType.normal
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black87,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
