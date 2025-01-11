import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:log_viewer/settings.dart';

import 'constants.dart';
import 'database.dart';
import 'providers/mod_manager.dart';

final _regExp = RegExp('(.*)\\[(${Constants.logSeverity.join('|')})\\s*:\\s*(.*?)\\] (.*)');

class Event {
  late int severity;
  late String source;
  late String string;
  late String fullString;
  late String fullStringNoPrefix;
  late Color color;
  late int index;
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
  static const intMin = ~(-1 >>> 1);
  static const startIndex = 0;
  static const endIndex = 0;

  static final events = <Event>[];
  static final modManager = ModManager();
  static final summary = <String>[];

  static var _severity = Constants.logSeverity.length - 1;
  static var _searchString = '';
  static RegExp _searchPattern = RegExp(_searchString, caseSensitive: false);
  static int _eventStart = startIndex;
  static int _eventEnd = endIndex;
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
    event.index = events.length;
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
    var start = _eventStart;
    var end = max(_eventStart, events.length+_eventEnd);
    for (var e in events.sublist(start, end)) {
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
    _searchString = '';
    _searchPattern = RegExp(_searchString, caseSensitive: false);
    _eventStart = startIndex;
    _eventEnd = endIndex;
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
      // Prefix each message with its index; useful for range searching
      var total = events.length;
      var length = total.toString().length;
      for (var event in events) {
        event.fullString = '${event.index.toString().padLeft(length, '0')} ${event.fullString}';
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
    _searchString = s;
    s = s.toLowerCase();
    var eventRange = RegExp(r'\s*range:(-?\d+)?\.\.(-?\d+)?\s*').firstMatch(s);
    var hasRangeChanged = false;
    if (eventRange != null) {
      var start = eventRange.group(1) != null ? int.tryParse(eventRange.group(1)!) ?? startIndex : startIndex;
      start = start >= 0 ? min(start, events.length) : max(startIndex, events.length+start);
      var end = eventRange.group(2) != null ? int.tryParse(eventRange.group(2)!) ?? intMin : intMin;
      end = end > 0 ? max(end-events.length, -events.length) : end == intMin ? startIndex : max(-events.length, end);
      hasRangeChanged = start != _eventStart || end != _eventEnd;
      _eventStart = start;
      _eventEnd = end;
      s = s.replaceFirst(eventRange.group(0)!, '');
    }
    else {
      hasRangeChanged = _eventStart != startIndex || _eventEnd != endIndex;
      _eventStart = startIndex;
      _eventEnd = endIndex;
    }
    var repeat = RegExp(r'\s*repeat:(\d+)\s*').firstMatch(s);
    var hasThresholdChanged = false;
    if (repeat != null) {
      var value = int.parse(repeat.group(1)!);
      hasThresholdChanged = value != _repeatThreshold;
      _repeatThreshold = value;
      s = s.replaceFirst(repeat.group(0)!, '');
    }
    else {
      hasThresholdChanged = _repeatThreshold != 0;
      _repeatThreshold = 0;
    }
    if (s != _searchPattern.pattern || hasRangeChanged || hasThresholdChanged) {
      try {
        _searchPattern = RegExp(s, caseSensitive: false);
        _recalculateFilteredEvents();
      } on FormatException catch (_) {
        // Capturing each keystroke of the search means an invalid regex is possible
      }
    }
  }

  static String getSearchString() {
    return _searchString;
  }

  static Future getAllModsStatus() async {
    await DB.init();
    var query = await DB.allMods();
    var toUpdate = <String>{};
    var now = DateTime.now();
    var cutOffDate = Settings.getCutOffDate();
    var deprecatedAndOldWhitelist = Settings.getDeprecatedAndOldWhitelist();
    var problematicModlist = Settings.getProblematicModlist();
    for (var mod in Logger.modManager.mods) {
      var entry = query[mod.fullName];
      if (entry != null) {
        var whitelisted = deprecatedAndOldWhitelist.contains(mod.fullName);
        mod.isDeprecated = !whitelisted && entry.isDeprecated == 1;
        mod.isOld = !whitelisted
            && cutOffDate != null
            && DateTime.parse(entry.dateTs).difference(cutOffDate).isNegative
            && !mod.isDeprecated;
        if (now.difference(DateTime.parse(entry.dateDb)).inHours > 1) {
          toUpdate.add(mod.fullName);
        }
        mod.isProblematic = problematicModlist.contains(mod.fullName);
      }
      else {
        toUpdate.add(mod.fullName);
      }
    }

    if (toUpdate.isEmpty) {
      modManager.recalculateFilteredMods();
    }

    // TODO: Ensure network permissions are granted and catch any network errors
    return Future(() => {
      http.get(Uri.parse('https://thunderstore.io/api/v1/package/')).then((response) {
        if (response.statusCode == 200) {
          var body = jsonDecode(response.body) as List;
          for (var tsMod in body) {
            var fullName = tsMod['full_name'];
            if (toUpdate.contains(fullName)) {
              var mod = Logger.modManager.getMod(fullName);
              if (mod != null) {
                var whitelisted = deprecatedAndOldWhitelist.contains(mod.fullName);
                mod.isDeprecated = !whitelisted && tsMod['is_deprecated'] == 1;
                mod.isOld = !whitelisted
                    && cutOffDate != null
                    && DateTime
                        .parse(tsMod['date_updated'])
                        .difference(cutOffDate)
                        .isNegative
                    && !mod.isDeprecated;
                mod.isProblematic = problematicModlist.contains(fullName);
                var entry = Entry(
                  fullName: fullName,
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
        modManager.recalculateFilteredMods();
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
  static List<ListItem> stuckLoading = [];
  static List<ListItem> missingMemberExceptions = [];
  static List<ListItem> mostCommonRecurrentErrors = [];

  static _reset() {
    modsCrashingOnAwake.clear();
    stuckLoading.clear();
    missingMemberExceptions.clear();
    mostCommonRecurrentErrors.clear();
  }

  static analyse() {
    _reset();
    var chainLoaderPattern = RegExp(r'BepInEx.Bootstrap.Chainloader:Start\(\)');
    var missingPattern = RegExp('^Missing(Field|Method)Exception');
    var stuckLoadingPattern = RegExp(r'RoR2\.RoR2Application\+<LoadGameContent>d__\d+\.MoveNext \(\)');
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
      if (stuckLoadingPattern.firstMatch(e.fullString) != null) {
        stuckLoading.add(ListItem(text: e.fullString, color: e.color));
      }
    }
    mostCommonRecurrentErrors.sort((event1, event2) => event2.repeat!.compareTo(event1.repeat!));
  }
}