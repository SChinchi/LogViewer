import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/log_parser.dart';
import 'package:log_viewer/providers/mod_manager.dart';
import 'package:log_viewer/settings.dart';
import 'package:log_viewer/themes/themes.dart';
import 'package:provider/provider.dart';

import '../settings_screen.dart';
import 'tabs/summary_tab.dart';
import 'tabs/modlist_tab.dart';
import 'tabs/console_tab.dart';
import 'tabs/diagnostics_tabs.dart';

class ConsoleScreen extends StatelessWidget {
  const ConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Logger.modManager),
      ],
      child: const ConsoleScreenState(),
    );
  }
}

class ConsoleScreenState extends StatefulWidget {
  const ConsoleScreenState({super.key});

  @override
  State<ConsoleScreenState> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreenState> with SingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    tabController = TabController(length: 4, vsync: this);
    tabController.addListener(() {
      if (tabController.previousIndex == 1) {
        Logger.modManager.clearSelections();
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isInSelectionMode = context.select((ModManager m) => m.isInSelectionMode);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 35,
        actions: [
          if (isInSelectionMode && tabController.index == 1)
            ...[
              IconButton(
                icon: const Icon(Icons.cancel),
                onPressed: () {
                  Logger.modManager.clearSelections();
                },
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  final text = Logger.modManager.mods.where((m) => m.isSelected).map((m) => m.guid);
                  await Clipboard.setData(ClipboardData(text: text.join('\n')));
                  Logger.modManager.clearSelections();
                },
              ),
              PopupMenuButton(
                shadowColor: AppTheme.primaryColor,
                onSelected: ((value) {
                  if (value == Constants.selectionOptions[0]) {
                    Settings.setDeprecatedAndOldWhitelist(_addTo(Settings.getDeprecatedAndOldWhitelist()));
                  }
                  else if (value == Constants.selectionOptions[1]) {
                    Settings.setDeprecatedAndOldWhitelist(_removeFrom(Settings.getDeprecatedAndOldWhitelist()));
                  }
                  else if (value == Constants.selectionOptions[2]) {
                    Settings.setProblematicModlist(_addTo(Settings.getProblematicModlist()));
                  }
                  else {
                    Settings.setProblematicModlist(_removeFrom(Settings.getProblematicModlist()));
                  }
                  Logger.modManager.clearSelections();
                }),
                itemBuilder: (BuildContext context) {
                  return Constants.selectionOptions.map((String choice) {
                    return PopupMenuItem<String>(value: choice, child: Text(choice));
                  }).toList();
                },
              ),
            ]
          else
            PopupMenuButton(
              menuPadding: EdgeInsets.zero,
              shadowColor: AppTheme.primaryColor,
              onSelected: ((value) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              }),
              itemBuilder: (BuildContext context) {
                return Constants.menuOptions.map((String choice) {
                  return PopupMenuItem(value: choice, child: Text(choice));
                }).toList();
              },
            )
        ],
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: Constants.titleTabSummary),
            Tab(text: Constants.titleTabMods),
            Tab(text: Constants.titleTabConsole),
            Tab(text: Constants.titleTabDiagnostics),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          SummaryPage(tabController: tabController),
          ModListPage(tabController: tabController),
          ConsolePage(tabController: tabController),
          DiagnosticsPage(tabController: tabController),
        ],
      ),
    );
  }

  List<String> _addTo(List<String> items) {
    final set = items.toSet();
    for (final mod in Logger.modManager.mods) {
      if (mod.isSelected) {
        set.add(mod.fullName);
      }
    }
    final newItems = set.toList();
    newItems.sort();
    return newItems;
  }

  List<String> _removeFrom(List<String> items) {
    final set = items.toSet();
    for (final mod in Logger.modManager.mods) {
      if (mod.isSelected) {
        set.remove(mod.fullName);
      }
    }
    final newItems = set.toList();
    newItems.sort();
    return newItems;
  }
}