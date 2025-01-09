import 'package:flutter/material.dart';
import 'package:log_viewer/constants.dart';

import '../log_parser.dart';
import '../settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _cutOffDateEnabled = Settings.getUseCutOffDate();
  final _whitelistTextController = TextEditingController();
  final _problematicTextController = TextEditingController();
  late String _whitelistOldText;
  late String _whitelistSubtitle;
  late String _problematicSubtitle;
  late String _problematicOldText;

  @override
  void initState() {
    var whitelist = Settings.getDeprecatedAndOldWhitelist();
    _whitelistOldText = whitelist.join('\n');
    _whitelistTextController.text = _whitelistOldText;
    _whitelistSubtitle = _countItems(whitelist);
    var problematic = Settings.getProblematicModlist();
    _problematicOldText = problematic.join('\n');
    _problematicTextController.text = _problematicOldText;
    _problematicSubtitle = _countItems(problematic);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        listTileTheme: const ListTileThemeData(
          titleTextStyle: TextStyle(color: Colors.white),
          subtitleTextStyle: TextStyle(color: Colors.grey)
        ),
        disabledColor: Colors.white30
      ),
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          title: const Text(Constants.settingsPage, style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: Colors.black
        ),
        backgroundColor: Colors.black,
        body: Center(child: Container(
          width: 800,
          color: Colors.black,
          child: ListView(children: [
            SettingsSection(
              title: 'Mod list',
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
                    }
                  ),
                  onTap: () async {
                    await Settings.setUseCutOffDate(!_cutOffDateEnabled);
                    setState(() {
                      _cutOffDateEnabled = !_cutOffDateEnabled;
                    });
                  }
                )
              ]
            ),
            ListTile(
              title: const Text('Set Old Mods Date'),
              subtitle: Text(Settings.getCutOffDateString()),
              enabled: _cutOffDateEnabled,
              onTap: () async {
                var date = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2019),
                  lastDate: DateTime.now(),
                  currentDate: Settings.getCutOffDate() ?? DateTime.now()
                );
                await Settings.setCutOffDate(date);
                setState(() {
                  Logger.modStatusNetRequest = Logger.getAllModsStatus();
                });
              }
            ),
            ListTile(
                title: const Text('Edit Deprecated/Old Mod Whitelist'),
                subtitle: Text(_whitelistSubtitle),
                onTap: () {
                  _whitelistOldText = _whitelistTextController.text;
                  showDialog(
                    context: context,
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
                              var modlist = _convertToInvariantList(_whitelistTextController.text);
                              _whitelistTextController.text = modlist.join('\n');
                              _whitelistSubtitle = _countItems(modlist);
                              Settings.setDeprecatedAndOldWhitelist(modlist);
                            });
                            Navigator.of(context).pop();
                          }
                      );
                    },
                  );
                }
            ),
            ListTile(
                title: const Text('Edit Problematic Mod list'),
                subtitle: Text(_problematicSubtitle),
                onTap: () {
                  _problematicOldText = _problematicTextController.text;
                  showDialog(
                    context: context,
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
                              var modlist = _convertToInvariantList(_problematicTextController.text);
                              _problematicTextController.text = modlist.join('\n');
                              _problematicSubtitle = _countItems(modlist);
                              Settings.setProblematicModlist(modlist);
                            });
                            Navigator.of(context).pop();
                          }
                      );
                    },
                  );
                }
            ),
          ])
        ))
      )
    );
  }

  static List<String> _convertToInvariantList(String text) {
    var lines = text.replaceAll(' ', '').split('\n').toSet();
    lines.remove('');
    var items = lines.toList();
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
    var tileList = ListView.builder(
      shrinkWrap: true,
      itemCount: tiles.length,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext context, int index) {
        return tiles[index];
      }
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
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold
            )
          )
        ),
        Container(child: tileList)
      ]
    );
  }
}

class MultilineTextDialog extends StatelessWidget {
  final String title;
  final TextEditingController textController;
  final VoidCallback onTapCancel;
  final VoidCallback onTapOK;

  const MultilineTextDialog({
    required this.title,
    required this.textController,
    required this.onTapCancel,
    required this.onTapOK,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
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
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: onTapOK,
          child: const Text('OK'),
        ),
      ],
    );
  }
}