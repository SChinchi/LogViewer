import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:log_viewer/settings.dart';

import 'constants.dart';
import 'database.dart';
import 'providers/mod_manager.dart';

final _consoleSearchFilterPattens = [
  r'\s*(?<exclude>exclude:(?<exclude_term>\(.*\)|[^(\s]\S*))\s*',
  r'\s*(?<range>range:(?<r0>-?\d*)\.\.(?<r1>-?\d*))\s*',
  r'\s*(?<repeat>repeat:(?<repeat_num>\d+))\s*'
];

class Event {
  late int severity;
  late String source;
  late String string;
  late String fullString;
  late String fullStringNoPrefix;
  late Color color;
  late int index;
  late int lineCount;
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
    lineCount = fullString.split('\n').length;
    var modPattern = RegExp(r'^TS Manifest: (.*)').firstMatch(match.group(4)!);
    if (modPattern != null) {
      modName = modPattern.group(1);
    }
  }
}

class Logger
{
  static final _eventPattern = RegExp('(.*)\\[(${Constants.logSeverity.join('|')})\\s*:\\s*(.*?)\\] (.*)');
  static final _filterPattern = RegExp('^(${_consoleSearchFilterPattens.join('|')})', caseSensitive: false);

  static const intMin = ~(-1 >>> 1);
  static const startIndex = 0;
  static const endIndex = 0;

  static final events = <Event>[];
  static final modManager = ModManager();
  static final summary = <String>[];

  static var _severity = Constants.logSeverity.length - 1;
  static var _searchString = '';
  static var _searchPattern = RegExp(_searchString, caseSensitive: false);
  static var _excludePattern = RegExp('', caseSensitive: false);
  static var _eventStart = startIndex;
  static var _eventEnd = endIndex;
  static var _repeatThreshold = 0;
  static var filteredEvents = <Event>[];
  static late Future modStatusNetRequest;

  static void _addEvent(String s) {
    var match = _eventPattern.firstMatch(s);
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
      return (_searchPattern.pattern.isEmpty || event.fullString.contains(_searchPattern))
          && (_excludePattern.pattern.isEmpty || !event.fullString.contains(_excludePattern));
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

  static bool parseLines(List<String> lines)
  {
    _reset();
    try {
      var sb = StringBuffer(lines[0]);
      for (var line in lines.sublist(1, lines.length)) {
        var match = _eventPattern.firstMatch(line);
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

      var bepInExLine = RegExp(r'^BepInEx \d+\.\d+\.\d+.\d+');
      var unityLine = RegExp(r'^Running under Unity');
      var patcherLine = RegExp(r'^Loaded \d+ patcher method from \[.*\]');
      var lastSummaryLine = RegExp(r'^\d+ plugins to load$');
      for (var event in events) {
        var isLastSummaryLine = lastSummaryLine.firstMatch(event.string) != null;
        if (isLastSummaryLine ||
            bepInExLine.firstMatch(event.string) != null ||
            unityLine.firstMatch(event.string) != null ||
            patcherLine.firstMatch(event.string) != null) {
          summary.add(event.string);
        }
        if (isLastSummaryLine) {
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
    var recalculateFilters = false;
    var match = _filterPattern.firstMatch(s);
    final matches = <String, List<String?>>{};
    while (match != null) {
      if (match.namedGroup('exclude') != null) {
        matches['exclude'] = [match.namedGroup('exclude_term')];
      }
      else if (match.namedGroup('range') != null) {
        matches['range'] = [match.namedGroup('r0'), match.namedGroup('r1')];
      }
      else if (match.namedGroup('repeat') != null) {
        matches['repeat'] = [match.namedGroup('repeat_num')];
      }
      s = s.substring(match.group(0)!.length);
      match = _filterPattern.firstMatch(s);
    }
    if (matches['exclude'] != null) {
      try {
        final excludeTerm = matches['exclude']![0]!;
        if (excludeTerm != _excludePattern.pattern) {
          _excludePattern = RegExp(excludeTerm, caseSensitive: false);
          recalculateFilters = true;
        }
      }
      on FormatException catch (_) {
        // Capturing each keystroke of the search means an invalid regex is possible
      }
    }
    else {
      recalculateFilters |= _excludePattern.pattern.isNotEmpty;
      _excludePattern = RegExp('', caseSensitive: false);
    }
    if (matches['range'] != null) {
      final r0 = matches['range']![0];
      final r1 = matches['range']![1];
      var start = r0 != null ? int.tryParse(r0) ?? startIndex : startIndex;
      start = start >= 0 ? min(start, events.length) : max(startIndex, events.length+start);
      var end = r1 != null ? int.tryParse(r1) ?? intMin : intMin;
      end = end > 0 ? max(end-events.length, -events.length) : end == intMin ? startIndex : max(-events.length, end);
      recalculateFilters |= start != _eventStart || end != _eventEnd;
      _eventStart = start;
      _eventEnd = end;
    }
    else {
      recalculateFilters |= _eventStart != startIndex || _eventEnd != endIndex;
      _eventStart = startIndex;
      _eventEnd = endIndex;
    }
    if (matches['repeat'] != null) {
      final repeatValue = int.parse(matches['repeat']![0]!);
      if (repeatValue != _repeatThreshold) {
        _repeatThreshold = repeatValue;
        recalculateFilters = true;
      }
    }
    else {
      recalculateFilters |= _repeatThreshold != 0;
      _repeatThreshold = 0;
    }
    if (s != _searchPattern.pattern) {
      try {
        _searchPattern = RegExp(s, caseSensitive: false);
        recalculateFilters = true;
      } on FormatException catch (_) {
        // Capturing each keystroke of the search means an invalid regex is possible
      }
    }
    if (recalculateFilters) {
      _recalculateFilteredEvents();
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
      return;
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
                mod.isDeprecated = !whitelisted && tsMod['is_deprecated'];
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
  static List<ListItem> dependencyIssues = [];
  static List<ListItem> modsCrashingOnAwake = [];
  static List<ListItem> stuckLoading = [];
  static List<ListItem> missingMemberExceptions = [];
  static List<ListItem> mostCommonRecurrentErrors = [];

  static _reset() {
    dependencyIssues.clear();
    modsCrashingOnAwake.clear();
    stuckLoading.clear();
    missingMemberExceptions.clear();
    mostCommonRecurrentErrors.clear();
  }

  static analyse() {
    _reset();
    var missingDependency = RegExp(r'^Could not load \[.*\] because it has missing dependencies:');
    var incompatibleDependency = RegExp(r'^Could not load \[.*\] because it is incompatible with:');
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
      if (missingDependency.firstMatch(e.string) != null || incompatibleDependency.firstMatch(e.string) != null) {
        dependencyIssues.add(ListItem(text: e.fullString, color: e.color));
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