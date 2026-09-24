import 'package:flutter/material.dart';
import '../models/bus.dart';

/// A custom widget representing a single bus marker on the map.
class BusMarkerWidget extends StatelessWidget {
  final Bus bus;

  const BusMarkerWidget({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    // Determine color based on staleness
    final color = bus.stale ? Colors.orange : Colors.green;

    return GestureDetector(
      onTap: () {
        // Show a little tooltip when tapped
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${bus.name} - ${bus.statusText}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color),
            ),
            child: Text(
              bus.name,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          Icon(
            Icons.location_on,
            color: color,
            size: 32,
          ),
        ],
      ),
    );
  }
}
