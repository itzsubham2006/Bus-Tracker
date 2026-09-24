import 'package:flutter/material.dart';
import '../models/bus.dart';
import '../services/api_service.dart';
import '../services/sse_service.dart';

/// Provider for managing the global state of the buses (used by the map and list).
class BusProvider extends ChangeNotifier {
  List<Bus> _buses = [];
  List<Bus> get buses => _buses;

  late SSEService _sseService;
  
  // Expose the connection status so UI can show a "Reconnecting..." badge if needed
  ValueNotifier<SSEStatus> get sseStatus => _sseService.connectionStatus;

  BusProvider() {
    _sseService = SSEService();
    _init();
  }

  void _init() async {
    // 1. Fetch initial state via standard REST API
    _buses = await ApiService.fetchBuses();
    notifyListeners();

    // 2. Connect to SSE for real-time updates
    _sseService.connect();
    _sseService.updateStream.listen((event) {
      if (event['type'] == 'buses') {
        // Replace the whole list
        _buses = event['data'];
        notifyListeners();
      } else if (event['type'] == 'update') {
        // Update a specific bus
        Bus updatedBus = event['data'];
        int index = _buses.indexWhere((b) => b.id == updatedBus.id);
        if (index != -1) {
          _buses[index] = updatedBus;
        } else {
          _buses.add(updatedBus);
        }
        notifyListeners();
      }
    });

    // Also notify UI when the SSE connection status changes
    _sseService.connectionStatus.addListener(() {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sseService.dispose();
    super.dispose();
  }
}
