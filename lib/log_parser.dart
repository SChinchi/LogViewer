import 'dart:io';

import 'package:flutter/material.dart';

import 'constants.dart';

final _regExp = RegExp('\\[(${Constants.logSeverity.join('|')})\\s*:\\s*(.*?)\\] (.*)');

class Mod {
  String guid;
  bool loaded = false;
  bool isDeprecated = false;
  bool isLatest = true;

  Mod(this.guid);

  void fetchData() async {
    /*
    var data = guid.split('-');
    var response = await http
        .get(Uri.parse('https://thunderstore.io/api/experimental/package/${data[0]}/${data[1]}/'));
    if (response.statusCode == 200) {
      var modData = jsonDecode(response.body) as Map<String, dynamic>;
      isDeprecated = modData['is_deprecated'];
      isLatest = data[2] == modData['latest']['version_number'];
    }
    loaded = true;
     */
  }
}

class Event {
  late int severity;
  late String source;
  late String string;
  late String fullString;
  late Color color;
  int repeat = 0;
  String? modName;

  Event(String s, RegExpMatch match) {
    severity = Constants.logSeverity.indexOf(match.group(1)!);
    source = match.group(2)!;
    string = match.group(3)!;
    fullString = s;
    if (severity < 2) {
      color = Colors.red;
    }
    else if (severity < 3) {
      color = Colors.yellow;
    }
    else {
      color = Colors.white;
    }
    var modPattern = RegExp('^TS Manifest: (.*)').firstMatch(match.group(3)!);
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

  static void _addEvent(String s) {
    var match = _regExp.firstMatch(s);
    if (match == null) {
      return;
    }
    // Compress repeated messages for the console
    if (events.isNotEmpty && events.last.fullString == s) {
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

  static bool parseFile(String path)
  {
    _reset();
    try {
      var file = File(path);
      if (!file.existsSync()) {
        return false;
      }
      var lines = file.readAsLinesSync();
      if (lines.isEmpty) {
        return false;
      }
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

      for (var event in events) {
        if (event.string == Constants.endOfSummary) {
          break;
        }
        summary.add(event.string);
      }
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
    var repeat = RegExp('^repeat:(\\d+)\\s*').firstMatch(s);
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
}