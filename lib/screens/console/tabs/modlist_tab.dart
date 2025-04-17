import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/log_parser.dart';
import 'package:log_viewer/providers/mod_manager.dart';
import 'package:log_viewer/themes/themes.dart';
import 'package:log_viewer/utils.dart';
import 'package:provider/provider.dart';

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
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final mods = context.watch<ModManager>().filteredMods;
    return Column(
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
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: Constants.searchText,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (text) {
                    Logger.modManager.searchString = text;
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
                height: 70,
                width: 200,
                child: DropdownMenu(
                  initialSelection: Logger.modManager.category,
                  inputDecorationTheme: InputDecorationTheme(
                    isDense: true,
                    constraints: BoxConstraints.tight(const Size.fromHeight(50)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onSelected: (ModCategory? value) {
                    Logger.modManager.category = value!;
                  },
                  dropdownMenuEntries: UnmodifiableListView(
                    ModCategory.values.map((ModCategory cat) => DropdownMenuEntry(value: cat, label: cat.name)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              addMiddleScrollFunctionality(
                Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  interactive: true,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: mods.length,
                      itemBuilder: (context, index) {
                        final mod = mods[index];
                        return GestureDetector(
                          child: Text(
                            mod.guid,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: mod.isDeprecated ? Colors.red
                                  : mod.isOld ? Colors.grey
                                  : mod.isProblematic ? Colors.yellow
                                  : AppTheme.primaryColor,
                              backgroundColor: mod.isSelected ? AppTheme.selectedColor
                                  : AppTheme.secondaryColor,
                            ),
                          ),
                          onLongPress: () {
                            if (!Logger.modManager.isInSelectionMode) {
                              Logger.modManager.toggleSelected(mod);
                            }
                          },
                          onTap: () {
                            if (Logger.modManager.isInSelectionMode) {
                              // Need to trigger a state update because [isInSelectionMode] doesn't change
                              setState(() {
                                Logger.modManager.toggleSelected(mod);
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
                _scrollController,
              ),
              Padding(
                padding: const EdgeInsets.all(50),
                child: FloatingActionButton(
                  child: const Icon(Icons.copy),
                  onPressed: () async {
                    final text = Logger.modManager.filteredMods.map((m) => m.guid).join('\n');
                    await Clipboard.setData(ClipboardData(text: text));
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}