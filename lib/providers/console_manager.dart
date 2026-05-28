import 'dart:math';

import 'package:flutter/material.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/models/event.dart';
import 'package:log_viewer/models/mod.dart';

final _consoleSearchFilterPattens = [
  r'\s*(?<exclude>exclude:(?<exclude_term>\(.*\)|[^(\s]\S*))\s*',
  r'\s*(?<range>range:(?<r0>-?\d*)\.\.(?<r1>-?\d*))\s*',
  r'\s*(?<repeat>repeat:(?<repeat_num>\d+))\s*'
];

class ConsoleManager extends ChangeNotifier {
  ConsoleManager(Map<String, dynamic> data, List<Mod> mods) {
    _mods = mods;
    if (data['success'] != true) {
      summary = [];
      return;
    }
    for (final event in data['events']) {
      events.add(Event.fromJson(event));
    }
    filteredEvents.addAll(events);
    summary = data['summary'];
  }

  @override
  void dispose() {
    for (final event in events) {
      event.dispose();
    }
    events.clear();
    filteredEvents.clear();
    super.dispose();
  }

  static final _filterPattern = RegExp('^(${_consoleSearchFilterPattens.join('|')})', caseSensitive: false);

  static const intMin = ~(-1 >>> 1);
  static const startIndex = 0;
  static const endIndex = 0;

  final events = <Event>[];
  final filteredEvents = <Event>[];
  late final List<dynamic> summary;
  late final List<Mod> _mods;

  var _severity = Constants.logSeverity.length - 1;
  var _searchString = '';
  var _searchPattern = RegExp('', caseSensitive: false);
  var _excludePattern = RegExp('', caseSensitive: false);
  var _eventStart = startIndex;
  var _eventEnd = endIndex;
  var _repeatThreshold = 0;
  var _eventIndexTarget = -1;
  var _eventTargetRevision = 0;

  bool _passesFilter(Event event) {
    if (event.severity <= _severity && event.repeat >= _repeatThreshold) {
      return (_searchPattern.pattern.isEmpty || event.fullString.contains(_searchPattern))
          && (_excludePattern.pattern.isEmpty || !event.fullString.contains(_excludePattern));
    }
    return false;
  }

  void _recalculateFilteredEvents() {
    filteredEvents.clear();
    final start = _eventStart;
    final end = max(_eventStart, events.length+_eventEnd);
    for (final event in events.sublist(start, end)) {
      if (_passesFilter(event)) {
        filteredEvents.add(event);
      }
    }
    notifyListeners();
  }

  void _resetSearchData() {
    _severity = Constants.logSeverity.length - 1;
    _searchString = '';
    _searchPattern = RegExp(_searchString, caseSensitive: false);
    _excludePattern = RegExp('', caseSensitive: false);
    _eventStart = startIndex;
    _eventEnd = endIndex;
    _repeatThreshold = 0;
  }

  void setSeverity(int num) {
    if (_severity == num) {
      return;
    }
    _severity = num;
    _recalculateFilteredEvents();
  }

  int getSeverity() {
    return _severity;
  }

  void setSearchString(String s) {
    _searchString = s;
    s = s.toLowerCase();
    var recalculateFilters = false;
    var match = _filterPattern.firstMatch(s);
    final matches = <String, List<String?>>{};
    while (match != null) {
      if (match.namedGroup('exclude') != null) {
        matches['exclude'] = [match.namedGroup('exclude_term')];
      } else if (match.namedGroup('range') != null) {
        matches['range'] = [match.namedGroup('r0'), match.namedGroup('r1')];
      } else if (match.namedGroup('repeat') != null) {
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
      } on FormatException catch (_) {
        // Capturing each keystroke of the search means an invalid regex is possible
      }
    } else {
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
    } else {
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
    } else {
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

  String getSearchString() {
    return _searchString;
  }

  void setEventTarget(int index) {
    if (index >= 0 && index < events.length) {
      _eventTargetRevision++;
      _eventIndexTarget = index;
      _resetSearchData();
      filteredEvents.clear();
      filteredEvents.addAll(events);
      notifyListeners();
    }
  }

  void resetEventTarget() {
    _eventIndexTarget = -1;
  }

  int get eventTarget => _eventIndexTarget;

  bool get hasValidEventTarget => _eventIndexTarget >= 0 && _eventIndexTarget < filteredEvents.length;

  int get eventTargetRevision => _eventTargetRevision;

  Mod? getEventRelatedMod(Event event) {
    if (event.modIndex != null) {
      if (event.modIndex! >= 0 && event.modIndex! < _mods.length) {
        return _mods[event.modIndex!];
      }
    }
    return null;
  }
}