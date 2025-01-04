import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DB {
  static late Future<Database> database;

  static init() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    //var v = await getDatabasesPath();
    //print('PATH: $v');
    database = openDatabase(
      join(await getDatabasesPath(), 'mods.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE mods(id INTEGER PRIMARY KEY, full_name TEXT, version TEXT, date_ts TEXT, date_db TEXT, deprecated INTEGER)',
        );
      },
      version: 1,
    );
  }

  static Future<void> insertMod(Entry mod) async {
    final db = await database;
    await db.insert(
      'mods',
      mod.serialise(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> updateMod(Entry mod) async {
    final db = await database;

    await db.update(
      'mods',
      mod.serialise(),
      where: 'id = ?',
      whereArgs: [mod.id],
    );
  }

  static Future<Map<String, Entry>> allMods() async {
    final db = await database;
    final List<Map<String, Object?>> entries = await db.query('mods');
    final result = <String, Entry>{};
    for (var kvp in entries) {
      var fullName = kvp['full_name'] as String;
      result[fullName] = Entry(
          id: kvp['id'] as int,
          fullName: fullName,
          version: kvp['version'] as String,
          dateTs: kvp['date_ts'] as String,
          dateDb: kvp['date_db'] as String,
          isDeprecated: kvp['deprecated'] as int,
      );
    }
    return result;
  }
}

class Entry {
  final int id;
  final String fullName;
  final String version;
  final String dateTs;
  final String dateDb;
  final int isDeprecated;

  Entry({
    required this.id,
    required this.fullName,
    required this.version,
    required this.dateTs,
    required this.dateDb,
    required this.isDeprecated,
  });

  Map<String, Object?> serialise() {
    return {
      'id': id,
      'full_name': fullName,
      'version': version,
      'date_ts': dateTs,
      'date_db': dateDb,
      'deprecated': isDeprecated,
    };
  }
}