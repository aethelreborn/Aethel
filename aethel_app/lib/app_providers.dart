import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/sync_service.dart';
import 'core/notifications/reminder_service.dart';
import 'core/storage/local_store.dart';
import 'core/storage/secure_store.dart';
import 'data/data_actions.dart';
import 'data/models.dart';
import 'features/auth/controllers/session_controller.dart';
import 'features/premium/premium_controller.dart';
import 'features/settings/controllers/settings_controller.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main.');
});

final secureStoreProvider = Provider<SecureStore>((ref) {
  return SecureStore(ref.watch(sharedPreferencesProvider));
});

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore.instance);

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController(ref.watch(sharedPreferencesProvider));
});

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(
    secure: ref.watch(secureStoreProvider),
    settings: ref.read(settingsControllerProvider.notifier),
  );
});

final syncRevisionProvider = ChangeNotifierProvider<ValueNotifier<int>>((ref) {
  return SyncService.instance.revision;
});

final syncStatusProvider =
    ChangeNotifierProvider<ValueNotifier<SyncStatus>>((ref) {
  return SyncService.instance.status;
});

final vaultItemsProvider = Provider<List<VaultItem>>((ref) {
  ref.watch(syncRevisionProvider);
  final items = List<VaultItem>.of(LocalStore.instance.snapshot.vault);
  items.sort((a, b) {
    if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
    return b.updatedAt.compareTo(a.updatedAt);
  });
  return List.unmodifiable(items);
});

final billItemsProvider = Provider<List<BillItem>>((ref) {
  ref.watch(syncRevisionProvider);
  final items = List<BillItem>.of(LocalStore.instance.snapshot.bills);
  items.sort((a, b) {
    if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
    final aDate = a.nextDueDate;
    final bDate = b.nextDueDate;
    if (aDate == null && bDate == null) {
      return b.updatedAt.compareTo(a.updatedAt);
    }
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return aDate.compareTo(bDate);
  });
  return List.unmodifiable(items);
});

final scheduleItemsProvider = Provider<List<FocusSchedule>>((ref) {
  ref.watch(syncRevisionProvider);
  final items = List<FocusSchedule>.of(LocalStore.instance.snapshot.schedules);
  items.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  return List.unmodifiable(items);
});

final focusSessionsProvider = Provider<List<FocusSession>>((ref) {
  ref.watch(syncRevisionProvider);
  final items = List<FocusSession>.of(LocalStore.instance.snapshot.sessions);
  items.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return List.unmodifiable(items);
});

final shellIndexProvider = StateProvider<int>((ref) => 0);

/// Defensive cap enforcement at the data layer. The screens also gate the
/// "add" taps so the upgrade sheet appears instead of an exception, but a
/// create can never slip past this even if a new call site forgets.
final dataActionsProvider = Provider<DataActions>((ref) {
  return DataActions(
    createGate: (kind, count) => canCreateWithState(
      ref.read(premiumControllerProvider),
      kind,
      count,
    ),
  );
});

/// Rebuilds the scheduled reminders whenever schedules or bills change, so
/// what the platform has queued always mirrors the vault.
final reminderSyncProvider = Provider<void>((ref) {
  final schedules = ref.watch(scheduleItemsProvider);
  final bills = ref.watch(billItemsProvider);
  unawaited(
    ReminderService.instance.sync(schedules: schedules, bills: bills),
  );
});
