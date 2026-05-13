import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger.dart';

class Settings {
  static const keyUseModManifest = 'use_mod_manifest';
  static const keyUseCutOffDate = 'use_cut_off_date';
  static const keyCutOffDate = 'cut_off_date';
  static const keyDeprecatedAndOldWhitelist = 'deprecated_and_old_whitelist';
  static const keyProblematicModlist = 'problematic_modlist';
  static const keyConsoleEventMaxLines = 'console_event_max_lines';
  static const keyTextSizeCopyThreshold = 'text_size_copy_threshold';

  static late final SharedPreferencesWithCache _prefs;
  static late final ValueNotifier<bool> useModManifest;
  static late final ValueNotifier<bool> useCutOffDate;
  static late final ValueNotifier<DateTime?> cutOffDate;
  static late final ValueNotifier<List<String>> deprecatedAndOldWhitelist;
  static late final ValueNotifier<List<String>> problematicModlist;
  static late final ValueNotifier<int> consoleEventMaxLines;
  static late final ValueNotifier<int> textSizeCopyThreshold;

  static DateTime? get cutOffDateEffective => useCutOffDate.value ? cutOffDate.value : null;

  static String get cutOffDateString {
    if (cutOffDate.value != null) {
      final d = cutOffDate.value!;
      return '${d.year.toString()}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    }
    return 'N/A';
  }

  static Future<void> init() async {
    _prefs = await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions());
    useModManifest = ValueNotifier(_prefs.getBool(keyUseModManifest) ?? true);
    useCutOffDate = ValueNotifier(_prefs.getBool(keyUseCutOffDate) ?? false);
    cutOffDate = ValueNotifier(DateTime.tryParse(_prefs.getString(keyCutOffDate) ?? ''));
    deprecatedAndOldWhitelist = ValueNotifier(_prefs.getStringList(keyDeprecatedAndOldWhitelist) ?? []);
    problematicModlist = ValueNotifier(_prefs.getStringList(keyProblematicModlist) ?? []);
    consoleEventMaxLines = ValueNotifier(_prefs.getInt(keyConsoleEventMaxLines) ?? 7);
    textSizeCopyThreshold = ValueNotifier(_prefs.getInt(keyTextSizeCopyThreshold) ?? 2000);

    useModManifest.addListener(Diagnostics.rebuildModsCrashingOnAwake);
  }

  static Future<void> setUseModManifest(bool value) async {
    if (useModManifest.value != value) {
      useModManifest.value = value;
      await _prefs.setBool(keyUseModManifest, value);
    }
  }

  static Future<void> setUseCutOffDate(bool value) async {
    if (useCutOffDate.value != value) {
      useCutOffDate.value = value;
      await _prefs.setBool(keyUseCutOffDate, value);
      await Logger.getAllModsStatus();
    }
  }

  static Future<void> setCutOffDate(DateTime? date) async {
    if (date != null) {
      cutOffDate.value = date;
      await _prefs.setString(keyCutOffDate, date.toIso8601String());
      await Logger.getAllModsStatus();
    }
  }

  static Future<void> setDeprecatedAndOldWhitelist(List<String> items) async {
    if (!listEquals(deprecatedAndOldWhitelist.value, items)) {
      deprecatedAndOldWhitelist.value = items;
      await _prefs.setStringList(keyDeprecatedAndOldWhitelist, items);
      await Logger.getAllModsStatus();
    }
  }

  static Future<void> setProblematicModlist(List<String> items) async {
    if (!listEquals(problematicModlist.value, items)) {
      problematicModlist.value = items;
      await _prefs.setStringList(keyProblematicModlist, items);
      await Logger.getAllModsStatus();
    }
  }

  static Future<void> setConsoleEventMaxLines(int value) async {
    if (value < 0) {
      value = 0;
    }
    if (consoleEventMaxLines.value != value) {
      consoleEventMaxLines.value = value;
      await _prefs.setInt(keyConsoleEventMaxLines, value);
    }
  }

  static Future<void> setTextSizeCopyThreshold(int value) async {
    if (value < 0) {
      value = 0;
    }
    if (textSizeCopyThreshold.value != value) {
      textSizeCopyThreshold.value = value;
      await _prefs.setInt(keyTextSizeCopyThreshold, value);
    }
  }
}