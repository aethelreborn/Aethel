import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aethel/core/network/websocket_client.dart';
import 'package:aethel/features/dashboard/providers/timeline_provider.dart';

/// Riverpod provider that owns the WebSocket sync lifecycle.
///
/// State is [AsyncValue.loading] while the connection is being established,
/// [AsyncValue.data(null)] once the gateway confirms a connection, and
/// [AsyncValue.error] on unrecoverable failures.
///
/// On every incoming event the relevant downstream providers
/// ([vaultProvider], [billingProvider], [timelineProvider]) are invalidated
/// so that the UI re-fetches fresh data from the HTTP API.
final syncProvider = StateNotifierProvider<SyncNotifier, AsyncValue<void>>(
  (ref) => SyncNotifier(ref),
);

class SyncNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final WebSocketClient _ws = WebSocketClient.instance;

  SyncNotifier(this._ref) : super(const AsyncLoading()) {
    _ws.onConnected = () {
      state = const AsyncValue.data(null);
      // Kick off a refresh of everything so the UI reflects the latest
      // server state as soon as the connection is confirmed.
      _ref.invalidate(timelineProvider);
      _ref.invalidate(vaultProvider);
      _ref.invalidate(billingProvider);
    };

    _ws.onVaultItemChanged = (_, __) {
      _ref.invalidate(vaultProvider);
      _ref.invalidate(timelineProvider);
    };

    _ws.onBillingItemUpdated = (_, __) {
      _ref.invalidate(billingProvider);
      _ref.invalidate(timelineProvider);
    };
  }

  /// Call this after a successful login / registration to start syncing.
  /// The client will read the current access token from [ApiClient].
  void startIfAuthenticated() => _ws.connect();

  /// Gracefully close the WebSocket and cancel any pending reconnect.
  void stop() => _ws.disconnect();

  @override
  void dispose() {
    _ws.dispose();
    super.dispose();
  }
}
