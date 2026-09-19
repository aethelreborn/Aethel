import 'package:aethel/data/local/database.dart';
import 'package:aethel/domain/models/models.dart';
import 'package:sqflite/sqflite.dart';

/// Local DAO for [BillingEntry] records backed by the SQLCipher database.
class BillingDao {
  static const _table = 'billing_items';

  Map<String, dynamic> _toRow(BillingEntry entry) => {
        'id': entry.id,
        'title': entry.title,
        'amount_due': entry.amountDue,
        'item_type': entry.type.name,
        'billing_cycle': entry.cycle?.name,
        'next_due_date': entry.nextDueDate?.toIso8601String(),
        'last_notified_at': entry.lastNotifiedAt?.toIso8601String(),
        'is_active': entry.isActive ? 1 : 0,
        'created_at': entry.createdAt.toIso8601String(),
        'updated_at': entry.updatedAt.toIso8601String(),
      };

  BillingEntry _fromRow(Map<String, Object?> row) => BillingEntry(
        id: row['id'] as String,
        title: row['title'] as String,
        amountDue: (row['amount_due'] as num).toDouble(),
        type: BillingType.values.byName(row['item_type'] as String),
        cycle: row['billing_cycle'] == null
            ? null
            : BillingCycle.values.byName(row['billing_cycle'] as String),
        nextDueDate: row['next_due_date'] == null
            ? null
            : DateTime.parse(row['next_due_date'] as String),
        lastNotifiedAt: row['last_notified_at'] == null
            ? null
            : DateTime.parse(row['last_notified_at'] as String),
        isActive: (row['is_active'] as int) == 1,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );

  Future<int> insert(BillingEntry entry) async {
    final db = AethelDatabase.database;
    return db.insert(_table, _toRow(entry),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(BillingEntry entry) async {
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

  Future<List<BillingEntry>> findAll() async {
    final db = AethelDatabase.database;
    final rows = await db.query(_table, orderBy: 'next_due_date ASC');
    return rows.map(_fromRow).toList();
  }

  Future<BillingEntry?> findById(String id) async {
    final db = AethelDatabase.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// Returns active billing entries whose [nextDueDate] falls within [daysAhead] days from now.
  Future<List<BillingEntry>> findUpcoming(int daysAhead) async {
    final db = AethelDatabase.database;
    final now = DateTime.now().toIso8601String();
    final deadline = DateTime.now().add(Duration(days: daysAhead)).toIso8601String();
    final rows = await db.query(
      _table,
      where: 'is_active = 1 AND next_due_date IS NOT NULL AND next_due_date >= ? AND next_due_date <= ?',
      whereArgs: [now, deadline],
      orderBy: 'next_due_date ASC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Removes all rows from the table. Used during cache refresh.
  Future<void> clearAll() async {
    final db = AethelDatabase.database;
    await db.delete(_table);
  }
}
