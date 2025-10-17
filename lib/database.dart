import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'constants.dart';
import 'utils.dart';

class DB {
  static late Future<Database> database;

  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Environment.isWeb) {
      databaseFactoryOrNull = null;
      databaseFactory = databaseFactoryFfiWeb;
    }
    else if (Environment.isWindows || Environment.isLinux) {
      databaseFactoryOrNull = null;
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    //var v = await getDatabasesPath();
    //print('PATH: $v');
    database = openDatabase(
      join(await getDatabasesPath(), Constants.dbName),
      onCreate: (db, version) async {
        for (int i = 0; i < version; i++) {
          await _upgradeDatabase(db, i + 1);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (int version = oldVersion; version < newVersion; version++) {
          await _upgradeDatabase(db, version + 1);
        }
      },
      version: Constants.dbVersion,
    );
  }

  static Future<void> _upgradeDatabase(Database db, int upgradeVersion) async {
    switch (upgradeVersion) {
      case 1:
        await db.execute(
          'CREATE TABLE ${Constants.tableName}('
              '${Entry.fullNameKey} TEXT PRIMARY KEY,'
              '${Entry.dateTsKey} TEXT,'
              '${Entry.dateDbKey} TEXT,'
              '${Entry.deprecatedKey} INTEGER)',
        );
        break;
      case 2:
        await db.execute('ALTER TABLE ${Constants.tableName} ADD ${Entry.latestVersionKey} TEXT');
        break;
    }
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
          latestVersion: kvp[Entry.latestVersionKey] as String?,
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
  static const latestVersionKey = 'latest_version';
  final String fullName;
  final String dateTs;
  final String dateDb;
  final int isDeprecated;
  final String? latestVersion;

  Entry({
    required this.fullName,
    required this.dateTs,
    required this.dateDb,
    required this.isDeprecated,
    required this.latestVersion,
  });

  Map<String, Object?> serialise() {
    return {
      fullNameKey: fullName,
      dateTsKey: dateTs,
      dateDbKey: dateDb,
      deprecatedKey: isDeprecated,
      latestVersionKey: latestVersion,
    };
  }
}