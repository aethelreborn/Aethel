import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

import 'api_client.dart';

/// Singleton manager for the WebSocket connection used for real-time
/// multi-device sync.
///
/// Connects to the backend gateway with the current access token passed as
/// a query parameter (`?token=<JWT>`). Automatically reconnects on disconnect
/// using exponential back-off capped at 30 s between attempts. An application-
/// level heartbeat (ping/pong every 30 s) keeps idle connections alive.
///
/// Events emitted by the gateway are forwarded to the callbacks registered
/// below. Call [connect] once authentication succeeds; call [disconnect]
/// (or [dispose]) when the user logs out.
class WebSocketClient {
  static const String kWsUrl = String.fromEnvironment(
    'AETHEL_WS_URL',
    defaultValue: 'ws://localhost:3001',
  );

  /// Single shared instance — intended to be used as a global singleton.
  static final WebSocketClient instance = WebSocketClient._internal();

  // ── Public callbacks ───────────────────────────────────────────────────────

  /// Fired once the channel moves into the open state.
  VoidCallback? onConnected;

  /// Fired on any vault-related event: `vault.created`, `vault.updated`,
  /// `vault.deleted`. [event] is the raw event string; [data] is the opaque
  /// payload sent by the gateway.
  void Function(String event, dynamic data)? onVaultItemChanged;

  /// Fired on billing-related events (e.g. `billing.marked_paid`).
  void Function(String event, dynamic data)? onBillingItemUpdated;

  // ── Internal state ─────────────────────────────────────────────────────────

  bool get isConnected => _connected;

  IOWebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _retryCount = 0;
  bool _connected = false;
  bool _disposed = false;

  WebSocketClient._internal();

  // ── Connection lifecycle ───────────────────────────────────────────────────

  /// Open a WebSocket connection using the current access token. If no token
  /// is available (unauthenticated) or the client is already connected, this
  /// is a no-op.
  void connect() {
    if (_connected || _disposed) return;

    final token = ApiClient.accessToken;
    if (token == null) return;

    final baseUrl = Uri.parse(kWsUrl);
    final wsUri = Uri(
      scheme: baseUrl.scheme,
      host: baseUrl.host,
      port: baseUrl.port,
      path: '/ws',
      queryParameters: {'token': token},
    );

    try {
      _channel = IOWebSocketChannel.connect(wsUri.toString());
      _channel!.stream.listen(
        _handleMessage,
        onDone: _onDisconnect,
        onError: _onError,
      );
      _startHeartbeat();
    } catch (e) {
      debugPrint('[WS] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _connected = false;
    _retryCount = 0;
  }

  void dispose() {
    _disposed = true;
    disconnect();
  }

  // ── Message handling ───────────────────────────────────────────────────────

  void _handleMessage(dynamic message) {
    if (message is! String) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(message) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[WS] Invalid JSON: $e');
      return;
    }

    final event = data['event'] as String?;
    final eventData = data['data'];
    if (event == null) return;

    switch (event) {
      case 'pong':
        // Heartbeat acknowledgement — nothing to do.
        return;
      case 'vault.created':
      case 'vault.updated':
      case 'vault.deleted':
        _connected = true;
        onConnected?.call();
        onVaultItemChanged?.call(event, eventData);
        break;
      case 'billing.marked_paid':
        _connected = true;
        onConnected?.call();
        onBillingItemUpdated?.call(event, eventData);
        break;
      default:
        debugPrint('[WS] Unknown event: $event');
    }
  }

  void _onDisconnect() {
    _connected = false;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _scheduleReconnect();
  }

  void _onError(dynamic error) {
    debugPrint('[WS] Error: $error');
    _onDisconnect();
  }

  // ── Reconnection with exponential back-off ─────────────────────────────────

  void _scheduleReconnect() {
    if (_disposed || _connected) return;
    final delaySeconds = _retryCount < 5 ? (1 << _retryCount) : 30;
    _retryCount++;
    debugPrint('[WS] Reconnecting in ${delaySeconds}s (attempt $_retryCount)');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), connect);
  }

  // ── Heartbeat ──────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connected) {
        _channel?.sink.add(jsonEncode({'event': 'ping'}));
      }
    });
  }
}
