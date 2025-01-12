import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:log_viewer/log_parser.dart';
import 'package:log_viewer/settings.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../providers/mod_manager.dart';
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
            toolbarHeight: 30,
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (isInSelectionMode && tabController.index == 1)
                ...[
                  IconButton(
                    icon: const Icon(
                        Icons.cancel,
                        color: Colors.white
                    ),
                    onPressed: () {
                      Logger.modManager.clearSelections();
                    }
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      var text = Logger.modManager.mods.where((m) => m.isSelected).map((m) => m.guid);
                      await Clipboard.setData(ClipboardData(text: text.join('\n')));
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: ((value) =>
                    {
                      if (value == Constants.selectionOptions[0]) {
                        Settings.setDeprecatedAndOldWhitelist(_addTo(Settings.getDeprecatedAndOldWhitelist()))
                      }
                      else if (value == Constants.selectionOptions[1]) {
                        Settings.setDeprecatedAndOldWhitelist(_removeFrom(Settings.getDeprecatedAndOldWhitelist()))
                      }
                      else if (value == Constants.selectionOptions[2]) {
                        Settings.setProblematicModlist(_addTo(Settings.getProblematicModlist()))
                      }
                      else {
                        Settings.setProblematicModlist(_removeFrom(Settings.getProblematicModlist()))
                      },
                      Logger.modManager.clearSelections()
                    }),
                    itemBuilder: (BuildContext context) {
                      return Constants.selectionOptions.map((String choice) {
                        return PopupMenuItem<String>(value: choice, child: Text(choice));
                      }).toList();
                    },
                  ),
                ]
              else
                PopupMenuButton<String>(
                  onSelected: ((value) =>
                  {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()))
                  }),
                  itemBuilder: (BuildContext context) {
                    return Constants.menuOptions.map((String choice) {
                      return PopupMenuItem<String>(value: choice, child: Text(choice));
                    }).toList();
                  },
                )
            ],
            bottom: TabBar(
                controller: tabController,
                labelColor: Colors.white,
                indicator: const UnderlineTabIndicator(borderSide: BorderSide(color: Colors.white, width: 2.0)),
                tabs: const [
                  Tab(text: Constants.titleTab_1),
                  Tab(text: Constants.titleTab_2),
                  Tab(text: Constants.titleTab_3),
                  Tab(text: Constants.titleTab_4),
                ]
            )
        ),
        body: TabBarView(controller: tabController, children: [
          SummaryPage(tabController: tabController),
          ModListPage(tabController: tabController),
          ConsolePage(tabController: tabController),
          DiagnosticsPage(tabController: tabController),
        ])
    );
  }

  List<String> _addTo(List<String> items) {
    var manager = Logger.modManager;
    var set = items.toSet();
    for (var mod in manager.mods) {
      if (mod.isSelected) {
        set.add(mod.fullName);
      }
    }
    var newItems = set.toList();
    newItems.sort();
    return newItems;
  }

  List<String> _removeFrom(List<String> items) {
    var manager = Logger.modManager;
    var set = items.toSet();
    for (var mod in manager.mods) {
      if (mod.isSelected) {
        set.remove(mod.fullName);
      }
    }
    var newItems = set.toList();
    newItems.sort();
    return newItems;
  }
}