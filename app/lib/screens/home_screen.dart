import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bus_provider.dart';
import '../services/sse_service.dart';
import '../widgets/bus_map.dart';
import '../widgets/bus_list_panel.dart';
import 'driver_login_screen.dart';
import 'driver_screen.dart';
import '../providers/driver_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine the SSE connection status to show a banner if disconnected
    final sseStatus = context.select<BusProvider, SSEStatus>((provider) => provider.sseStatus.value);
    final isDriverLoggedIn = context.select<DriverProvider, bool>((provider) => provider.isLoggedIn);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          // Secret long-press to open driver mode!
          onLongPress: () {
            if (isDriverLoggedIn) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverScreen()));
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverLoginScreen()));
            }
          },
          child: const Text('College Bus Tracker'),
        ),
        leading: const Icon(Icons.directions_bus),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Stack(
        children: [
          // 1. The full-screen map
          const BusMap(),

          // 2. The connection status banner (shown only when disconnected/connecting)
          if (sseStatus != SSEStatus.connected)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Center(
                  child: Text(
                    sseStatus == SSEStatus.connecting ? 'Connecting...' : 'Disconnected. Reconnecting...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

          // 3. The bottom panel showing list of buses
          const BusListPanel(),
        ],
      ),
    );
  }
}
