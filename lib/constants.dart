class Constants {
  static const dbName = 'mods.db';
  static const tableName = 'mods';

  static const appTitle = 'BepInEx Log Viewer';
  static const titleTabSummary = 'Summary';
  static const titleTabMods = 'Mod list';
  static const titleTabConsole = 'Console';
  static const titleTabDiagnostics = 'Diagnostics';

  static const dropText = 'Drop file';
  static const loadButton = 'Open file';
  static const parseError = 'Failed to parse file; empty or not a log.';
  static const searchText = 'Search';
  static const buttonOk = 'OK';
  static const buttonCancel = 'Cancel';

  static const logSeverity = [
    'Fatal',
    'Error',
    'Warning',
    'Message',
    'Debug',
    'Info'
  ];

  static const diagnosticsDependencies = 'Missing Dependencies & Incompatibilities';
  static const diagnosticsCrashingMods = 'Mods Crashing On Awake';
  static const diagnosticsBadHooks = 'Flawed Code Modifications';
  static const diagnosticsStuckLoading = 'Stuck Loading x%';
  static const diagnosticsMissingMember = 'Missing Member Exception';
  static const diagnosticsRepeatErrors = 'Most Spammed Errors';

  static const settingsPage = 'Settings';
  static const menuOptions = [settingsPage];
  static const selectionOptions = [
    'Add to deprecated/old whitelist',
    'Remove from deprecated/old whitelist',
    'Add to problematic list',
    'Remove from problematic list',
  ];

  static const settingsSectionMods = 'Mod list';
  static const settingsSectionConsole = 'Console';

  static const zipHeader = [80, 75, 3, 4];

  static const tempCopyFilename = 'message.txt';
}