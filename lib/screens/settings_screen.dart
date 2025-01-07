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
            )
          ])
        ))
      )
    );
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