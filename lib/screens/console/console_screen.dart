import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/logger.dart';
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
  late final TabController _tabController;
  final _summaryFocusNode = FocusNode(debugLabel: 'summary-main');
  final _modlistFocusNode = FocusNode(debugLabel: 'modlist-main');
  final _consoleFocusNode = FocusNode(debugLabel: 'console-main');
  final _diagnosticsFocusNode = FocusNode(debugLabel: 'diagnostics-main');
  late final _allFocusNodes = [_summaryFocusNode, _modlistFocusNode, _consoleFocusNode, _diagnosticsFocusNode];
  var _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.previousIndex == 1) {
        Logger.modManager.clearSelections();
      }

      _currentIndex = _tabController.index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _allFocusNodes[_currentIndex].requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _summaryFocusNode.dispose();
    _modlistFocusNode.dispose();
    _consoleFocusNode.dispose();
    _diagnosticsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInSelectionMode = context.select((ModManager m) => m.isInSelectionMode);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 35,
        actions: [
          if (isInSelectionMode && _tabController.index == 1)
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
                    Settings.setDeprecatedAndOldWhitelist(_addTo(Settings.deprecatedAndOldWhitelist.value, false));
                  }
                  else if (value == Constants.selectionOptions[1]) {
                    Settings.setDeprecatedAndOldWhitelist(_removeFrom(Settings.deprecatedAndOldWhitelist.value, false));
                  }
                  else if (value == Constants.selectionOptions[2]) {
                    Settings.setProblematicModlist(_addTo(Settings.problematicModlist.value, true));
                  }
                  else {
                    Settings.setProblematicModlist(_removeFrom(Settings.problematicModlist.value, true));
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
          controller: _tabController,
          tabs: const [
            Tab(text: Constants.titleTabSummary),
            Tab(text: Constants.titleTabMods),
            Tab(text: Constants.titleTabConsole),
            Tab(text: Constants.titleTabDiagnostics),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SummaryPage(tabController: _tabController, focusNode: _summaryFocusNode),
          ModListPage(tabController: _tabController, focusNode: _modlistFocusNode),
          ConsolePage(tabController: _tabController, focusNode: _consoleFocusNode),
          DiagnosticsPage(tabController: _tabController, focusNode: _diagnosticsFocusNode),
        ],
      ),
    );
  }

  List<String> _addTo(List<String> items, bool useGuid) {
    final set = items.toSet();
    for (final mod in Logger.modManager.mods) {
      if (mod.isSelected) {
        set.add(useGuid ? mod.guid : mod.fullName);
      }
    }
    final newItems = set.toList();
    newItems.sort();
    return newItems;
  }

  List<String> _removeFrom(List<String> items, bool useGuid) {
    final set = items.toSet();
    for (final mod in Logger.modManager.mods) {
      if (mod.isSelected) {
        set.remove(useGuid ? mod.guid : mod.fullName);
      }
    }
    final newItems = set.toList();
    newItems.sort();
    return newItems;
  }
}