import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../models/bus.dart';
import 'sse_status.dart';

/// Native (Android/iOS/Desktop) implementation of SSEService using dart:io HttpClient.
class SSEService {
  final ValueNotifier<SSEStatus> connectionStatus = ValueNotifier(SSEStatus.disconnected);
  final StreamController<dynamic> _updateStreamController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get updateStream => _updateStreamController.stream;

  HttpClient? _client;
  HttpClientResponse? _response;
  StreamSubscription<String>? _subscription;
  
  bool _isDisposed = false;
  int _retryDelay = 1;

  void connect() async {
    if (_isDisposed) return;
    
    connectionStatus.value = SSEStatus.connecting;
    
    try {
      _client = HttpClient();
      _client!.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      
      final request = await _client!.getUrl(Uri.parse('${AppConfig.baseUrl}/api/stream'));
      request.headers.add('Accept', 'text/event-stream');
      request.headers.add('Cache-Control', 'no-cache');
      
      _response = await request.close();
      
      if (_response!.statusCode == 200) {
        connectionStatus.value = SSEStatus.connected;
        _retryDelay = 1;
        
        String eventType = 'message';
        
        _subscription = _response!
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          if (line.startsWith(':')) return;
          
          if (line.isEmpty) {
            eventType = 'message';
          } else if (line.startsWith('event:')) {
            eventType = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            final dataStr = line.substring(5).trim();
            if (dataStr.isNotEmpty) {
              _handleEvent(eventType, dataStr);
            }
          }
        }, onError: (error) {
          debugPrint('SSE Stream Error: $error');
          _reconnect();
        }, onDone: () {
          debugPrint('SSE Stream Closed');
          _reconnect();
        });
      } else {
        debugPrint('SSE Connection Failed: ${_response!.statusCode}');
        _reconnect();
      }
    } catch (e) {
      debugPrint('SSE Connection Exception: $e');
      _reconnect();
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
      debugPrint('Error parsing SSE data: $e');
    }
  }

  void _reconnect() {
    if (_isDisposed) return;
    
    disconnect();
    connectionStatus.value = SSEStatus.disconnected;
    
    Future.delayed(Duration(seconds: _retryDelay), () {
      if (!_isDisposed) connect();
    });
    
    _retryDelay = (_retryDelay * 2).clamp(1, 30);
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close(force: true);
    _client = null;
    connectionStatus.value = SSEStatus.disconnected;
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _updateStreamController.close();
    connectionStatus.dispose();
  }
}
