import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/driver_provider.dart';

/// Driver control screen — only accessible via the hidden long-press gesture.
///
/// Shows which bus the driver is controlling and a big Start/End Trip button.
/// While a trip is active, displays current GPS coordinates and a status indicator.
class DriverScreen extends StatelessWidget {
  const DriverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Controls'),
        // Logout is intentionally NOT a prominent button — it's in a popup menu
        // since drivers should set this up once and leave it
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _confirmLogout(context, driver);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Log out of driver mode'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- Bus identity ---
              Text(
                'You are driving:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                driver.busName ?? 'Unknown Bus',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
              ),
              const SizedBox(height: 48),

              // --- Big circular Start/End Trip button ---
              GestureDetector(
                onTap: () async {
                  if (driver.isTripActive) {
                    await driver.endTrip();
                  } else {
                    final success = await driver.startTrip();
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not start trip. Please enable location services '
                            'and grant location permission.',
                          ),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: driver.isTripActive ? Colors.red : Colors.green,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      driver.isTripActive ? 'END\nTRIP' : 'START\nTRIP',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // --- Status info ---
              if (driver.isTripActive) ...[
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Sending location every 7 seconds...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Show last known coordinates if available
                if (driver.lastLat != null && driver.lastLng != null)
                  Text(
                    'Last sent: ${driver.lastLat!.toStringAsFixed(5)}, '
                    '${driver.lastLng!.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: 'monospace',
                    ),
                  ),
              ] else
                const Text(
                  'Tap the button to start your trip',
                  style: TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows a confirmation dialog before logging out of driver mode.
  void _confirmLogout(BuildContext context, DriverProvider driver) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out of driver mode?'),
        content: const Text(
          'You\'ll need to re-enter your bus token to use driver mode again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              driver.logout();
              Navigator.pop(context); // Go back to home
            },
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
