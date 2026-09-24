import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../models/bus.dart';

/// Represents the connection status of our SSE client.
enum SSEStatus { disconnected, connecting, connected }

/// Service to handle Server-Sent Events (SSE) from the backend.
/// This allows us to receive real-time bus updates without constantly polling.
class SSEService {
  // Notifier to broadcast connection status to the UI (e.g., to show "Reconnecting...")
  final ValueNotifier<SSEStatus> connectionStatus = ValueNotifier(SSEStatus.disconnected);
  
  // Stream to emit parsed bus updates to whoever is listening (usually the BusProvider)
  final StreamController<dynamic> _updateStreamController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get updateStream => _updateStreamController.stream;

  HttpClient? _client;
  HttpClientResponse? _response;
  StreamSubscription<String>? _subscription;
  
  bool _isDisposed = false;
  int _retryDelay = 1; // Start with 1 second delay for exponential backoff

  /// Connects to the SSE stream endpoint.
  void connect() async {
    if (_isDisposed) return;
    
    connectionStatus.value = SSEStatus.connecting;
    
    try {
      _client = HttpClient();
      // Important: Allow self-signed certs or standard issues on local dev
      _client!.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      
      final request = await _client!.getUrl(Uri.parse('${AppConfig.baseUrl}/api/stream'));
      // Request SSE content type
      request.headers.add('Accept', 'text/event-stream');
      request.headers.add('Cache-Control', 'no-cache');
      
      _response = await request.close();
      
      if (_response!.statusCode == 200) {
        connectionStatus.value = SSEStatus.connected;
        _retryDelay = 1; // Reset retry delay on successful connection
        
        String eventType = 'message';
        
        // Listen to the stream of lines
        _subscription = _response!
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          
          // Ignore SSE comments (heartbeats usually start with a colon)
          if (line.startsWith(':')) return;
          
          if (line.isEmpty) {
            // An empty line means the current event is complete.
            // (We parse data right away on the 'data:' line for simplicity in this implementation)
            eventType = 'message'; // Reset
          } else if (line.startsWith('event:')) {
            eventType = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            final dataStr = line.substring(5).trim();
            if (dataStr.isNotEmpty) {
              _handleEvent(eventType, dataStr);
            }
          }
        }, onError: (error) {
          print('SSE Stream Error: $error');
          _reconnect();
        }, onDone: () {
          print('SSE Stream Closed');
          _reconnect();
        });
      } else {
        print('SSE Connection Failed: ${_response!.statusCode}');
        _reconnect();
      }
    } catch (e) {
      print('SSE Connection Exception: $e');
      _reconnect();
    }
  }

  /// Parses the SSE event and sends it into our Dart stream.
  void _handleEvent(String eventType, String dataStr) {
    try {
      final dynamic data = json.decode(dataStr);
      
      if (eventType == 'buses') {
        // Initial full list of buses
        List<Bus> busList = (data as List).map((json) => Bus.fromJson(json)).toList();
        _updateStreamController.add({'type': 'buses', 'data': busList});
      } else if (eventType == 'update') {
        // Single bus update
        Bus bus = Bus.fromJson(data);
        _updateStreamController.add({'type': 'update', 'data': bus});
      }
    } catch (e) {
      print('Error parsing SSE data: $e');
    }
  }

  /// Implements exponential backoff for reconnecting.
  void _reconnect() {
    if (_isDisposed) return;
    
    disconnect();
    connectionStatus.value = SSEStatus.disconnected;
    
    print('Reconnecting to SSE in $_retryDelay seconds...');
    Future.delayed(Duration(seconds: _retryDelay), () {
      connect();
    });
    
    // Increase the delay for the next failure (up to 30 seconds max)
    _retryDelay = (_retryDelay * 2).clamp(1, 30);
  }

  /// Disconnects from the stream.
  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close(force: true);
    _client = null;
    connectionStatus.value = SSEStatus.disconnected;
  }

  /// Cleans up resources.
  void dispose() {
    _isDisposed = true;
    disconnect();
    _updateStreamController.close();
    connectionStatus.dispose();
  }
}
