import 'package:log_viewer/constants.dart';
import 'package:log_viewer/settings.dart';

class Mod {
  static final _versionPattern = RegExp(r'^(.*)-(\d+).(\d+).(\d+)');

  late final String guid;
  late final String bepInName;
  late final String fullName;
  late final Version version;
  late final int index;
  int labels = ModLabel.none;

  List<String> get categories => _categories;
  set categories(List<String> value) {
    _categories = value;
    isAi = value.contains('AI Generated');
  }
  List<String> _categories = [];

  bool get isDeprecated => labels & ModLabel.deprecated > 0;
  set isDeprecated(bool value) {
    if (value) {
      labels |= ModLabel.deprecated;
    } else {
      labels &= ~ModLabel.deprecated;
    }
  }

  bool get isOld => labels & ModLabel.old > 0;
  set isOld(bool value) {
    if (value) {
      labels |= ModLabel.old;
    } else {
      labels &= ~ModLabel.old;
    }
  }

  bool get isProblematic => labels & ModLabel.problematic > 0;
  set isProblematic(bool value) {
    if (value) {
      labels |= ModLabel.problematic;
    } else {
      labels &= ~ModLabel.problematic;
    }
  }

  bool get isAi => labels & ModLabel.ai > 0;
  set isAi(bool value) {
    if (Settings.mentionAiMods.value && value) {
      labels |= ModLabel.ai;
    } else {
      labels &= ~ModLabel.ai;
    }
  }

  bool isSelected = false;
  bool isLatestVersion = true;
  bool isUnique = true;

  Mod(this.guid, this.bepInName) {
    final name = _versionPattern.firstMatch(guid);
    if (name != null) {
      fullName = name.group(1)!;
      version = Version(name.group(2)!, name.group(3)!, name.group(4)!);
    } else {
      fullName = guid;
      version = Version('1', '0', '0');
    }
  }

  String get name {
    if (Settings.useModManifest.value) {
      return isUnique ? guid : '$guid [$bepInName]';
    }
    return bepInName;
  }

  bool get hasManifest => guid != Constants.noManifestModName;
  bool get hasManifestEffective => !Settings.useModManifest.value || hasManifest;
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

class ModLabel {
  static const none = 0;
  static const deprecated = 1 << 0;
  static const old = 1 << 1;
  static const problematic = 1 << 2;
  static const ai = 1 << 3;
}