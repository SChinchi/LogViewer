import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:log_viewer/database.dart';
import 'package:log_viewer/models/mod.dart';
import 'package:log_viewer/settings.dart';

enum ModCategory {
  // ignore: constant_identifier_names
  All,
  // ignore: constant_identifier_names
  Deprecated,
  // ignore: constant_identifier_names
  Old,
  // ignore: constant_identifier_names
  Problematic,
  // ignore: constant_identifier_names
  AI,
}

class ModManager extends ChangeNotifier {
  ModManager(Map<String, dynamic> data) {
    for (final modData in data['mods']) {
      final mod = List<String>.from(modData);
      add(Mod(mod[0], mod[1]));
    }
    updateModData();

    Settings.useModManifest.addListener(notifyListeners);
    Settings.useCutOffDate.addListener(updateModData);
    Settings.cutOffDate.addListener(updateModData);
    Settings.deprecatedAndOldWhitelist.addListener(updateModData);
    Settings.problematicModlist.addListener(updateModData);
    Settings.mentionAiMods.addListener(updateModData);
  }

  @override
  void dispose() {
    Settings.useModManifest.removeListener(notifyListeners);
    Settings.useCutOffDate.removeListener(updateModData);
    Settings.cutOffDate.removeListener(updateModData);
    Settings.deprecatedAndOldWhitelist.removeListener(updateModData);
    Settings.problematicModlist.removeListener(updateModData);
    Settings.mentionAiMods.removeListener(updateModData);
    mods.clear();
    filteredMods.clear();
    super.dispose();
  }

  final mods = <Mod>[];
  final filteredMods = <Mod>[];
  var isInSelectionMode = false;
  // Some mods contain multiple plugins, which are loaded individually
  // but refer to the same manifest name.
  final _nameToMod = <String, List<Mod>>{};

  var _category = ModCategory.All;
  set category(ModCategory value)
  {
    if (_category == value) {
      return;
    }
    _category = value;
    _recalculateFilteredMods();
  }
  ModCategory get category => _category;

  var _searchString = RegExp('', caseSensitive: false);
  set searchString(String value) {
    if (value != _searchString.pattern) {
      try {
        _searchString = RegExp(value, caseSensitive: false);
        _recalculateFilteredMods();
      } on FormatException catch (_) {
        // Capturing each keystroke of the search means an invalid regex is possible
      }
    }
  }
  String get searchString => _searchString.pattern;

  bool _passesFilter(Mod mod) {
    if (_category == ModCategory.All
        || (_category == ModCategory.Deprecated && mod.isDeprecated)
        || (_category == ModCategory.Old && mod.isOld && !mod.isDeprecated)
        || (_category == ModCategory.Problematic && mod.isProblematic)
        || (_category == ModCategory.AI && mod.isAi)) {
      return _searchString.pattern.isEmpty || mod.name.contains(_searchString);
    }
    return false;
  }

  void _recalculateFilteredMods() {
    filteredMods.clear();
    for (final mod in mods) {
      if (_passesFilter(mod)) {
        filteredMods.add(mod);
      }
    }
    notifyListeners();
  }

  void add(Mod mod) {
    mod.index = mods.length;
    mods.add(mod);
    if (_passesFilter(mod)) {
      filteredMods.add(mod);
    }
    if (!_nameToMod.containsKey(mod.fullName)) {
      _nameToMod[mod.fullName] = [];
    }
    _nameToMod[mod.fullName]!.add(mod);
  }

  List<Mod>? getModPlugins(String name) {
    return _nameToMod[name];
  }

  void toggleSelected(Mod mod) {
    mod.isSelected = !mod.isSelected;
    isInSelectionMode = mods.any((m) => m.isSelected);
    notifyListeners();
  }

  void clearSelections() {
    if (isInSelectionMode) {
      for (final mod in mods) {
        mod.isSelected = false;
      }
      isInSelectionMode = false;
      notifyListeners();
    }
  }

  void _updateAmbiguousMods() {
    final problematicModlist = Settings.problematicModlist.value;
    for (final mod in mods) {
      if (!mod.hasManifest || _nameToMod[mod.fullName]!.length > 1) {
        // Manual mods are not updated when we fetch Thunderstore data, so we do it... manually
        mod.isProblematic = problematicModlist.contains(mod.guid) || !mod.hasManifestEffective;
        mod.isUnique = false;
      }
    }
  }

  Future updateModData() async {
    await DB.init();
    final query = await DB.allMods();
    final toUpdate = <String>{};
    final now = DateTime.now();
    final cutOffDate = Settings.cutOffDateEffective;
    final deprecatedAndOldWhitelist = Settings.deprecatedAndOldWhitelist.value;
    final problematicModlist = Settings.problematicModlist.value;
    for (final mod in mods) {
      final entry = query[mod.fullName];
      if (entry != null) {
        final whitelisted = deprecatedAndOldWhitelist.contains(mod.fullName);
        final categories = entry.categories;
        mod.isDeprecated = !whitelisted && entry.isDeprecated == 1;
        mod.isOld = !whitelisted
            && cutOffDate != null
            && DateTime
                .parse(entry.dateTs)
                .difference(cutOffDate)
                .isNegative
            && !mod.isDeprecated;
        if (now
            .difference(DateTime.parse(entry.dateDb))
            .inHours > 1 || entry.latestVersion == null) {
          toUpdate.add(mod.fullName);
        } else {
          mod.isLatestVersion = mod.version.toString() == entry.latestVersion;
        }
        mod.isProblematic = problematicModlist.contains(mod.guid) || !mod.hasManifestEffective;
        if (categories == null) {
          toUpdate.add(mod.fullName);
        } else {
          mod.categories = categories.split(';');
        }
      } else {
        toUpdate.add(mod.fullName);
      }
    }

    // Update the UI now for any mods where the database suffices.
    // And if we make an http request, we will have another update later.
    _updateAmbiguousMods();
    _recalculateFilteredMods();
    notifyListeners();

    if (toUpdate.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse('https://thunderstore.io/api/v1/package/'));
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as List;
          for (final tsMod in body) {
            final fullName = tsMod['full_name'];
            if (toUpdate.contains(fullName)) {
              final modPlugins = getModPlugins(fullName);
              if (modPlugins != null) {
                final latestVersion = tsMod['versions'].first['version_number'];
                final categories = (tsMod['categories'] as List).cast<String>();
                for (final mod in modPlugins) {
                  final whitelisted = deprecatedAndOldWhitelist.contains(mod.fullName);
                  mod.isDeprecated = !whitelisted && tsMod['is_deprecated'];
                  mod.isOld = !whitelisted
                      && cutOffDate != null
                      && DateTime
                          .parse(tsMod['date_updated'])
                          .difference(cutOffDate)
                          .isNegative
                      && !mod.isDeprecated;
                  mod.isProblematic = problematicModlist.contains(mod.guid) || !mod.hasManifestEffective;
                  mod.isLatestVersion = mod.version.toString() == latestVersion;
                  mod.categories = categories;
                }
                final entry = Entry(
                  fullName: fullName,
                  dateTs: tsMod['date_updated'],
                  dateDb: now.toIso8601String(),
                  isDeprecated: tsMod['is_deprecated'] ? 1 : 0,
                  latestVersion: latestVersion,
                  categories: categories.join(';'),
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
      } on Exception catch (_) {
        // Fallback to assigning any old values we still have in the database
        for (final fullName in toUpdate) {
          final entry = query[fullName];
          if (entry != null) {
            final modPlugins = getModPlugins(fullName);
            if (modPlugins != null) {
              final categories = entry.categories?.split(';') ?? [];
              for (final mod in modPlugins) {
                final whitelisted = deprecatedAndOldWhitelist.contains(mod.fullName);
                mod.isDeprecated = !whitelisted && entry.isDeprecated == 1;
                mod.isOld = !whitelisted
                    && cutOffDate != null
                    && DateTime
                        .parse(entry.dateTs)
                        .difference(cutOffDate)
                        .isNegative
                    && !mod.isDeprecated;
                mod.isProblematic = problematicModlist.contains(mod.guid) || !mod.hasManifestEffective;
                mod.isLatestVersion = mod.version.toString() == entry.latestVersion;
                mod.categories = categories;
              }
            }
          }
        }
      } finally {
        _updateAmbiguousMods();
        _recalculateFilteredMods();
        notifyListeners();
      }
    }
  }
}