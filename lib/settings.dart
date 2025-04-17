import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'log_parser.dart';

class Settings {
  static const keyUseCutOffDate = 'use_cut_off_date';
  static const keyCutOffDate = 'cut_off_date';
  static const keyDeprecatedAndOldWhitelist = 'deprecated_and_old_whitelist';
  static const keyProblematicModlist = 'problematic_modlist';
  static const keyConsoleEventMaxLines = 'console_event_max_lines';
  static const keyTextSizeCopyThreshold = 'text_size_copy_threshold';

  static late SharedPreferencesWithCache _prefs;
  static late bool _useCutOffDate;
  static DateTime? _cutOffDate;
  static late List<String> _deprecatedAndOldWhitelist;
  static late List<String> _problematicModlist;
  static late int _consoleEventMaxLines;
  static late int _textSizeCopyThreshold;

  static init() async {
    _prefs = await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions());
    _useCutOffDate = _prefs.getBool(keyUseCutOffDate) ?? false;
    _cutOffDate = DateTime.tryParse(_prefs.getString(keyCutOffDate) ?? '');
    _deprecatedAndOldWhitelist = _prefs.getStringList(keyDeprecatedAndOldWhitelist) ?? [];
    _problematicModlist = _prefs.getStringList(keyProblematicModlist) ?? [];
    _consoleEventMaxLines = _prefs.getInt(keyConsoleEventMaxLines) ?? 7;
    _textSizeCopyThreshold = _prefs.getInt(keyTextSizeCopyThreshold) ?? 2000;
  }

  static setUseCutOffDate(bool value) async {
    _useCutOffDate = value;
    await _prefs.setBool(keyUseCutOffDate, value);
    await Logger.getAllModsStatus();
  }

  static bool getUseCutOffDate() => _useCutOffDate;

  static setCutOffDate(DateTime? date) async {
    if (date != null) {
      _cutOffDate = date;
      await _prefs.setString(keyCutOffDate, date.toIso8601String());
      await Logger.getAllModsStatus();
    }
  }

  static DateTime? getCutOffDate() => _useCutOffDate ? _cutOffDate : null;

  static String getCutOffDateString() {
    if (_cutOffDate != null) {
      final d = _cutOffDate!;
      return '${d.year.toString()}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    }
    return 'N/A';
  }

  static setDeprecatedAndOldWhitelist(List<String> items) async {
    if (!listEquals(_deprecatedAndOldWhitelist, items)) {
      _deprecatedAndOldWhitelist = items;
      await _prefs.setStringList(keyDeprecatedAndOldWhitelist, items);
      await Logger.getAllModsStatus();
    }
  }

  static List<String> getDeprecatedAndOldWhitelist() => _deprecatedAndOldWhitelist;

  static setProblematicModlist(List<String> items) async {
    if (!listEquals(_problematicModlist, items)) {
      _problematicModlist = items;
      await _prefs.setStringList(keyProblematicModlist, items);
      await Logger.getAllModsStatus();
    }
  }

  static List<String> getProblematicModlist() => _problematicModlist;

  static setConsoleEventMaxLines(int value) async {
    if (value < 0) {
      value = 0;
    }
    _consoleEventMaxLines = value;
    await _prefs.setInt(keyConsoleEventMaxLines, value);
  }

  static int getConsoleEventMaxLines() => _consoleEventMaxLines;

  static setTextSizeCopyThreshold(int value) async {
    if (value < 0) {
      value = 0;
    }
    _textSizeCopyThreshold = value;
    await _prefs.setInt(keyTextSizeCopyThreshold, value);
  }

  static int getTextSizeCopyThreshold() => _textSizeCopyThreshold;
}