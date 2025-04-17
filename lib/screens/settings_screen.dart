import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/log_parser.dart';
import 'package:log_viewer/settings.dart';
import 'package:log_viewer/themes/themes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _cutOffDateEnabled = Settings.getUseCutOffDate();
  final _whitelistTextController = TextEditingController();
  final _problematicTextController = TextEditingController();
  final _collapsibleTextController = TextEditingController();
  final _textSizeThresholdTextController = TextEditingController();
  late String _whitelistOldText;
  late String _whitelistSubtitle;
  late String _problematicSubtitle;
  late String _problematicOldText;
  late int _collapsibleThreshold;
  late int _textSizeThreshold;

  @override
  void initState() {
    final whitelist = Settings.getDeprecatedAndOldWhitelist();
    _whitelistOldText = whitelist.join('\n');
    _whitelistTextController.text = _whitelistOldText;
    _whitelistSubtitle = _countItems(whitelist);
    final problematic = Settings.getProblematicModlist();
    _problematicOldText = problematic.join('\n');
    _problematicTextController.text = _problematicOldText;
    _problematicSubtitle = _countItems(problematic);
    _collapsibleThreshold = Settings.getConsoleEventMaxLines();
    _textSizeThreshold = Settings.getTextSizeCopyThreshold();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme.copyWith(
        listTileTheme: const ListTileThemeData(
          subtitleTextStyle: TextStyle(color: Colors.grey),
        ),
        disabledColor: AppTheme.disabledColor,
      ),
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(Constants.settingsPage),
          ),
          body: Center(
            child: SizedBox(
              width: 800,
              child: ListView(
                children: [
                  SettingsSection(
                    title: Constants.settingsSectionMods,
                    tiles: [
                      ListTile(
                        title: const Text('Use Old Date Threshold'),
                        trailing: Switch(
                          value: _cutOffDateEnabled,
                          onChanged: (bool value) async {
                            await Settings.setUseCutOffDate(value);
                            setState(() {
                              _cutOffDateEnabled = value;
                            });
                          },
                        ),
                        onTap: () async {
                          await Settings.setUseCutOffDate(!_cutOffDateEnabled);
                          setState(() {
                            _cutOffDateEnabled = !_cutOffDateEnabled;
                          });
                        },
                      ),
                      ListTile(
                        title: const Text('Set Old Mods Date'),
                        subtitle: Text(Settings.getCutOffDateString()),
                        enabled: _cutOffDateEnabled,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2019),
                            lastDate: DateTime.now(),
                            currentDate: Settings.getCutOffDate() ?? DateTime.now(),
                          );
                          await Settings.setCutOffDate(date);
                          setState(() {
                            Logger.modStatusNetRequest = Logger.getAllModsStatus();
                          });
                        },
                      ),
                      ListTile(
                        title: const Text('Edit Deprecated/Old Mod Whitelist'),
                        subtitle: Text(_whitelistSubtitle),
                        onTap: () {
                          _whitelistOldText = _whitelistTextController.text;
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return MultilineTextDialog(
                                title: 'Deprecated/Old Mod Whitelist',
                                textController: _whitelistTextController,
                                onTapCancel: () {
                                  _whitelistTextController.text = _whitelistOldText;
                                  Navigator.of(context).pop();
                                },
                                onTapOK: () {
                                  setState(() {
                                    final modlist = _convertToInvariantList(_whitelistTextController.text);
                                    _whitelistTextController.text = modlist.join('\n');
                                    _whitelistSubtitle = _countItems(modlist);
                                    Settings.setDeprecatedAndOldWhitelist(modlist);
                                  });
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                          );
                        },
                      ),
                      ListTile(
                        title: const Text('Edit Problematic Mod list'),
                        subtitle: Text(_problematicSubtitle),
                        onTap: () {
                          _problematicOldText = _problematicTextController.text;
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return MultilineTextDialog(
                                title: 'Problematic Mod List',
                                textController: _problematicTextController,
                                onTapCancel: () {
                                  _problematicTextController.text = _problematicOldText;
                                  Navigator.of(context).pop();
                                },
                                onTapOK: () {
                                  setState(() {
                                    final modlist = _convertToInvariantList(_problematicTextController.text);
                                    _problematicTextController.text = modlist.join('\n');
                                    _problematicSubtitle = _countItems(modlist);
                                    Settings.setProblematicModlist(modlist);
                                  });
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: Constants.settingsSectionConsole,
                    tiles: [
                      ListTile(
                        title: const Text('Collapsible Console Line Threshold'),
                        subtitle: Text(_collapsibleThreshold > 0 ? _collapsibleThreshold.toString() : 'None'),
                        onTap: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return NumberDialog(
                                title: 'Set Limit (0 for None)',
                                textController: _collapsibleTextController,
                                onFieldSubmitted: (value) {
                                  setState(() {
                                    _collapsibleThreshold = int.parse(_collapsibleTextController.text);
                                    _collapsibleTextController.text = '';
                                    Settings.setConsoleEventMaxLines(_collapsibleThreshold);
                                  });
                                  Navigator.pop(context);
                                },
                                onTapCancel: () {
                                  _collapsibleTextController.text = '';
                                  Navigator.pop(context);
                                },
                                onTapOK: () {
                                  setState(() {
                                    _collapsibleThreshold = int.parse(_collapsibleTextController.text);
                                    _collapsibleTextController.text = '';
                                    Settings.setConsoleEventMaxLines(_collapsibleThreshold);
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                      ),
                      ListTile(
                        title: const Text('Copy To File If Text Longer Than'),
                        subtitle: Text(_textSizeThreshold > 0 ? _textSizeThreshold.toString() : 'None'),
                        onTap: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return NumberDialog(
                                title: 'Set Threshold (0 for None)',
                                textController: _textSizeThresholdTextController,
                                onFieldSubmitted: (value) {
                                  setState(() {
                                    _textSizeThreshold = int.parse(_textSizeThresholdTextController.text);
                                    _textSizeThresholdTextController.text = '';
                                    Settings.setTextSizeCopyThreshold(_textSizeThreshold);
                                  });
                                  Navigator.pop(context);
                                },
                                onTapCancel: () {
                                  _textSizeThresholdTextController.text = '';
                                  Navigator.pop(context);
                                },
                                onTapOK: () {
                                  setState(() {
                                    _textSizeThreshold = int.parse(_textSizeThresholdTextController.text);
                                    _textSizeThresholdTextController.text = '';
                                    Settings.setTextSizeCopyThreshold(_textSizeThreshold);
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static List<String> _convertToInvariantList(String text) {
    final lines = text.replaceAll(' ', '').split('\n').toSet();
    lines.remove('');
    final items = lines.toList();
    items.sort();
    return items;
  }

  static String _countItems(List<String> items) {
    if (items.isEmpty) {
      return 'Empty';
    }
    if (items.length == 1) {
      return '1 mod';
    }
    return '${items.length} mods';
  }
}

class SettingsSection extends StatelessWidget {
  final List<ListTile> tiles;
  final String? title;

  const SettingsSection({
    required this.tiles,
    this.title,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    final tileList = ListView.builder(
      shrinkWrap: true,
      itemCount: tiles.length,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext context, int index) {
        return tiles[index];
      },
    );

    if (title == null) {
      return tileList;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 0, 0),
          child: Text(title!,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(child: tileList),
      ],
    );
  }
}

class MultilineTextDialog extends StatelessWidget {
  final String title;
  final TextEditingController textController;
  final VoidCallback onTapCancel;
  final VoidCallback onTapOK;

  const MultilineTextDialog({
    super.key,
    required this.title,
    required this.textController,
    required this.onTapCancel,
    required this.onTapOK,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      backgroundColor: AppTheme.dialogBackgroundColor,
      content: TextField(
        controller: textController,
        maxLines: null,
        expands: true,
        keyboardType: TextInputType.multiline,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: onTapCancel,
          child: const Text(Constants.buttonCancel),
        ),
        TextButton(
          onPressed: onTapOK,
          child: const Text(Constants.buttonOk),
        ),
      ],
    );
  }
}

class NumberDialog extends StatelessWidget {
  final String title;
  final TextEditingController textController;
  final ValueChanged<String> onFieldSubmitted;
  final VoidCallback onTapCancel;
  final VoidCallback onTapOK;

  const NumberDialog({
    super.key,
    required this.title,
    required this.textController,
    required this.onFieldSubmitted,
    required this.onTapCancel,
    required this.onTapOK,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      backgroundColor: AppTheme.dialogBackgroundColor,
      content: TextFormField(
        controller: textController,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
          FilteringTextInputFormatter.digitsOnly
        ],
        onFieldSubmitted: onFieldSubmitted,
        maxLines: 1,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: onTapCancel,
          child: const Text(Constants.buttonCancel),
        ),
        TextButton(
            onPressed: onTapOK,
            child: const Text(Constants.buttonOk)
        ),
      ],
    );
  }
}