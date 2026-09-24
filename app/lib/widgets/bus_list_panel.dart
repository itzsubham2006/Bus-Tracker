import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bus_provider.dart';
import '../models/bus.dart';

/// A draggable bottom sheet that shows all 4 buses and their current status.
/// Students can drag it up to see more detail, or tap a bus to zoom the map to it.
class BusListPanel extends StatelessWidget {
  const BusListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // DraggableScrollableSheet creates a panel that the user can drag up/down
    return DraggableScrollableSheet(
      initialChildSize: 0.25,  // Start showing ~25% of screen height
      minChildSize: 0.08,      // Can be collapsed to just the drag handle
      maxChildSize: 0.5,       // Can be expanded to half the screen
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10.0,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Consumer<BusProvider>(
            builder: (context, provider, child) {
              if (provider.buses.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Loading buses...'),
                  ),
                );
              }

              return ListView.builder(
                controller: scrollController,
                // +1 for the drag handle at the top
                itemCount: provider.buses.length + 1,
                itemBuilder: (context, index) {
                  // First item is the drag handle indicator
                  if (index == 0) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }
                  final bus = provider.buses[index - 1];
                  return _buildBusTile(bus);
                },
              );
            },
          ),
        );
      },
    );
  }

  /// Builds a single list tile for one bus showing its name, status badge, and last seen time.
  Widget _buildBusTile(Bus bus) {
    // Color-code by status: green = running, grey = stopped, orange = signal lost
    final Color statusColor;
    final IconData statusIcon;
    if (!bus.isActive) {
      statusColor = Colors.grey;
      statusIcon = Icons.directions_bus_outlined;
    } else if (bus.stale) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.directions_bus;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Icon(statusIcon, color: statusColor),
      ),
      title: Text(
        bus.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        bus.statusText,
        style: TextStyle(color: statusColor, fontSize: 13),
      ),
      trailing: bus.lastSeenText != null
          ? Text(
              bus.lastSeenText!,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
          : null,
    );
  }
}
