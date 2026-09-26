import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
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

  // Initial center focused on Kokrajhar route corridor
  static const LatLng _kokrajharCenter = LatLng(26.4150, 90.2750);

  // Strict corridor bounds between Girls' College Kokrajhar (South) and CIT Kokrajhar / Simbargaon Rd (North)
  // Includes horizontal padding so zooming in at any stop along the corridor never bounces back
  static final LatLngBounds _kokrajharBounds = LatLngBounds(
    southwest: const LatLng(26.3880, 90.2450), // Girls' College Kokrajhar (26.3911, 90.2647)
    northeast: const LatLng(26.4900, 90.3250), // CIT Kokrajhar / Simbargaon Rd (26.4865, 90.3056)
  );

  // Track current camera position and rotation steps (each step = 45 degrees)
  CameraPosition _currentCameraPosition = const CameraPosition(
    target: _kokrajharCenter,
    zoom: 14.0,
  );
  int _rotationSteps = 0;

  // Cache of custom-painted marker icons (keyed by id + name + stale status)
  final Map<String, BitmapDescriptor> _markerIcons = {};
  final Set<String> _generatingKeys = {};

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
                bearing: _normalizedBearing,
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

  double get _normalizedBearing => ((_rotationSteps * 45.0) % 360 + 360) % 360;

  void _rotateLeft() {
    setState(() {
      _rotationSteps -= 1;
    });
    _applyNativeRotation();
  }

  void _resetNorth() {
    setState(() {
      _rotationSteps = 0;
    });
    _applyNativeRotation();
  }

  void _rotateRight() {
    setState(() {
      _rotationSteps += 1;
    });
    _applyNativeRotation();
  }

  void _applyNativeRotation() {
    if (!kIsWeb && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentCameraPosition.target,
            zoom: _currentCameraPosition.zoom,
            tilt: _currentCameraPosition.tilt,
            bearing: _normalizedBearing,
          ),
        ),
      );
    }
  }

  double _calculateScaleForRotation(double radians, double width, double height) {
    if (radians == 0 || width <= 0 || height <= 0) return 1.0;
    final double absCos = math.cos(radians).abs();
    final double absSin = math.sin(radians).abs();
    final double scaleX = (width * absCos + height * absSin) / width;
    final double scaleY = (width * absSin + height * absCos) / height;
    return math.max(scaleX, scaleY);
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.hybrid // Hybrid displays satellite photography with clear street names
          : MapType.normal;
    });
  }

  String _iconCacheKey(Bus bus) => '${bus.id}_${bus.displayName}_${bus.stale}';

  /// Ensures every bus in the list has its custom labeled car/bus icon generated and cached.
  void _ensureMarkerIcons(List<Bus> buses) {
    for (final bus in buses) {
      final key = _iconCacheKey(bus);
      if (!_markerIcons.containsKey(key) && !_generatingKeys.contains(key)) {
        _generatingKeys.add(key);
        _createCustomBusMarker(bus).then((descriptor) {
          if (mounted) {
            setState(() {
              _markerIcons[key] = descriptor;
              _generatingKeys.remove(key);
            });
          }
        });
      }
    }
  }

  /// Dynamically paints a high-DPI custom map marker for a bus containing:
  /// 1. A top pill badge with the bus's name ("Bus 1", "Bus 2", etc.)
  /// 2. A circular pin badge in the bus's unique color containing its unique car/vehicle icon
  /// 3. A bottom pointer tip anchored to the exact road coordinate
  Future<BitmapDescriptor> _createCustomBusMarker(Bus bus) async {
    const double width = 168;
    const double height = 152;
    const double centerX = width / 2;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Color primaryColor = bus.stale ? const Color(0xFFF57C00) : bus.themeColor;

    // --- 1. Draw Top Name Pill ("Bus 1", "Bus 2", etc.) ---
    final TextPainter labelPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: bus.displayName,
        style: const TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
    labelPainter.layout();

    final double pillWidth = labelPainter.width + 34;
    const double pillHeight = 40;
    final RRect pillRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(centerX, 24),
        width: pillWidth,
        height: pillHeight,
      ),
      const Radius.circular(20),
    );

    // Pill drop shadow
    canvas.drawRRect(
      pillRRect.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Pill background fill
    canvas.drawRRect(
      pillRRect,
      Paint()..color = primaryColor,
    );

    // Pill crisp white border
    canvas.drawRRect(
      pillRRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Paint bus name text ("Bus 1") centered inside the pill
    labelPainter.paint(
      canvas,
      Offset(centerX - labelPainter.width / 2, 24 - labelPainter.height / 2),
    );

    // --- 2. Draw Circular Vehicle Pin & Pointer Triangle ---
    const Offset circleCenter = Offset(centerX, 94);
    const double circleRadius = 33;

    final Path pinPath = Path()
      ..addOval(Rect.fromCircle(center: circleCenter, radius: circleRadius))
      ..moveTo(centerX - 14, circleCenter.dy + 26)
      ..lineTo(centerX, height - 6)
      ..lineTo(centerX + 14, circleCenter.dy + 26)
      ..close();

    // Pin drop shadow
    canvas.drawPath(
      pinPath.shift(const Offset(0, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // White outer border around pin + pointer
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.0
        ..strokeJoin = StrokeJoin.round,
    );

    // Colored fill for pin + pointer
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill,
    );

    // --- 3. Draw Distinct Car / Vehicle Icon Inside Circle ---
    final IconData iconData = bus.stale ? Icons.warning_amber_rounded : bus.vehicleIcon;
    final TextPainter iconPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: 36,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          color: Colors.white,
        ),
      ),
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        circleCenter.dx - iconPainter.width / 2,
        circleCenter.dy - iconPainter.height / 2,
      ),
    );

    // Convert canvas to PNG bytes and create BitmapDescriptor
    final ui.Image image = await pictureRecorder.endRecording().toImage(
          width.toInt(),
          height.toInt(),
        );
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(
      pngBytes,
      width: width / 2,   // 84 logical px
      height: height / 2, // 76 logical px
    );
  }

  Widget _buildRotationButton({
    required String label,
    required String tooltip,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isHighlighted
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in the buses list
    final buses = context.watch<BusProvider>().buses;

    // Ensure custom markers with bus name + car icon are generated for all buses
    _ensureMarkerIcons(buses);

    // Create markers only for active buses that have coordinates
    Set<Marker> markers = buses
        .where((b) => b.isActive && b.lat != null && b.lng != null)
        .map((b) {
          final customIcon = _markerIcons[_iconCacheKey(b)];
          return Marker(
            markerId: MarkerId(b.id.toString()),
            position: LatLng(b.lat!, b.lng!),
            anchor: const Offset(0.5, 0.96),
            icon: customIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                    b.stale ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueAzure),
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
          );
        })
        .toSet();

    final Widget googleMapWidget = GoogleMap(
      key: const ValueKey('kokrajhar_google_map'),
      initialCameraPosition: const CameraPosition(
        target: _kokrajharCenter,
        zoom: 14.0,
      ),
      mapType: _currentMapType,
      minMaxZoomPreference: const MinMaxZoomPreference(13.0, 20.0),
      cameraTargetBounds: CameraTargetBounds(_kokrajharBounds),
      rotateGesturesEnabled: true,
      compassEnabled: true,
      markers: markers,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      onCameraMove: (position) {
        _currentCameraPosition = position;
      },
      onMapCreated: (controller) {
        _mapController = controller;
      },
    );

    final double targetAngleRadians = kIsWeb ? (_rotationSteps * 45.0) * (math.pi / 180.0) : 0.0;

    return Stack(
      children: [
        // Map viewport (supports smooth rotation on both Web and Android)
        if (kIsWeb)
          LayoutBuilder(
            builder: (context, constraints) {
              return ClipRect(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: targetAngleRadians),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (context, angle, child) {
                    final double scale = _calculateScaleForRotation(
                      angle,
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..scaleByDouble(scale, scale, 1.0, 1.0)
                        ..rotateZ(angle),
                      child: child,
                    );
                  },
                  child: googleMapWidget,
                ),
              );
            },
          )
        else
          googleMapWidget,

        // Floating Map Rotation Controls (< ^ >) and Satellite Toggle (top right)
        Positioned(
          top: 16,
          right: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rotation control pill: [ < | ^ | > ]
              Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(24),
                color: Colors.white,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _rotationSteps != 0
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRotationButton(
                        label: '<',
                        tooltip: 'Rotate Left (-45°)',
                        onTap: _rotateLeft,
                      ),
                      Container(
                        width: 1,
                        height: 22,
                        color: Colors.grey.shade300,
                      ),
                      _buildRotationButton(
                        label: '^',
                        tooltip: 'Reset North (0°)',
                        onTap: _resetNorth,
                        isHighlighted: _rotationSteps != 0,
                      ),
                      Container(
                        width: 1,
                        height: 22,
                        color: Colors.grey.shade300,
                      ),
                      _buildRotationButton(
                        label: '>',
                        tooltip: 'Rotate Right (+45°)',
                        onTap: _rotateRight,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Satellite / Default Map Toggle Button
              Material(
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
            ],
          ),
        ),
      ],
    );
  }
}
