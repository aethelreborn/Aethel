import 'package:aethel/data/local/daos/vault_dao.dart';
import 'package:aethel/core/network/api_client.dart';
import 'package:aethel/domain/models/models.dart';
import 'package:dio/dio.dart';

/// Orchestrates vault data between the local SQLCipher cache and the remote API.
class VaultRepository {
  final VaultDao _dao = VaultDao();

  /// Returns all vault entries, preferring the local cache.
  /// If the cache is empty the entries are fetched from the API and cached locally.
  Future<List<VaultEntry>> getAll() async {
    final local = await _dao.findAll();
    if (local.isNotEmpty) return local;

    try {
      final resp = await ApiClient.dio.get('/vault');
      final List<dynamic> items = resp.data['items'] as List<dynamic>? ?? [];
      final entries = items
          .map((e) => VaultEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final entry in entries) {
        await _dao.insert(entry);
      }
      return entries;
    } on DioException catch (_) {
      // Return whatever we have locally even on failure.
      return local;
    }
  }

  /// Fetches the latest vault entries from the server and overwrites the local cache.
  Future<List<VaultEntry>> refreshFromServer() async {
    final resp = await ApiClient.dio.get('/vault');
    final List<dynamic> items = resp.data['items'] as List<dynamic>? ?? [];
    final entries = items
        .map((e) => VaultEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    await _dao.clearAll();
    for (final entry in entries) {
      await _dao.insert(entry);
    }
    return entries;
  }

  /// Adds a new vault entry: POSTs to the API and writes to the local cache.
  /// The entry must already contain valid [VaultEntry.encryptedPayload] and [VaultEntry.iv].
  /// Callers responsible for encrypting the raw payload before invoking this method.
  Future<VaultEntry> add(VaultEntry entry) async {
    await ApiClient.dio.post('/vault', data: entry.toJson());
    await _dao.insert(entry);
    return entry;
  }

  /// Updates an existing vault entry on the server and in the local cache.
  Future<void> update(VaultEntry entry) async {
    await ApiClient.dio.put('/vault/${entry.id}', data: entry.toJson());
    await _dao.update(entry);
  }

  /// Deletes a vault entry from the server and removes it from the local cache.
  Future<void> delete(String id) async {
    await ApiClient.dio.delete('/vault/$id');
    await _dao.delete(id);
  }

  /// Called after authentication to ensure the local cache is in sync with the server.
  Future<void> reconcile() async {
    await refreshFromServer();
  }
}
