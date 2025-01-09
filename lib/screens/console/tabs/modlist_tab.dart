import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:log_viewer/constants.dart';
import 'package:log_viewer/log_parser.dart';

class ModListPage extends StatelessWidget {
  final TabController tabController;

  const ModListPage({super.key, required this.tabController});

  @override
  Widget build(BuildContext context) {
    return const FutureBuilderExampleApp();
  }
}

class FutureBuilderExampleApp extends StatelessWidget {
  const FutureBuilderExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
      return const FutureBuilderExample();
  }
}

class FutureBuilderExample extends StatefulWidget {
  const FutureBuilderExample({super.key});

  @override
  State<FutureBuilderExample> createState() => _HomePageState();
}

class _HomePageState extends State<FutureBuilderExample> {
  final _textController = TextEditingController(text: Logger.modManager.searchString);
  var _mods = Logger.modManager.filteredMods;
  var _dropdownValue = Logger.modManager.category;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var mainWidget = Container(
        color: Colors.black,
        child: Column(
            children: [
              Container(
                  alignment: Alignment.topLeft,
                  height: 70,
                  width: 400,
                  child: Row(
                      children: [
                        Container(
                            padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                            height: 70,
                            width: 200,
                            child: TextField(
                                controller: _textController,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: const InputDecoration(
                                  labelText: Constants.searchText,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (text) {
                                  setState(() {
                                    Logger.modManager.searchString = text;
                                    _mods = Logger.modManager.filteredMods;
                                  });
                                })
                        ),
                        Container(
                            padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
                            height: 70,
                            width: 200,
                            child : DropdownMenu(
                                initialSelection: _dropdownValue,
                                textStyle: const TextStyle(color: Colors.white),
                                onSelected: (ModCategory? value) {
                                  setState(() {
                                    _dropdownValue = value!;
                                    Logger.modManager.category = value;
                                    _mods = Logger.modManager.filteredMods;
                                  });
                                },
                                dropdownMenuEntries: UnmodifiableListView(
                                  ModCategory.values.map((ModCategory cat) => DropdownMenuEntry(value: cat, label: cat.name)),
                                )
                            )
                        )
                      ]
                  )
              ),
              Expanded(
                  child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        ListView.builder(
                          itemCount: _mods.length,
                          itemBuilder: (context, index) {
                            var mod = _mods[index];
                            return SelectableText(
                              mod.guid,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: mod.isDeprecated ? Colors.red
                                    : mod.isOld ? Colors.grey
                                    : mod.isProblematic ? Colors.yellow
                                    : Colors.white
                              ),
                            );
                          },
                        ),
                        Padding(
                            padding: const EdgeInsets.all(50),
                            child: FloatingActionButton(
                              child: const Icon(Icons.copy),
                              onPressed: () async {
                                var text = Logger.modManager.filteredMods.map((m) => m.guid).join('\n');
                                await Clipboard.setData(ClipboardData(text: text));
                              },
                            )
                        )
                      ]
                  )
              )
            ]
        )
    );
    return FutureBuilder(
        future: Logger.modStatusNetRequest,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return mainWidget;
          }
          return Stack(children: [mainWidget, const Center(child: CircularProgressIndicator())]);
        }
    );
  }
}