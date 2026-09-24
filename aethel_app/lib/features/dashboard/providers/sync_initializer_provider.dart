import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aethel/features/auth/providers/auth_provider.dart';
import 'package:aethel/features/dashboard/providers/sync_provider.dart';

/// Watches auth state and automatically starts the WebSocket sync client
/// once the user is authenticated, or stops it on logout.
final syncInitializerProvider = Provider((ref) {
  ref.watch(authStateProvider); // subscribe so we react to auth changes
  final syncNotifier = ref.read(syncProvider.notifier);

  ref.listen<AuthState>(authStateProvider, (_, next) {
    if (next.isAuthenticated) {
      syncNotifier.startIfAuthenticated();
    } else {
      syncNotifier.stop();
    }
  });
});
