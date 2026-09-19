import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AethelDatabase {
  AethelDatabase._();

  static const _dbName = 'aethel.db';
  static const _schemaVersion = 1;

  static Database? _db;

  /// Returns the singleton database instance. Must be initialized first via [init].
  static Database get database {
    if (_db == null) throw StateError('Database not initialized — call init() first');
    return _db!;
  }

  static bool get isInitialized => _db != null;

  /// Derives an encryption key from [masterKeyBytes] and opens (or reopens) the encrypted SQLite database.
  /// Call this after the user has authenticated and the master-key-derived AES key is available.
  static Future<void> init(Uint8List masterKeyBytes) async {
    await close();

    // Use a deterministic base64 representation of the key so SQLCipher's KDF derives
    // the same data key every time the same master key is supplied.
    final dbKey = base64UrlEncode(masterKeyBytes);

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbName);

    final db = await sqlcipher.openDatabase(
      dbPath,
      version: _schemaVersion,
      password: dbKey,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    _db = db;
  }

  /// Closes the database.
  static Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) await db.close();
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vault_items (
        id              TEXT PRIMARY KEY,
        title           TEXT NOT NULL,
        item_type       TEXT NOT NULL,
        encrypted_payload TEXT NOT NULL,
        iv              TEXT NOT NULL,
        created_at      TEXT NOT NULL,
        updated_at      TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE billing_items (
        id               TEXT PRIMARY KEY,
        title            TEXT NOT NULL,
        amount_due       REAL   NOT NULL,
        item_type        TEXT NOT NULL,
        billing_cycle    TEXT,
        next_due_date    TEXT,
        last_notified_at TEXT,
        is_active        INTEGER NOT NULL DEFAULT 1,
        created_at       TEXT NOT NULL,
        updated_at       TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_vault_updated ON vault_items(updated_at DESC)');
    await db.execute('CREATE INDEX idx_billing_active ON billing_items(is_active, next_due_date)');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Version 1 — no migrations yet.
  }
}
