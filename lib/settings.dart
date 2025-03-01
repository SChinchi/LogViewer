import 'package:flutter/foundation.dart';
import 'package:log_viewer/log_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  static const KEY_USE_CUT_OFF_DATE = 'use_cut_off_date';
  static const KEY_CUT_OFF_DATE = 'cut_off_date';
  static const KEY_DEPRECATED_AND_OLD_WHITELIST = 'deprecated_and_old_whitelist';
  static const KEY_PROBLEMATIC_MODLIST = 'problematic_modlist';
  static const KEY_CONSOLE_EVENT_MAX_LINES = 'console_event_max_lines';

  static late SharedPreferencesWithCache _prefs;
  static late bool _useCutOffDate;
  static DateTime? _cutOffDate;
  static late List<String> _deprecatedAndOldWhitelist;
  static late List<String> _problematicModlist;
  static late int _consoleEventMaxLines;

  static init() async {
    _prefs = await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions());
    _useCutOffDate = _prefs.getBool(KEY_USE_CUT_OFF_DATE) ?? false;
    _cutOffDate = DateTime.tryParse(_prefs.getString(KEY_CUT_OFF_DATE) ?? '');
    _deprecatedAndOldWhitelist = _prefs.getStringList(KEY_DEPRECATED_AND_OLD_WHITELIST) ?? [];
    _problematicModlist = _prefs.getStringList(KEY_PROBLEMATIC_MODLIST) ?? [];
    _consoleEventMaxLines = _prefs.getInt(KEY_CONSOLE_EVENT_MAX_LINES) ?? 7;
  }

  static setUseCutOffDate(bool value) async {
    _useCutOffDate = value;
    await _prefs.setBool(KEY_USE_CUT_OFF_DATE, value);
    await Logger.getAllModsStatus();
  }

  static bool getUseCutOffDate() => _useCutOffDate;

  static setCutOffDate(DateTime? date) async {
    if (date != null) {
      _cutOffDate = date;
      await _prefs.setString(KEY_CUT_OFF_DATE, date.toIso8601String());
      await Logger.getAllModsStatus();
    }
  }

  static DateTime? getCutOffDate() => _useCutOffDate ? _cutOffDate : null;

  static getCutOffDateString() {
    if (_cutOffDate != null) {
      var d = _cutOffDate!;
      return '${d.year.toString()}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    }
    return 'N/A';
  }

  static setDeprecatedAndOldWhitelist(List<String> items) async {
    if (!listEquals(_deprecatedAndOldWhitelist, items)) {
      _deprecatedAndOldWhitelist = items;
      await _prefs.setStringList(KEY_DEPRECATED_AND_OLD_WHITELIST, items);
      await Logger.getAllModsStatus();
    }
  }

  static List<String> getDeprecatedAndOldWhitelist() => _deprecatedAndOldWhitelist;

  static setProblematicModlist(List<String> items) async {
    if (!listEquals(_problematicModlist, items)) {
      _problematicModlist = items;
      await _prefs.setStringList(KEY_PROBLEMATIC_MODLIST, items);
      await Logger.getAllModsStatus();
    }
  }

  static List<String> getProblematicModlist() => _problematicModlist;

  static setConsoleEventMaxLines(int value) async {
    if (value < 0) {
      value = 0;
    }
    _consoleEventMaxLines = value;
    await _prefs.setInt(KEY_CONSOLE_EVENT_MAX_LINES, value);
  }

  static int getConsoleEventMaxLines() => _consoleEventMaxLines;
}