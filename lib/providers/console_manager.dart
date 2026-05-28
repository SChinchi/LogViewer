import 'dart:math';

import 'package:flutter/material.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/filters/exclude_filter.dart';
import 'package:log_viewer/filters/range_filter.dart';
import 'package:log_viewer/filters/repeat_filter.dart';
import 'package:log_viewer/models/event.dart';
import 'package:log_viewer/models/mod.dart';

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

    _rangeFilter.length = events.length;
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

  final _excludeFilter = ExcludeFilter();
  final _rangeFilter = RangeFilter(startIndex, endIndex);
  final _repeatFilter = RepeatFilter();
  final _allFilters = [
    ExcludeFilter.pattern.pattern,
    RangeFilter.pattern.pattern,
    RepeatFilter.pattern.pattern,
  ];
  late final _filterPattern = RegExp('^(${_allFilters.join('|')})*', caseSensitive: false);

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

  bool _tryUpdateExcludeFilter(String text) {
    _excludeFilter.update(text);
    final hasUpdated = _excludeFilter.regex.pattern != _excludePattern.pattern;
    _excludePattern = _excludeFilter.regex;
    return hasUpdated;
  }

  bool _tryUpdateRangeFilter(String text) {
    _rangeFilter.update(text);
    final hasUpdated = _rangeFilter.eventStart != _eventStart || _rangeFilter.eventEnd != _eventEnd;
    _eventStart = _rangeFilter.eventStart;
    _eventEnd = _rangeFilter.eventEnd;
    return hasUpdated;
  }

  bool _tryUpdateRepeatFilter(String text) {
    _repeatFilter.update(text);
    final hasUpdated = _repeatFilter.value != _repeatThreshold;
    _repeatThreshold = _repeatFilter.value;
    return hasUpdated;
  }

  void setSearchString(String s) {
    _searchString = s;
    var recalculateFilters = false;
    final filterMatches = _filterPattern.firstMatch(s);
    if (filterMatches != null) {
      final filters = filterMatches.group(0)!;
      recalculateFilters |= _tryUpdateExcludeFilter(filters);
      recalculateFilters |= _tryUpdateRangeFilter(filters);
      recalculateFilters |= _tryUpdateRepeatFilter(filters);
      s = s.substring(filters.length);
    }

    if (s != _searchPattern.pattern) {
      try {
        _searchPattern = RegExp(s, caseSensitive: false);
        recalculateFilters = true;
      } on FormatException {
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