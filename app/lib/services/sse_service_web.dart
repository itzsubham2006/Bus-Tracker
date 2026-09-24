// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../models/bus.dart';
import 'sse_status.dart';

/// Web implementation of SSEService using native browser EventSource.
class SSEService {
  final ValueNotifier<SSEStatus> connectionStatus = ValueNotifier(SSEStatus.disconnected);
  final StreamController<dynamic> _updateStreamController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get updateStream => _updateStreamController.stream;

  html.EventSource? _eventSource;
  bool _isDisposed = false;

  void connect() {
    if (_isDisposed) return;
    
    connectionStatus.value = SSEStatus.connecting;

    try {
      final url = '${AppConfig.baseUrl}/api/stream';
      _eventSource = html.EventSource(url);

      _eventSource!.onOpen.listen((_) {
        connectionStatus.value = SSEStatus.connected;
      });

      _eventSource!.onError.listen((_) {
        connectionStatus.value = SSEStatus.disconnected;
      });

      _eventSource!.addEventListener('buses', (html.Event event) {
        final messageEvent = event as html.MessageEvent;
        _handleEvent('buses', messageEvent.data.toString());
      });

      _eventSource!.addEventListener('update', (html.Event event) {
        final messageEvent = event as html.MessageEvent;
        _handleEvent('update', messageEvent.data.toString());
      });
    } catch (e) {
      debugPrint('Web SSE Exception: $e');
      connectionStatus.value = SSEStatus.disconnected;
    }
  }

  void _handleEvent(String eventType, String dataStr) {
    try {
      final dynamic data = json.decode(dataStr);
      if (eventType == 'buses') {
        List<Bus> busList = (data as List).map((json) => Bus.fromJson(json)).toList();
        _updateStreamController.add({'type': 'buses', 'data': busList});
      } else if (eventType == 'update') {
        Bus bus = Bus.fromJson(data);
        _updateStreamController.add({'type': 'update', 'data': bus});
      }
    } catch (e) {
      debugPrint('Error parsing Web SSE data: $e');
    }
  }

  void disconnect() {
    _eventSource?.close();
    _eventSource = null;
    connectionStatus.value = SSEStatus.disconnected;
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _updateStreamController.close();
    connectionStatus.dispose();
  }
}
