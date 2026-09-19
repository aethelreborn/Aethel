import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aethel/domain/models/models.dart';
import 'package:aethel/core/network/api_client.dart';

final timelineProvider = StateNotifierProvider<TimelineNotifier, AsyncValue<List<TimelineEvent>>>(
  (ref) => TimelineNotifier(),
);

class TimelineNotifier extends StateNotifier<AsyncValue<List<TimelineEvent>>> {
  TimelineNotifier() : super(const AsyncLoading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncLoading();
    try {
      final resp = await ApiClient.dio.get('/timeline');
      final List<dynamic> items = resp.data['events'] as List<dynamic>? ?? [];
      final events = items.map((e) {
        final map = e as Map<String, dynamic>;
        return TimelineEvent(
          id: map['id'] as String,
          title: map['title'] as String,
          subtitle: map['subtitle'] as String,
          urgency: UrgencyLevel.values.byName(map['urgency'] as String),
          timestamp: DateTime.parse(map['timestamp'] as String),
          module: map['module'] as String,
        );
      }).toList();
      state = AsyncValue.data(events);
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }
}

final vaultProvider = StateNotifierProvider<VaultNotifier, AsyncValue<List<VaultEntry>>>(
  (ref) => VaultNotifier(),
);

class VaultNotifier extends StateNotifier<AsyncValue<List<VaultEntry>>> {
  VaultNotifier() : super(const AsyncLoading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncLoading();
    try {
      final resp = await ApiClient.dio.get('/vault');
      final List<dynamic> items = resp.data['items'] as List<dynamic>? ?? [];
      final entries = items.map((e) => VaultEntry.fromJson(e as Map<String, dynamic>)).toList();
      state = AsyncValue.data(entries);
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }

  Future<void> add(VaultEntry entry) async {
    await ApiClient.dio.post('/vault', data: entry.toJson());
    await fetch();
  }

  Future<void> delete(String id) async {
    await ApiClient.dio.delete('/vault/$id');
    await fetch();
  }
}

final billingProvider = StateNotifierProvider<BillingNotifier, AsyncValue<List<BillingEntry>>>(
  (ref) => BillingNotifier(),
);

class BillingNotifier extends StateNotifier<AsyncValue<List<BillingEntry>>> {
  BillingNotifier() : super(const AsyncLoading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncLoading();
    try {
      final resp = await ApiClient.dio.get('/billing');
      final List<dynamic> items = resp.data['items'] as List<dynamic>? ?? [];
      final entries = items.map((e) => BillingEntry.fromJson(e as Map<String, dynamic>)).toList();
      state = AsyncValue.data(entries);
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }

  Future<void> add(BillingEntry entry) async {
    await ApiClient.dio.post('/billing', data: entry.toJson());
    await fetch();
  }

  Future<void> markPaid(String id) async {
    await ApiClient.dio.post('/billing/$id/paid');
    await fetch();
  }

  Future<void> delete(String id) async {
    await ApiClient.dio.delete('/billing/$id');
    await fetch();
  }
}
