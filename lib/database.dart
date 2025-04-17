import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'constants.dart';

class DB {
  static late Future<Database> database;

  static init() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Platform.isWindows || Platform.isLinux) {
      databaseFactoryOrNull = null;
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    //var v = await getDatabasesPath();
    //print('PATH: $v');
    database = openDatabase(
      join(await getDatabasesPath(), Constants.dbName),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE ${Constants.tableName}('
          '${Entry.fullNameKey} TEXT PRIMARY KEY,'
          '${Entry.dateTsKey} TEXT,'
          '${Entry.dateDbKey} TEXT,'
          '${Entry.deprecatedKey} INTEGER)',
        );
      },
      version: 1,
    );
  }

  static Future<void> insertMod(Entry mod) async {
    final db = await database;
    await db.insert(
      Constants.tableName,
      mod.serialise(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> updateMod(Entry mod) async {
    final db = await database;
    await db.update(
      Constants.tableName,
      mod.serialise(),
      where: '${Entry.fullNameKey} = ?',
      whereArgs: [mod.fullName],
    );
  }

  static Future<Map<String, Entry>> allMods() async {
    final db = await database;
    final List<Map<String, Object?>> entries = await db.query(Constants.tableName);
    final result = <String, Entry>{};
    for (final kvp in entries) {
      final fullName = kvp[Entry.fullNameKey] as String;
      result[fullName] = Entry(
          fullName: fullName,
          dateTs: kvp[Entry.dateTsKey] as String,
          dateDb: kvp[Entry.dateDbKey] as String,
          isDeprecated: kvp[Entry.deprecatedKey] as int,
      );
    }
    return result;
  }
}

class Entry {
  static const fullNameKey = 'full_name';
  static const dateTsKey = 'date_ts';
  static const dateDbKey = 'date_db';
  static const deprecatedKey = 'deprecated';
  final String fullName;
  final String dateTs;
  final String dateDb;
  final int isDeprecated;

  Entry({
    required this.fullName,
    required this.dateTs,
    required this.dateDb,
    required this.isDeprecated,
  });

  Map<String, Object?> serialise() {
    return {
      fullNameKey: fullName,
      dateTsKey: dateTs,
      dateDbKey: dateDb,
      deprecatedKey: isDeprecated,
    };
  }
}