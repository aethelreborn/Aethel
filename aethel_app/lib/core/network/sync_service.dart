import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../data/models.dart';
import '../config/app_config.dart';
import '../crypto/crypto_service.dart';
import '../storage/local_store.dart';
import 'api_client.dart';

class SyncStatus {
  const SyncStatus({
    this.syncing = false,
    this.connected = false,
    this.lastSync,
    this.error,
  });

  final bool syncing;
  final bool connected;
  final DateTime? lastSync;
  final String? error;

  SyncStatus copyWith({
    bool? syncing,
    bool? connected,
    DateTime? lastSync,
    String? error,
    bool clearError = false,
  }) {
    return SyncStatus(
      syncing: syncing ?? this.syncing,
      connected: connected ?? this.connected,
      lastSync: lastSync ?? this.lastSync,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final ValueNotifier<SyncStatus> status = ValueNotifier<SyncStatus>(
    const SyncStatus(),
  );

  final ApiClient _api = ApiClient.instance;
  final LocalStore _local = LocalStore.instance;

  String? _token;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  Timer? _debounceTimer;
  bool _syncing = false;

  bool get isRunning => _token != null;

  void bump() {
    revision.value++;
  }

  void notifyLocalChange() {
    bump();
    unawaited(syncNow());
  }

  void start(String token) {
    if (token.isEmpty) return;
    _token = token;
    _connectSocket();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(syncNow()),
    );
    unawaited(syncNow());
  }

  void stop() {
    _token = null;
    _reconnectTimer?.cancel();
    _debounceTimer?.cancel();
    _pollTimer?.cancel();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _channel?.sink.close();
    _channel = null;
    status.value = status.value.copyWith(connected: false);
  }

  void onAuthLost() {
    stop();
    status.value = status.value.copyWith(
      error: 'Sync paused — unlock again to refresh the session.',
    );
  }

  Future<void> syncNow() async {
    if (_syncing || !_local.isOpen) return;
    if (_token == null || !_api.hasSession) {
      status.value = status.value.copyWith(
        error: 'Local only — sign in to sync across devices.',
      );
      return;
    }

    _syncing = true;
    status.value = status.value.copyWith(syncing: true);
    try {
      await _pushDeletions();
      await _pushPendingVault();
      await _pushPendingBills();
      await _pushPendingSchedules();
      await _pullAll();
      status.value = status.value.copyWith(
        syncing: false,
        lastSync: DateTime.now(),
        clearError: true,
      );
      bump();
      if (_hasPending) _scheduleSync();
    } on ApiException catch (error) {
      status.value = status.value.copyWith(
        syncing: false,
        error: error.message,
      );
    } catch (_) {
      status.value = status.value.copyWith(
        syncing: false,
        error: 'Sync could not finish. Your local changes are safe.',
      );
    } finally {
      _syncing = false;
    }
  }

  bool get _hasPending {
    final snapshot = _local.snapshot;
    return snapshot.deletedVaultIds.isNotEmpty ||
        snapshot.deletedBillIds.isNotEmpty ||
        snapshot.deletedScheduleIds.isNotEmpty ||
        snapshot.vault.any((item) => item.pending) ||
        snapshot.bills.any((item) => item.pending) ||
        snapshot.schedules.any((item) => item.pending);
  }

  Future<void> _pushDeletions() async {
    final snapshot = _local.snapshot;
    for (final id in List<String>.of(snapshot.deletedVaultIds)) {
      try {
        await _api.delete('/vault/$id');
      } on ApiException catch (error) {
        if (error.statusCode != 404) rethrow;
      }
      snapshot.deletedVaultIds.remove(id);
      await _local.save();
    }
    for (final id in List<String>.of(snapshot.deletedBillIds)) {
      try {
        await _api.delete('/billing/$id');
      } on ApiException catch (error) {
        if (error.statusCode != 404) rethrow;
      }
      snapshot.deletedBillIds.remove(id);
      await _local.save();
    }
    for (final id in List<String>.of(snapshot.deletedScheduleIds)) {
      try {
        await _api.delete('/schedules/$id');
      } on ApiException catch (error) {
        if (error.statusCode != 404) rethrow;
      }
      snapshot.deletedScheduleIds.remove(id);
      await _local.save();
    }
  }

  Future<void> _pushPendingVault() async {
    final key = _key;
    if (key == null) return;
    final snapshot = _local.snapshot;
    for (final item in List<VaultItem>.of(snapshot.vault)) {
      if (!item.pending) continue;
      final clean = item.copyWith(pending: false);
      final title = CryptoService.encryptString(clean.title, key);
      final payload = CryptoService.encryptJson(clean.toJson(), key);
      final body = <String, dynamic>{
        'id': clean.id,
        'title': title.ciphertext,
        'item_type': clean.type.apiValue,
        'encrypted_payload': payload.ciphertext,
        'iv': payload.iv,
      };
      try {
        await _api.post('/vault', data: body);
      } on ApiException catch (error) {
        if (error.statusCode == 409) {
          await _api.put('/vault/${clean.id}', data: body);
        } else {
          rethrow;
        }
      }
      _markVaultSynced(clean.id);
      await _local.save();
    }
  }

  Future<void> _pushPendingBills() async {
    final key = _key;
    if (key == null) return;
    final snapshot = _local.snapshot;
    for (final bill in List<BillItem>.of(snapshot.bills)) {
      if (!bill.pending) continue;
      final clean = bill.copyWith(pending: false);
      final title = CryptoService.encryptJson(
        {'title': clean.title, 'notes': clean.notes},
        key,
      );
      final body = <String, dynamic>{
        'id': clean.id,
        'title': title.ciphertext,
        'amount_due': clean.amount,
        'item_type': clean.type.apiValue,
        'next_due_date': clean.nextDueDate?.toUtc().toIso8601String(),
        'billing_cycle': clean.cycle?.apiValue,
        'is_active': clean.isActive,
        'paid_at': clean.lastPaidAt?.toUtc().toIso8601String(),
      };
      try {
        await _api.post('/billing', data: body);
      } on ApiException catch (error) {
        if (error.statusCode == 409) {
          await _api.put('/billing/${clean.id}', data: body);
        } else {
          rethrow;
        }
      }
      _markBillSynced(clean.id);
      await _local.save();
    }
  }

  Future<void> _pushPendingSchedules() async {
    final snapshot = _local.snapshot;
    for (final schedule in List<FocusSchedule>.of(snapshot.schedules)) {
      if (!schedule.pending) continue;
      final clean = schedule.copyWith(pending: false);
      final body = <String, dynamic>{
        'id': clean.id,
        'label': clean.label,
        'start_time': _timeOfDayIso(clean.startMinutes),
        'end_time': _timeOfDayIso(clean.endMinutes),
        'days_of_week': clean.apiDays,
        'blocked_apps': clean.blockedApps,
        'enabled': clean.enabled,
      };
      try {
        await _api.post('/schedules', data: body);
      } on ApiException catch (error) {
        if (error.statusCode == 409) {
          await _api.put('/schedules/${clean.id}', data: body);
        } else {
          rethrow;
        }
      }
      _markScheduleSynced(clean.id);
      await _local.save();
    }
  }

  Future<void> _pullAll() async {
    final key = _key;
    if (key == null) return;

    final vaultResponse = await _api.get('/vault');
    final remoteVault = _listFrom(vaultResponse, 'items');
    final localVault = {
      for (final item in _local.snapshot.vault) item.id: item,
    };
    final mergedVault = <VaultItem>[];
    for (final raw in remoteVault) {
      final id = _string(raw['id']);
      if (id.isEmpty) continue;
      final decryptedTitle =
          CryptoService.tryDecryptString(_string(raw['title']), key);
      final payload = CryptoService.tryDecryptString(
        _string(raw['encryptedPayload'] ?? raw['encrypted_payload']),
        key,
      );
      VaultItem? remote;
      if (payload != null) {
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            remote = VaultItem.fromJson(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          remote = null;
        }
      }
      remote ??= VaultItem(
        id: id,
        title: decryptedTitle ?? 'Locked item',
        type: VaultType.fromApi(_string(raw['itemType'] ?? raw['item_type'])),
        createdAt: _parseDate(raw['createdAt'] ?? raw['created_at']),
        updatedAt: _parseDate(raw['updatedAt'] ?? raw['updated_at']),
      );
      remote = remote.copyWith(
        id: id,
        title:
            decryptedTitle?.isNotEmpty == true ? decryptedTitle : remote.title,
        pending: false,
        createdAt: _parseDate(raw['createdAt'] ?? raw['created_at']),
        updatedAt: _parseDate(raw['updatedAt'] ?? raw['updated_at']),
      );
      final local = localVault.remove(id);
      if (local != null && local.pending) {
        mergedVault.add(local);
      } else {
        mergedVault.add(
          local == null ? remote : remote.copyWith(favorite: local.favorite),
        );
      }
    }
    mergedVault.addAll(localVault.values.where((item) => item.pending));

    final billingResponse = await _api.get('/billing');
    final remoteBills = _listFrom(billingResponse, 'items');
    final localBills = {
      for (final bill in _local.snapshot.bills) bill.id: bill,
    };
    final mergedBills = <BillItem>[];
    for (final raw in remoteBills) {
      final id = _string(raw['id']);
      if (id.isEmpty) continue;
      var title = 'Bill';
      var notes = '';
      final decrypted = CryptoService.tryDecryptString(
        _string(raw['title']),
        key,
      );
      if (decrypted != null) {
        try {
          final decoded = jsonDecode(decrypted);
          if (decoded is Map) {
            title = _string(decoded['title'] ?? title);
            notes = _string(decoded['notes'] ?? notes);
          } else {
            title = decrypted;
          }
        } catch (_) {
          title = decrypted;
        }
      }
      final remote = BillItem(
        id: id,
        title: title,
        amount: _double(raw['amountDue'] ?? raw['amount_due']),
        type: BillingType.fromApi(_string(raw['itemType'] ?? raw['item_type'])),
        cycle: BillingCycle.fromApi(
          _string(raw['billingCycle'] ?? raw['billing_cycle']),
        ),
        nextDueDate: _parseNullableDate(
          raw['nextDueDate'] ?? raw['next_due_date'],
        ),
        notes: notes,
        isActive: _bool(raw['isActive'] ?? raw['is_active'], fallback: true),
        lastPaidAt: _parseNullableDate(raw['paidAt'] ?? raw['paid_at']),
        createdAt: _parseDate(raw['createdAt'] ?? raw['created_at']),
        updatedAt: _parseDate(raw['updatedAt'] ?? raw['updated_at']),
      );
      final local = localBills.remove(id);
      if (local != null && local.pending) {
        mergedBills.add(local);
      } else {
        mergedBills.add(remote);
      }
    }
    mergedBills.addAll(localBills.values.where((bill) => bill.pending));

    final scheduleResponse = await _api.get('/schedules');
    final remoteSchedules = _listFrom(scheduleResponse, 'items');
    final localSchedules = {
      for (final schedule in _local.snapshot.schedules) schedule.id: schedule,
    };
    final mergedSchedules = <FocusSchedule>[];
    for (final raw in remoteSchedules) {
      final id = _string(raw['id']);
      if (id.isEmpty) continue;
      final start = _parseDate(raw['startTime'] ?? raw['start_time']);
      final end = _parseDate(raw['endTime'] ?? raw['end_time']);
      final daysRaw = raw['daysOfWeek'] ?? raw['days_of_week'];
      final days = <int>{};
      if (daysRaw is List) {
        for (final value in daysRaw) {
          final day =
              value is num ? value.toInt() : int.tryParse('$value') ?? 0;
          days.add(day == 0 ? 7 : day);
        }
      }
      final appsRaw = raw['blockedApps'] ?? raw['blocked_apps'];
      final remote = FocusSchedule(
        id: id,
        label: _string(raw['label']),
        startMinutes: start.toUtc().hour * 60 + start.toUtc().minute,
        endMinutes: end.toUtc().hour * 60 + end.toUtc().minute,
        days: days,
        blockedApps: appsRaw is List
            ? appsRaw.map((value) => value.toString()).toList()
            : const [],
        enabled: _bool(raw['enabled'], fallback: true),
        createdAt: _parseDate(raw['createdAt'] ?? raw['created_at']),
        updatedAt: _parseDate(raw['updatedAt'] ?? raw['updated_at']),
      );
      final local = localSchedules.remove(id);
      if (local != null && local.pending) {
        mergedSchedules.add(local);
      } else {
        mergedSchedules.add(remote);
      }
    }
    mergedSchedules.addAll(localSchedules.values.where((s) => s.pending));

    _local.snapshot
      ..vault = mergedVault
      ..bills = mergedBills
      ..schedules = mergedSchedules;
    await _local.save();
  }

  Uint8List? get _key {
    if (!_local.isOpen) return null;
    // LocalStore deliberately keeps the key private; encryption helpers need it.
    return LocalStore.instance.exportKeyForSync();
  }

  void _markVaultSynced(String id) {
    final snapshot = _local.snapshot;
    final index = snapshot.vault.indexWhere((item) => item.id == id);
    if (index != -1) {
      snapshot.vault[index] = snapshot.vault[index].copyWith(pending: false);
    }
  }

  void _markBillSynced(String id) {
    final snapshot = _local.snapshot;
    final index = snapshot.bills.indexWhere((bill) => bill.id == id);
    if (index != -1) {
      snapshot.bills[index] = snapshot.bills[index].copyWith(pending: false);
    }
  }

  void _markScheduleSynced(String id) {
    final snapshot = _local.snapshot;
    final index =
        snapshot.schedules.indexWhere((schedule) => schedule.id == id);
    if (index != -1) {
      snapshot.schedules[index] =
          snapshot.schedules[index].copyWith(pending: false);
    }
  }

  void _scheduleSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 900), () {
      unawaited(syncNow());
    });
  }

  Future<void> _connectSocket() async {
    final token = _token;
    if (token == null) return;
    _socketSubscription?.cancel();
    _channel?.sink.close();
    try {
      final uri = AppConfig.websocketUri.replace(
        queryParameters: {'token': token},
      );
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _socketSubscription = channel.stream.listen(
        (event) {
          if (event is String &&
              (event.contains('vault.') ||
                  event.contains('billing.') ||
                  event.contains('schedule.'))) {
            _scheduleSync();
          }
        },
        onError: (_) => _reconnectSocket(),
        onDone: _reconnectSocket,
        cancelOnError: true,
      );
      status.value = status.value.copyWith(connected: true);
    } catch (_) {
      _reconnectSocket();
    }
  }

  void _reconnectSocket() {
    status.value = status.value.copyWith(connected: false);
    if (_token == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 6), () {
      unawaited(_connectSocket());
    });
  }

  static String _timeOfDayIso(int minutes) {
    final hour = (minutes ~/ 60).clamp(0, 23);
    final minute = (minutes % 60).clamp(0, 59);
    return DateTime.utc(2000, 1, 1, hour, minute).toIso8601String();
  }

  static List<Map<String, dynamic>> _listFrom(
    Map<String, dynamic> response,
    String key,
  ) {
    final raw = response[key];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  static String _string(dynamic value) => value?.toString() ?? '';

  static bool _bool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    return fallback;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _parseDate(dynamic value) =>
      _parseNullableDate(value) ?? DateTime.now();

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
