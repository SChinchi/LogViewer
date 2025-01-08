import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:log_viewer/settings.dart';

import 'constants.dart';
import 'database.dart';

final _regExp = RegExp('(.*)\\[(${Constants.logSeverity.join('|')})\\s*:\\s*(.*?)\\] (.*)');

class Mod {
  String guid;
  late String fullName;
  bool isDeprecated = false;
  bool isOld = false;

  Mod(this.guid) {
    var pattern = RegExp(r'^(.*)-\d+.\d+.\d+');
    var name = pattern.firstMatch(guid);
    fullName = name != null ? name.group(1)! : guid;
  }
}

enum ModCategory {
  All,
  Deprecated,
  Old,
  Problematic,
}

class ModManager {
  final mods = <Mod>[];
  final filteredMods = <Mod>[];
  final _nameToMod = <String, Mod>{};

  var _category = ModCategory.All;
  set category(ModCategory value)
  {
    if (_category == value) {
      return;
    }
    _category = value;
    _recalculateFilteredMods();
  }
  ModCategory get category => _category;

  var _searchString = RegExp('', caseSensitive: false);
  set searchString(String value) {
    if (value != _searchString.pattern) {
      try {
        _searchString = RegExp(value, caseSensitive: false);
        _recalculateFilteredMods();
      } on FormatException catch (_) {
        // Capturing each keystroke of the search means an invalid regex is possible
      }
    }
  }
  String get searchString => _searchString.pattern;

  bool _passesFilter(Mod mod) {
    if (_category == ModCategory.All
        || (_category == ModCategory.Deprecated && mod.isDeprecated)
        || (_category == ModCategory.Old && mod.isOld && !mod.isDeprecated)) {
      return _searchString.pattern.isEmpty || mod.guid.contains(_searchString);
    }
    return false;
  }

  void _recalculateFilteredMods() {
    filteredMods.clear();
    for (var mod in mods) {
      if (_passesFilter(mod)) {
        filteredMods.add(mod);
      }
    }
  }

  void reset() {
    mods.clear();
    filteredMods.clear();
    _nameToMod.clear();
    _category = ModCategory.All;
    _searchString = RegExp('', caseSensitive: false);
  }

  void add(Mod mod) {
    mods.add(mod);
    if (_passesFilter(mod)) {
      filteredMods.add(mod);
    }
    _nameToMod[mod.fullName] = mod;
  }

  Mod? getMod(String name) {
    return _nameToMod[name];
  }
}

class Event {
  late int severity;
  late String source;
  late String string;
  late String fullString;
  late String fullStringNoPrefix;
  late Color color;
  int repeat = 0;
  String? modName;

  Event(String s, RegExpMatch match) {
    severity = Constants.logSeverity.indexOf(match.group(2)!);
    source = match.group(3)!;
    string = match.group(4)!;
    fullString = s;
    fullStringNoPrefix = s.substring(match.group(1)!.length);
    if (severity < 2) {
      color = Colors.red;
    }
    else if (severity < 3) {
      color = Colors.yellow;
    }
    else {
      color = Colors.white;
    }
    var modPattern = RegExp(r'^TS Manifest: (.*)').firstMatch(match.group(4)!);
    if (modPattern != null) {
      modName = modPattern.group(1);
    }
  }
}

class Logger
{
  static final events = <Event>[];
  static final modManager = ModManager();
  static final summary = <String>[];

  static var _severity = Constants.logSeverity.length - 1;
  static RegExp _searchPattern = RegExp('', caseSensitive: false);
  static int _repeatThreshold = 0;
  static var filteredEvents = <Event>[];
  static late Future modStatusNetRequest;

  static void _addEvent(String s) {
    var match = _regExp.firstMatch(s);
    if (match == null) {
      return;
    }
    // Compress repeated messages for the console
    var sNoPrefix = s.substring(match.group(1)!.length);
    if (events.isNotEmpty && events.last.fullStringNoPrefix == sNoPrefix) {
      events.last.repeat++;
      return;
    }
    var event = Event(s, match);
    events.add(event);
    if (_passesFilter(event)) {
      filteredEvents.add(event);
    }
    if (event.modName != null) {
      modManager.add(Mod(event.modName!));
    }
  }

  static bool _passesFilter(Event event) {
    if (event.severity <= _severity && event.repeat >= _repeatThreshold) {
      return _searchPattern.pattern.isEmpty || event.fullString.contains(_searchPattern);
    }
    return false;
  }

  static void _recalculateFilteredEvents() {
    filteredEvents.clear();
    for (var e in events) {
      if (_passesFilter(e)) {
        filteredEvents.add(e);
      }
    }
  }

  static void _reset() {
    events.clear();
    filteredEvents.clear();
    modManager.reset();
    summary.clear();

    _severity = Constants.logSeverity.length - 1;
    _searchPattern = RegExp('', caseSensitive: false);
    _repeatThreshold = 0;
  }

  static bool parseFile(String path) {
    try {
      var file = File(path);
      if (!file.existsSync()) {
        return false;
      }
      var lines = file.readAsLinesSync();
      if (lines.isEmpty) {
        return false;
      }
      return parseLines(lines);
    }
    on Exception catch (_) {
      return false;
    }
  }

  static bool parseLines(List<String> lines)
  {
    _reset();
    try {
      var sb = StringBuffer(lines[0]);
      for (var line in lines.sublist(1, lines.length)) {
        var match = _regExp.firstMatch(line);
        if (match != null) {
          _addEvent(sb.toString().trimRight());
          sb.clear();
        }
        sb.writeln(line);
      }
      if (sb.isNotEmpty) {
        _addEvent(sb.toString().trimRight());
      }

      var lastSummaryLine = RegExp(r'^\d+ plugins to load$');
      for (var event in events) {
        summary.add(event.string);
        if (lastSummaryLine.firstMatch(event.string) != null) {
          break;
        }
      }

      modStatusNetRequest = getAllModsStatus();
      Diagnostics.analyse();
      return true;
    }
    on Exception catch (_) {
      return false;
    }
  }

  static void setSeverity(int num) {
    if (_severity == num) {
      return;
    }
    _severity = num;
    _recalculateFilteredEvents();
  }

  static int getSeverity() {
    return _severity;
  }

  static void setSearchString(String s) {
    s = s.toLowerCase();
    var repeat = RegExp(r'^repeat:(\d+)\s*').firstMatch(s);
    var hasThresholdChanged = false;
    if (repeat != null) {
      var value = int.parse(repeat.group(1)!);
      if (value != _repeatThreshold) {
        hasThresholdChanged = true;
      }
      _repeatThreshold = value;
      s = s.substring(repeat.group(0)!.length);
    }
    else {
      if (_repeatThreshold != 0) {
        hasThresholdChanged = true;
      }
      _repeatThreshold = 0;
    }
    if (s != _searchPattern.pattern || hasThresholdChanged) {
      try {
        _searchPattern = RegExp(s, caseSensitive: false);
        _recalculateFilteredEvents();
      } on FormatException catch (_) {
        // Capturing each keystroke of the search means an invalid regex is possible
      }
    }
  }

  static String getSearchString() {
    return _searchPattern.pattern;
  }

  static Future getAllModsStatus() async {
    await DB.init();
    var query = await DB.allMods();
    var toUpdate = <String, int>{};
    var now = DateTime.now();
    var cutOffDate = Settings.getCutOffDate();
    var id = query.length;
    for (var mod in Logger.modManager.mods) {
      var entry = query[mod.fullName];
      if (entry != null) {
        mod.isDeprecated = entry.isDeprecated == 1;
        mod.isOld = cutOffDate != null
            && DateTime.parse(entry.dateTs).difference(cutOffDate).isNegative
            && !mod.isDeprecated;
        if (now.difference(DateTime.parse(entry.dateDb)).inHours > 1) {
          if (!toUpdate.containsKey(mod.fullName)) {
            toUpdate[mod.fullName] = entry.id;
          }
        }
      }
      else {
        if (!toUpdate.containsKey(mod.fullName)) {
          toUpdate[mod.fullName] = id;
          id++;
        }
      }
    }

    // TODO: Ensure network permissions are granted and catch any network errors
    return Future(() => {
      http.get(Uri.parse('https://thunderstore.io/api/v1/package/')).then((response) {
        if (response.statusCode == 200) {
          var body = jsonDecode(response.body) as List;
          for (var tsMod in body) {
            var fullName = tsMod['full_name'];
            if (toUpdate.containsKey(fullName)) {
              var mod = Logger.modManager.getMod(fullName);
              if (mod != null) {
                mod.isDeprecated = tsMod['is_deprecated'] == 1;
                mod.isOld = cutOffDate != null
                    && DateTime
                        .parse(tsMod['date_updated'])
                        .difference(cutOffDate)
                        .isNegative
                    && !mod.isDeprecated;
                var entry = Entry(
                  id: toUpdate[fullName]!,
                  fullName: fullName,
                  version: '',
                  dateTs: tsMod['date_updated'],
                  dateDb: now.toIso8601String(),
                  isDeprecated: tsMod['is_deprecated'] ? 1 : 0,
                );
                DB.insertMod(entry);
                toUpdate.remove(fullName);
                if (toUpdate.isEmpty) {
                  break;
                }
              }
            }
          }
        }
      })
    });
  }
}

class ListItem {
  String text;
  Color color;
  int? repeat;

  ListItem({required this.text, required this.color, this.repeat});
}

class Diagnostics {
  static List<ListItem> modsCrashingOnAwake = [];
  static List<ListItem> missingMemberExceptions = [];
  static List<ListItem> mostCommonRecurrentErrors = [];

  static _reset() {
    modsCrashingOnAwake.clear();
    missingMemberExceptions.clear();
    mostCommonRecurrentErrors.clear();
  }

  static analyse() {
    _reset();
    var chainLoaderPattern = RegExp(r'BepInEx.Bootstrap.Chainloader:Start()');
    var missingPattern = RegExp('^Missing(Field|Method)Exception');
    var encounteredExceptions = <String>{};
    var encounteredCommonErrors = <String>{};
    var currentMod = '';
    for (var e in Logger.events) {
      if (e.modName != null) {
        currentMod = e.modName!;
      }
      if (missingPattern.firstMatch(e.string) != null && !encounteredExceptions.contains(e.fullStringNoPrefix)) {
        missingMemberExceptions.add(ListItem(text: e.fullString, color: e.color));
        encounteredExceptions.add(e.fullStringNoPrefix);
      }
      if (e.repeat > 0 && e.severity < 2 && !encounteredCommonErrors.contains(e.fullStringNoPrefix)) {
        mostCommonRecurrentErrors.add(ListItem(text: e.fullString, color: e.color, repeat: e.repeat));
        encounteredCommonErrors.add(e.fullStringNoPrefix);
      }
      if (chainLoaderPattern.firstMatch(e.fullString) != null) {
        modsCrashingOnAwake.add(ListItem(text: '$currentMod\n${e.fullString}', color: e.color));
      }
    }
    mostCommonRecurrentErrors.sort((event1, event2) => event2.repeat!.compareTo(event1.repeat!));
  }
}