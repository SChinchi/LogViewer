import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'database.dart';

final _regExp = RegExp('(.*)\\[(${Constants.logSeverity.join('|')})\\s*:\\s*(.*?)\\] (.*)');

class Mod {
  String guid;
  bool isDeprecated = false;
  bool isLatest = true;

  Mod(this.guid);
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
  static final mods = <Mod>[];
  static final summary = <String>[];

  static var _severity = Constants.logSeverity.length - 1;
  static RegExp _searchPattern = RegExp('', caseSensitive: false);
  static int _repeatThreshold = 0;
  static var filteredEvents = <Event>[];
  static late Future<List<Null>> modStatusNetRequest;

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
      mods.add(Mod(event.modName!));
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
    mods.clear();
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

  static Future<List<Null>> getAllModsStatus() async {
    await DB.init();
    var query = await DB.allMods();
    var toUpdate = List.generate(0, (i) => <String>[]);
    var now = DateTime.now();
    var id = query.length;
    for (var mod in Logger.mods) {
      var data = mod.guid.split('-');
      var fullName = '${data[0]}-${data[1]}';
      var entry = query[fullName];
      if (entry != null) {
        if (now.difference(DateTime.parse(entry.dateDb)).inHours < 1) {
          mod.isLatest = entry.version == data[2];
          mod.isDeprecated = entry.isDeprecated == 1;
        }
        else {
          toUpdate.add([data[0], data[1], entry.id.toString()]);
        }
      }
      else {
        toUpdate.add([data[0], data[1], id.toString()]);
        id++;
      }
    }

    // TODO: Ensure network permissions are granted and catch any network errors
    var client = http.Client();
    return Future.wait(toUpdate.map((data) =>
        client.get(
            Uri.parse('https://thunderstore.io/api/experimental/package/${data[0]}/${data[1]}/'))
            .then((response) {
              if (response.statusCode == 200) {
                var body = jsonDecode(response.body) as Map<String, dynamic>;
                var fullName = body['full_name'] as String;
                for (var mod in Logger.mods) {
                  if (mod.guid.startsWith(fullName)) {
                    var guid = mod.guid.split('-');
                    mod.isLatest = body['latest']['version_number'] == guid[2];
                    mod.isDeprecated = body['is_deprecated'] == 1;
                    var entry = Entry(
                      id: int.parse(data[2]),
                      fullName: fullName,
                      version: body['latest']['version_number'],
                      dateTs: body['date_updated'],
                      dateDb: now.toIso8601String(),
                      isDeprecated: body['is_deprecated'] ? 1 : 0,
                    );
                    DB.insertMod(entry);
                  }
                }
              }
            })
    ));
  }
}

class Diagnostics {
  static List<Event> missingMemberExceptions = [];
  static List<Event> mostCommonRecurrentErrors = [];

  static _reset() {
    missingMemberExceptions.clear();
    mostCommonRecurrentErrors.clear();
  }

  static analyse() {
    _reset();
    var missingPattern = RegExp('^Missing(Field|Method)Exception');
    var encounteredExceptions = <String>{};
    var encounteredCommonErrors = <String>{};
    for (var e in Logger.events) {
      if (missingPattern.firstMatch(e.string) != null && !encounteredExceptions.contains(e.fullStringNoPrefix)) {
        missingMemberExceptions.add(e);
        encounteredExceptions.add(e.fullStringNoPrefix);
      }
      if (e.repeat > 0 && e.severity < 2 && !encounteredCommonErrors.contains(e.fullStringNoPrefix)) {
        mostCommonRecurrentErrors.add(e);
        encounteredCommonErrors.add(e.fullStringNoPrefix);
      }
    }
    mostCommonRecurrentErrors.sort((event1, event2) => event2.repeat.compareTo(event1.repeat));
  }
}