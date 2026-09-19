import 'package:aethel/data/local/daos/billing_dao.dart';
import 'package:aethel/core/network/api_client.dart';
import 'package:aethel/domain/models/models.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Orchestrates billing data between the local SQLCipher cache and the remote API.
class BillingRepository {
  final BillingDao _dao = BillingDao();
  final _uuid = const Uuid();

  /// Returns all billing entries, preferring the local cache.
  /// If the cache is empty the entries are fetched from the API and cached locally.
  Future<List<BillingEntry>> getAll() async {
    final local = await _dao.findAll();
    if (local.isNotEmpty) return local;

    try {
      final resp = await ApiClient.dio.get('/billing');
      final List<dynamic> items = resp.data['items'] as List<dynamic>? ?? [];
      final entries = items
          .map((e) => BillingEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final entry in entries) {
        await _dao.insert(entry);
      }
      return entries;
    } on DioException catch (_) {
      return local;
    }
  }

  /// Fetches the latest billing entries from the server and overwrites the local cache.
  Future<List<BillingEntry>> refreshFromServer() async {
    final resp = await ApiClient.dio.get('/billing');
    final List<dynamic> items = resp.data['items'] as List<dynamic>? ?? [];
    final entries = items
        .map((e) => BillingEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    await _dao.clearAll();
    for (final entry in entries) {
      await _dao.insert(entry);
    }
    return entries;
  }

  /// Adds a new billing entry to the server and caches it locally.
  Future<BillingEntry> add({
    required String title,
    required double amountDue,
    required BillingType type,
    BillingCycle? cycle,
    DateTime? nextDueDate,
    DateTime? lastNotifiedAt,
    bool isActive = true,
  }) async {
    final now = DateTime.now();
    final entry = BillingEntry(
      id: _uuid.v4(),
      title: title,
      amountDue: amountDue,
      type: type,
      cycle: cycle,
      nextDueDate: nextDueDate,
      lastNotifiedAt: lastNotifiedAt,
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
    );

    await ApiClient.dio.post('/billing', data: entry.toJson());
    await _dao.insert(entry);
    return entry;
  }

  /// Updates an existing billing entry on the server and in the local cache.
  Future<void> update(BillingEntry entry) async {
    await ApiClient.dio.put('/billing/${entry.id}', data: entry.toJson());
    await _dao.update(entry);
  }

  /// Marks a billing entry as paid on the server and updates the local cache.
  Future<void> markPaid(String id) async {
    await ApiClient.dio.post('/billing/$id/paid');
    final existing = await _dao.findById(id);
    if (existing != null) {
      final updated = BillingEntry(
        id: existing.id,
        title: existing.title,
        amountDue: existing.amountDue,
        type: existing.type,
        cycle: existing.cycle,
        nextDueDate: existing.nextDueDate,
        lastNotifiedAt: existing.lastNotifiedAt ?? DateTime.now(),
        isActive: false,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      await _dao.update(updated);
    }
  }

  /// Deletes a billing entry from the server and removes it from the local cache.
  Future<void> delete(String id) async {
    await ApiClient.dio.delete('/billing/$id');
    await _dao.delete(id);
  }

  /// Returns active billing entries whose next due date falls within [daysAhead] days from now.
  /// Falls back to the local cache when the server is unavailable.
  Future<List<BillingEntry>> findUpcoming(int daysAhead) async {
    try {
      final resp = await ApiClient.dio.get(
        '/billing/upcoming',
        queryParameters: {'days_ahead': daysAhead},
      );
      final List<dynamic> items = resp.data['items'] as List<dynamic>? ?? [];
      final entries = items
          .map((e) => BillingEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      // Cache results for future calls.
      await _dao.clearAll();
      for (final entry in entries) {
        await _dao.insert(entry);
      }
      return entries;
    } on DioException {
      return _dao.findUpcoming(daysAhead);
    }
  }

  /// Called after authentication to ensure the local cache is in sync with the server.
  Future<void> reconcile() async {
    await refreshFromServer();
  }
}
