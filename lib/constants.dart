class Constants {
  static const appTitle = 'BepInEx Log Viewer';
  static const titleTab_1 = 'Summary';
  static const titleTab_2 = 'Mod list';
  static const titleTab_3 = 'Console';
  static const titleTab_4 = 'Diagnostics';
  static const dropText = 'Drop file';
  static const loadButton = 'Open file';
  static const parseError = 'Failed to parse file; empty or not a log.';
  static const searchText = 'Search';

  static const logSeverity = [
    'Fatal',
    'Error',
    'Warning',
    'Message',
    'Debug',
    'Info'
  ];

  static const settingsPage = 'Settings';
  static const menuOptions = [settingsPage];
  static const selectionOptions = [
    'Add to deprecated/old whitelist',
    'Remove from deprecated/old whitelist',
    'Add to problematic list',
    'Remove from problematic list',
  ];

  static const zipHeader = [80, 75, 3, 4];
}