import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'database.dart';
import 'providers/mod_manager.dart';
import 'settings.dart';
import 'themes/themes.dart';

final _consoleSearchFilterPattens = [
  r'\s*(?<exclude>exclude:(?<exclude_term>\(.*\)|[^(\s]\S*))\s*',
  r'\s*(?<range>range:(?<r0>-?\d*)\.\.(?<r1>-?\d*))\s*',
  r'\s*(?<repeat>repeat:(?<repeat_num>\d+))\s*'
];

class Event {
  static final _modPattern = RegExp(r'^TS Manifest: (.*)');

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

  Event(String text, RegExpMatch match) {
    severity = Constants.logSeverity.indexOf(match.group(2)!);
    source = match.group(3)!;
    string = match.group(4)!;
    fullString = text;
    fullStringNoPrefix = text.substring(match.group(1)!.length);
    if (severity < 2) {
      color = Colors.red;
    }
    else if (severity < 3) {
      color = Colors.yellow;
    }
    else {
      color = AppTheme.primaryColor;
    }
    lineCount = fullString.split('\n').length;
    final modPattern = _modPattern.firstMatch(match.group(4)!);
    if (modPattern != null) {
      modName = modPattern.group(1);
    }
  }

  Event.clone(Event event) {
    severity = event.severity;
    source = event.source;
    string = event.string;
    fullString = event.fullString;
    fullStringNoPrefix = event.fullStringNoPrefix;
    color = event.color;
    index = event.index;
    lineCount = event.lineCount;
    repeat = repeat;
    modName = event.modName;
  }
}

class Parser {
  static final _eventPattern = RegExp('(.*)\\[(${Constants.logSeverity.join('|')})\\s*:\\s*(.*?)\\] (.*)');

  final summary = <Text>[];
  final mods = <Mod>[];
  final events = <Event>[];

  void _addEvent(String text) {
    final match = _eventPattern.firstMatch(text);
    if (match == null) {
      return;
    }
    // Compress repeated messages for the console
    final sNoPrefix = text.substring(match.group(1)!.length);
    if (events.isNotEmpty && events.last.fullStringNoPrefix == sNoPrefix) {
      events.last.repeat++;
      return;
    }
    final event = Event(text, match);
    event.index = events.length;
    events.add(event);
    if (event.modName != null) {
      mods.add(Mod(event.modName!));
    }
  }

  void _createSummary() {
    final bepInExLine = RegExp(r'^BepInEx \d+\.\d+\.\d+.\d+');
    final unityLine = RegExp(r'^Running under Unity');
    final patcherLine = RegExp(r'^Loaded \d+ patcher method from \[.*\]');
    final pluginsLine = RegExp(r'^\d+ plugins to load$');
    final wWiseLine = RegExp(r'^WwiseUnity: Setting Plugin DLL path to');
    for (final event in events) {
      final wWiseMatch = wWiseLine.firstMatch(event.string) != null;
      final isLastSummaryLine = wWiseMatch;
      if (isLastSummaryLine ||
          bepInExLine.firstMatch(event.string) != null ||
          unityLine.firstMatch(event.string) != null ||
          patcherLine.firstMatch(event.string) != null ||
          pluginsLine.firstMatch(event.string) != null) {
        if (!wWiseMatch) {
          summary.add(Text(event.string));
        }
        // Checking if the installed path is illegitimate to add it to the summary.
        // Epic Games does allow any directory path so some rare false positives are expected.
        else if (!event.string.contains('/steamapps/common/Risk') && !event.string.contains('/Epic Games/Risk')) {
          summary.add(Text(event.string, style: const TextStyle(color: Colors.yellow)));
        }
      }
      if (isLastSummaryLine) {
        return;
      }
    }
  }

  void parse(List<String> lines, SendPort sender)
  {
    try {
      var progress = 0;
      var index = 0;
      final total = lines.length;
      final sb = StringBuffer(lines[0]);
      for (final line in lines.sublist(1, lines.length)) {
        final match = _eventPattern.firstMatch(line);
        if (match != null) {
          _addEvent(sb.toString().trimRight());
          sb.clear();
        }
        sb.writeln(line);
        index += 1;
        if (index % 5000 == 0) {
          final currentProgress = (index / total * 100).toInt();
          if (currentProgress != progress) {
            progress = currentProgress;
            sender.send(progress);
          }
        }
      }
      if (sb.isNotEmpty) {
        _addEvent(sb.toString().trimRight());
      }

      // Prefix each message with its index; useful for range searching
      final eventNum = events.length;
      final length = eventNum.toString().length;
      for (final event in events) {
        event.fullString = '${event.index.toString().padLeft(length, '0')} ${event.fullString}';
      }

      _createSummary();

      sender.send({
        'success': true,
        'summary': summary,
        'mods': mods,
        'events': events,
      });
    }
    on Exception catch (_) {
      sender.send({
        'success': false
      });
    }
  }
}

class Logger {
  static final _filterPattern = RegExp('^(${_consoleSearchFilterPattens.join('|')})', caseSensitive: false);

  static const intMin = ~(-1 >>> 1);
  static const startIndex = 0;
  static const endIndex = 0;

  static final events = <Event>[];
  static final modManager = ModManager();
  static final summary = <Text>[];

  static var _severity = Constants.logSeverity.length - 1;
  static var _searchString = '';
  static var _searchPattern = RegExp(_searchString, caseSensitive: false);
  static var _excludePattern = RegExp('', caseSensitive: false);
  static var _eventStart = startIndex;
  static var _eventEnd = endIndex;
  static var _repeatThreshold = 0;
  static final filteredEvents = <Event>[];
  static late Future modStatusNetRequest;
  static var isLoading = false;

  static bool _passesFilter(Event event) {
    if (event.severity <= _severity && event.repeat >= _repeatThreshold) {
      return (_searchPattern.pattern.isEmpty || event.fullString.contains(_searchPattern))
          && (_excludePattern.pattern.isEmpty || !event.fullString.contains(_excludePattern));
    }
    return false;
  }

  static void _recalculateFilteredEvents() {
    filteredEvents.clear();
    final start = _eventStart;
    final end = max(_eventStart, events.length+_eventEnd);
    for (final event in events.sublist(start, end)) {
      if (_passesFilter(event)) {
        filteredEvents.add(event);
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
    final query = await DB.allMods();
    final toUpdate = <String>{};
    final now = DateTime.now();
    final cutOffDate = Settings.getCutOffDate();
    final deprecatedAndOldWhitelist = Settings.getDeprecatedAndOldWhitelist();
    final problematicModlist = Settings.getProblematicModlist();
    for (final mod in Logger.modManager.mods) {
      final entry = query[mod.fullName];
      if (entry != null) {
        final whitelisted = deprecatedAndOldWhitelist.contains(mod.fullName);
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
          final body = jsonDecode(response.body) as List;
          for (final tsMod in body) {
            final fullName = tsMod['full_name'];
            if (toUpdate.contains(fullName)) {
              final mod = Logger.modManager.getMod(fullName);
              if (mod != null) {
                final whitelisted = deprecatedAndOldWhitelist.contains(mod.fullName);
                mod.isDeprecated = !whitelisted && tsMod['is_deprecated'];
                mod.isOld = !whitelisted
                    && cutOffDate != null
                    && DateTime
                        .parse(tsMod['date_updated'])
                        .difference(cutOffDate)
                        .isNegative
                    && !mod.isDeprecated;
                mod.isProblematic = problematicModlist.contains(fullName);
                final entry = Entry(
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

  static void populateData(Map data) {
    _reset();
    if (data['success'] != true) {
      return;
    }
    for (final mod in data['mods']) {
      Logger.modManager.add(mod);
    }
    getAllModsStatus();
    Logger.summary.addAll(data['summary']);
    Logger.events.addAll(data['events']);
    Logger._recalculateFilteredEvents();
  }
}

class Diagnostics {
  static List<Event> dependencyIssues = [];
  static List<Event> modsCrashingOnAwake = [];
  static List<Event> hookFails = [];
  static List<Event> stuckLoading = [];
  static List<Event> missingMemberExceptions = [];
  static List<Event> mostCommonRecurrentErrors = [];

  static void _reset() {
    dependencyIssues.clear();
    modsCrashingOnAwake.clear();
    hookFails.clear();
    stuckLoading.clear();
    missingMemberExceptions.clear();
    mostCommonRecurrentErrors.clear();
  }

  static void analyse() {
    _reset();
    final missingDependency = RegExp(r'^Could not load \[.*\] because it has missing dependencies:');
    final incompatibleDependency = RegExp(r'^Could not load \[.*\] because it is incompatible with:');
    final chainLoaderPattern = RegExp(r'BepInEx.Bootstrap.Chainloader:Start\(\)');
    final stuckLoadingPattern = RegExp(r'UnityEngine.SetupCoroutine.InvokeMoveNext');
    final flawedHookPattern = RegExp(r'(MonoMod\.RuntimeDetour\.(IL)?Hook\.\.ctor|HarmonyLib\.PatchClassProcessor\.Patch)');
    final missingPattern = RegExp(r'^Missing(Field|Method)Exception');
    final encounteredExceptions = <String>{};
    final encounteredCommonErrors = <String, Event>{};
    var currentMod = '';
    for (final event in Logger.events) {
      if (event.modName != null) {
        currentMod = event.modName!;
      }
      if (missingDependency.firstMatch(event.string) != null || incompatibleDependency.firstMatch(event.string) != null) {
        dependencyIssues.add(event);
      }
      if (chainLoaderPattern.firstMatch(event.fullString) != null) {
        final eventCopy = Event.clone(event);
        eventCopy.fullString = '$currentMod\n${eventCopy.fullString}';
        modsCrashingOnAwake.add(eventCopy);
      }
      if (stuckLoadingPattern.firstMatch(event.fullString) != null) {
        stuckLoading.add(event);
      }
      if (flawedHookPattern.firstMatch(event.fullString) != null) {
        hookFails.add(event);
      }
      if (missingPattern.firstMatch(event.string) != null && !encounteredExceptions.contains(event.fullStringNoPrefix)) {
        missingMemberExceptions.add(event);
        encounteredExceptions.add(event.fullStringNoPrefix);
      }
      if (event.repeat > 0 && event.severity < 2) {
        if (!encounteredCommonErrors.containsKey(event.fullStringNoPrefix)) {
          encounteredCommonErrors[event.fullStringNoPrefix] = event;
        }
        else if (encounteredCommonErrors[event.fullStringNoPrefix]!.repeat < event.repeat) {
          encounteredCommonErrors[event.fullStringNoPrefix] = event;
        }
      }
    }
    mostCommonRecurrentErrors.addAll(encounteredCommonErrors.values);
    mostCommonRecurrentErrors.sort((event1, event2) => event2.repeat.compareTo(event1.repeat));
  }
}