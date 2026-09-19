import 'package:aethel/data/local/database.dart';
import 'package:aethel/domain/models/models.dart';
import 'package:sqflite/sqflite.dart';

/// Local DAO for [VaultEntry] records backed by the SQLCipher database.
class VaultDao {
  static const _table = 'vault_items';

  Map<String, dynamic> _toRow(VaultEntry entry) => {
        'id': entry.id,
        'title': entry.title,
        'item_type': entry.type.name,
        'encrypted_payload': entry.encryptedPayload,
        'iv': entry.iv,
        'created_at': entry.createdAt.toIso8601String(),
        'updated_at': entry.updatedAt.toIso8601String(),
      };

  VaultEntry _fromRow(Map<String, Object?> row) => VaultEntry(
        id: row['id'] as String,
        title: row['title'] as String,
        type: VaultItemType.values.byName(row['item_type'] as String),
        encryptedPayload: row['encrypted_payload'] as String,
        iv: row['iv'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );

  Future<int> insert(VaultEntry entry) async {
    final db = AethelDatabase.database;
    return db.insert(_table, _toRow(entry),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(VaultEntry entry) async {
    final db = AethelDatabase.database;
    return db.update(
      _table,
      _toRow(entry),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> delete(String id) async {
    final db = AethelDatabase.database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<VaultEntry>> findAll() async {
    final db = AethelDatabase.database;
    final rows = await db.query(_table, orderBy: 'updated_at DESC');
    return rows.map(_fromRow).toList();
  }

  Future<VaultEntry?> findById(String id) async {
    final db = AethelDatabase.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// Removes all rows from the table. Used during cache refresh.
  Future<void> clearAll() async {
    final db = AethelDatabase.database;
    await db.delete(_table);
  }
}
