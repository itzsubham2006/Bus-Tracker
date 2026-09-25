import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bus_provider.dart';
import '../models/bus.dart';

/// A draggable bottom sheet that shows all 4 buses and their current status.
/// Students can drag it up to see more detail, or tap the locate button on the left to zoom directly to the bus.
class BusListPanel extends StatelessWidget {
  const BusListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.25, // Start showing ~25% of screen height
      minChildSize: 0.08,     // Collapsible to just drag handle
      maxChildSize: 0.55,     // Expandable to half screen
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12.0,
                offset: const Offset(0, -3),
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

              return ListView.separated(
                controller: scrollController,
                itemCount: provider.buses.length + 1,
                separatorBuilder: (context, index) {
                  if (index == 0) return const SizedBox.shrink();
                  return Divider(height: 1, indent: 72, endIndent: 16, color: Colors.grey.shade200);
                },
                itemBuilder: (context, index) {
                  // First item is the drag handle indicator
                  if (index == 0) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        height: 5,
                        width: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }
                  final bus = provider.buses[index - 1];
                  return _buildBusTile(context, bus);
                },
              );
            },
          ),
        );
      },
    );
  }

  /// Builds a single list tile for one bus with a prominent zoom/locate button on the left.
  Widget _buildBusTile(BuildContext context, Bus bus) {
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

    void handleLocateBus() {
      if (bus.hasLocation) {
        context.read<BusProvider>().focusOnBus(bus);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zooming to ${bus.displayName}...'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${bus.displayName} is currently not running'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      // Prominent locate/zoom button on the left side of the bus
      leading: Tooltip(
        message: bus.hasLocation ? 'Zoom to ${bus.displayName}' : '${bus.displayName} not running',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: handleLocateBus,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(statusIcon, color: statusColor, size: 24),
                  if (bus.hasLocation)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.my_location,
                          color: statusColor,
                          size: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      // Clean display name: 'Bus 1', 'Bus 2', 'Bus 3', 'Bus 4' (no route suffixes)
      title: Text(
        bus.displayName,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
            ),
          ),
          Text(
            bus.statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing: bus.lastSeenText != null
          ? Text(
              bus.lastSeenText!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          : null,
      onTap: handleLocateBus,
    );
  }
}
