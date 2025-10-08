import 'package:flutter/foundation.dart';

class Mod {
  String guid;
  late String fullName;
  late Version version;
  late int index;
  bool isDeprecated = false;
  bool isOld = false;
  bool isProblematic = false;
  bool isSelected = false;
  bool isLatestVersion = true;

  Mod(this.guid) {
    var pattern = RegExp(r'^(.*)-(\d+).(\d+).(\d+)');
    var name = pattern.firstMatch(guid);
    if (name != null) {
      fullName = name.group(1)!;
      version = Version(name.group(2)!, name.group(3)!, name.group(4)!);
    }
    else {
      fullName = guid;
      version = Version('1', '0', '0');
    }
  }
}

class Version {
  final String major;
  final String minor;
  final String patch;

  Version(this.major, this.minor, this.patch);

  @override
  String toString() {
    return '$major.$minor.$patch';
  }
}

enum ModCategory {
  // ignore: constant_identifier_names
  All,
  // ignore: constant_identifier_names
  Deprecated,
  // ignore: constant_identifier_names
  Old,
  // ignore: constant_identifier_names
  Problematic,
}

class ModManager with ChangeNotifier {
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
    recalculateFilteredMods();
  }
  ModCategory get category => _category;

  var _searchString = RegExp('', caseSensitive: false);
  set searchString(String value) {
    if (value != _searchString.pattern) {
      try {
        _searchString = RegExp(value, caseSensitive: false);
        recalculateFilteredMods();
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
        || (_category == ModCategory.Problematic && mod.isProblematic)) {
      return _searchString.pattern.isEmpty || mod.guid.contains(_searchString);
    }
    return false;
  }

  void recalculateFilteredMods() {
    filteredMods.clear();
    for (final mod in mods) {
      if (_passesFilter(mod)) {
        filteredMods.add(mod);
      }
    }
    notifyListeners();
  }

  void reset() {
    mods.clear();
    filteredMods.clear();
    isInSelectionMode = false;
    _nameToMod.clear();
    _category = ModCategory.All;
    _searchString = RegExp('', caseSensitive: false);
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
    final oldMode = mods.any((m) => m.isSelected);
    mod.isSelected = !mod.isSelected;
    final newMode = mods.any((m) => m.isSelected);
    if (oldMode != newMode) {
      isInSelectionMode = newMode;
      notifyListeners();
    }
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

  @override
  // ignore: must_call_super
  void dispose() {}
}