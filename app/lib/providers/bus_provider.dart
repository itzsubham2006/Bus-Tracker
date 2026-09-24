import 'dart:async';
import 'package:flutter/material.dart';
import '../models/bus.dart';
import '../services/api_service.dart';
import '../services/sse_service.dart';

/// Provider for managing the global state of the buses (used by the map and list).
class BusProvider extends ChangeNotifier {
  List<Bus> _buses = [];
  List<Bus> get buses => _buses;

  late SSEService _sseService;
  Timer? _pollingTimer;
  
  // Expose the connection status so UI can show a "Reconnecting..." badge if needed
  ValueNotifier<SSEStatus> get sseStatus => _sseService.connectionStatus;

  BusProvider() {
    _sseService = SSEService();
    _init();
  }

  void _init() async {
    // 1. Fetch initial state via standard REST API
    await _refreshBuses();

    // 2. Connect to SSE for real-time updates
    _sseService.connect();
    _sseService.updateStream.listen((event) {
      if (event['type'] == 'buses') {
        _buses = event['data'];
        notifyListeners();
      } else if (event['type'] == 'update') {
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

    // 3. Fallback polling: If SSE drops or is disconnected, poll every 5s
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_sseService.connectionStatus.value != SSEStatus.connected) {
        await _refreshBuses();
      }
    });
  }

  Future<void> _refreshBuses() async {
    final fetched = await ApiService.fetchBuses();
    if (fetched.isNotEmpty) {
      _buses = fetched;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _sseService.dispose();
    super.dispose();
  }
}
