import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:log_viewer/constants.dart';
import 'package:log_viewer/log_parser.dart';
import 'package:log_viewer/providers/mod_manager.dart';

class ModListPage extends StatelessWidget {
  final TabController tabController;

  const ModListPage({super.key, required this.tabController});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Logger.modManager),
      ],
      child: const ModListPageState(),
    );
  }
}

class ModListPageState extends StatefulWidget {
  const ModListPageState({super.key});

  @override
  State<ModListPageState> createState() => _ModListPageState();
}

class _ModListPageState extends State<ModListPageState> {
  final _textController = TextEditingController(text: Logger.modManager.searchString);

  @override
  Widget build(BuildContext context) {
    var mods = context.watch<ModManager>().filteredMods;
    return Container(
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
                                  Logger.modManager.searchString = text;
                                })
                        ),
                        Container(
                            padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
                            height: 70,
                            width: 200,
                            child: DropdownMenu(
                                initialSelection: Logger.modManager.category,
                                textStyle: const TextStyle(color: Colors.white),
                                onSelected: (ModCategory? value) {
                                  Logger.modManager.category = value!;
                                },
                                dropdownMenuEntries: UnmodifiableListView(
                                  ModCategory.values.map((ModCategory cat) =>
                                      DropdownMenuEntry(value: cat, label: cat.name)),
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
                          itemCount: mods.length,
                          itemBuilder: (context, index) {
                            var mod = mods[index];
                            return GestureDetector(
                                child: Text(
                                  mod.guid,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                      color: mod.isDeprecated ? Colors.red
                                          : mod.isOld ? Colors.grey
                                          : mod.isProblematic ? Colors.yellow
                                          : Colors.white,
                                      backgroundColor: Logger.modManager.mods[index].isSelected ? Colors.grey[700]
                                          : Colors.black
                                  ),
                                ),
                                onLongPress: () {
                                  if (!Logger.modManager.isInSelectionMode) {
                                    Logger.modManager.toggleSelected(index);
                                  }
                                },
                                onTap: () {
                                  if (Logger.modManager.isInSelectionMode) {
                                    // Need to trigger a state update because [isInSelectionMode] doesn't change
                                    setState(() {
                                      Logger.modManager.toggleSelected(index);
                                    });
                                  }
                                }
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
  }
}