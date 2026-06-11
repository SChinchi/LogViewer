import 'package:flutter/material.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/models/event.dart';
import 'package:log_viewer/providers/console_manager.dart';
import 'package:log_viewer/providers/mod_manager.dart';
import 'package:log_viewer/settings.dart';
import 'package:log_viewer/widgets/advanced_scrollable.dart';
import 'package:log_viewer/widgets/expandable_card.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class DiagnosticsPage extends StatefulWidget {
  final TabController tabController;
  final FocusNode focusNode;

  const DiagnosticsPage({super.key, required this.tabController, required this.focusNode});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final ModManager _modManager;
  late final ConsoleManager _consoleManager;
  final _scrollController = ScrollController(debugLabel: 'diagnostics');
  final CategoryItems _outdatedMods = CategoryItems();
  final CategoryItems _skippedMods = CategoryItems();
  final CategoryItems _modsCrashingOnAwake = CategoryItems();
  final CategoryItems _hookFails = CategoryItems();
  final CategoryItems _stuckLoading = CategoryItems();
  final CategoryItems _missingMemberExceptions = CategoryItems();
  final CategoryItems _mostCommonRecurrentErrors = CategoryItems();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _modManager = context.read<ModManager>();
    _consoleManager = context.read<ConsoleManager>();
    Settings.useModManifest.addListener(_onSettingChanged);
    _analyse();
  }

  @override
  void dispose() {
    Settings.useModManifest.removeListener(_onSettingChanged);
    _scrollController.dispose();
    _outdatedMods.dispose();
    _skippedMods.dispose();
    _modsCrashingOnAwake.dispose();
    _hookFails.dispose();
    _stuckLoading.dispose();
    _missingMemberExceptions.dispose();
    _mostCommonRecurrentErrors.dispose();
    super.dispose();
  }

  void _onSettingChanged() => setState(() {});

  void _analyse() {
    final bepInExPatterns = [
      r'^Skipping over type \[.*?\] as no metadata attribute is specified',
      r'^Skipping type \[.*?\] because its GUID \[.*?\] is of an illegal format',
      r'^Skipping type \[.*?\] because its version is invalid',
      r'^Skipping type \[.*?\] because its name is null',
      r'^Skipping \[.*?\] because a plugin with a similar GUID \(.*?\) has been already loaded',
      r'^Skipping \[.*?\] because a newer version exists',
      r'^Skipping \[.*?\] because of process filters',
      r'^Could not load \[.*?\] because it is incompatible with',
      r'^Skipping \[.*?\] because it has a dependency that was not loaded',
      r'^Could not load \[.*?\] because it has missing dependencies',
      r'^Error loading \[.*?\]',
    ];
    final skippedMods = RegExp('(${bepInExPatterns.join('|')})');
    // Normally it appears as Chainloader:Start, but if it has been hooked Chainloader::Start
    final chainLoaderPattern = RegExp(r'BepInEx.Bootstrap.Chainloader:[:]?Start');
    // The game loads its content in a coroutine, but we want to filter other irrelevant ones.
    // Most errors are either related to the class that does the loading, RoR2Application, or
    // coroutines launched by the SystemInitializerAttribute, for which BepInExPack conveniently
    // appears in the stack trace.
    final stuckLoadingPattern = RegExp(r'(RoR2Application|FixSystemInitializer).*UnityEngine.SetupCoroutine.InvokeMoveNext', dotAll: true);
    final flawedHookPattern = RegExp(r'(MonoMod\.RuntimeDetour\.(IL)?Hook\.\.ctor|HarmonyLib\.PatchClassProcessor\.Patch)');
    final missingPattern = RegExp(r'^Missing(Field|Method)Exception');
    final encounteredExceptions = <String>{};
    final encounteredCommonErrors = <String, Event>{};
    var currentModIndex = 0;

    for (final event in _consoleManager.events) {
      if (event.modIndex != null) {
        currentModIndex = event.modIndex!;
      }
      if (event.source == 'BepInEx') {
        if (skippedMods.firstMatch(event.message) != null) {
          _skippedMods.add(Event.clone(event));
        }
      }
      if (chainLoaderPattern.firstMatch(event.fullString) != null) {
        final eventCopy = Event.clone(event);
        eventCopy.modIndex = currentModIndex;
        eventCopy.fullString = '${_consoleManager.getEventRelatedMod(eventCopy)!.name}\n${eventCopy.fullString}';
        _modsCrashingOnAwake.add(eventCopy);
      }
      if (stuckLoadingPattern.firstMatch(event.fullString) != null && event.severity < 2) {
        _stuckLoading.add(Event.clone(event));
      }
      if (flawedHookPattern.firstMatch(event.fullString) != null) {
        _hookFails.add(Event.clone(event));
      }
      if (missingPattern.firstMatch(event.message) != null && !encounteredExceptions.contains(event.fullStringNoPrefix)) {
        _missingMemberExceptions.add(Event.clone(event));
        encounteredExceptions.add(event.fullStringNoPrefix);
      }
      if (event.repeat > 0 && event.severity < 2) {
        if (!encounteredCommonErrors.containsKey(event.fullStringNoPrefix)) {
          encounteredCommonErrors[event.fullStringNoPrefix] = event;
        } else if (encounteredCommonErrors[event.fullStringNoPrefix]!.repeat < event.repeat) {
          encounteredCommonErrors[event.fullStringNoPrefix] = event;
        }
      }
    }
    for (final event in encounteredCommonErrors.values) {
      _mostCommonRecurrentErrors.add(Event.clone(event));
    }
    _mostCommonRecurrentErrors.events.sort((event1, event2) => event2.repeat.compareTo(event1.repeat));
  }

  void _tryAddCategory(List<ExpandableList> expandableCategories, CategoryItems items, String header) {
    if (items.isNotEmpty) {
      expandableCategories.add(ExpandableList(heading: header, items: items));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    context.select((ModManager modManager) => modManager.mods.where((m) => !m.isLatestVersion).toList());
    _rebuildOutdatedMods();
    _rebuildModsCrashingOnAwake();
    final data = <ExpandableList>[];
    _tryAddCategory(data, _outdatedMods, Constants.diagnosticsOutdated);
    _tryAddCategory(data, _skippedMods, Constants.diagnosticsSkippedMods);
    _tryAddCategory(data, _modsCrashingOnAwake, Constants.diagnosticsCrashingMods);
    _tryAddCategory(data, _hookFails, Constants.diagnosticsBadHooks);
    _tryAddCategory(data, _stuckLoading, Constants.diagnosticsStuckLoading);
    _tryAddCategory(data, _missingMemberExceptions, Constants.diagnosticsMissingMember);
    _tryAddCategory(data, _mostCommonRecurrentErrors, Constants.diagnosticsRepeatErrors);
    return AdvancedScrollable(
      controller: _scrollController,
      mainFocusNode: widget.focusNode,
      child: SuperListView.builder(
        controller: _scrollController,
        itemCount: data.length,
        itemBuilder: (BuildContext context, int index) {
          return ExpansionTile(
            backgroundColor: Colors.white10,
            title: Text(data[index].heading),
            controller: data[index].items.controller,
            children: data[index].items.events.map((item) =>
                ListTile(
                  title: ExpandableCard(event: item, tabController: widget.tabController),
                  minVerticalPadding: 2,
                )).toList(),
          );
        },
      ),
    );
  }

  void _rebuildOutdatedMods() {
    _outdatedMods.clear();
    final mods = _modManager
        .mods
        .where((mod) => !mod.isLatestVersion)
        .map((mod) => mod.guid)
        .join('\n');
    if (mods.isNotEmpty) {
      // We're faking the structure of an Event so we can add it to the list.
      _outdatedMods.add(Event('', Constants.logSeverity[2], 'LogViewer', mods, mods));
    }
  }

  void _rebuildModsCrashingOnAwake() {
    for (final event in _modsCrashingOnAwake.events) {
      final modNameAndText = event.fullString.split('\n');
      modNameAndText[0] = _consoleManager.getEventRelatedMod(event)!.name;
      event.fullString = modNameAndText.join('\n');
    }
  }
}

class CategoryItems {
  final events = <Event>[];
  final controller = ExpansibleController();

  bool get isNotEmpty => events.isNotEmpty;

  void add(Event event) {
    events.add(event);
  }

  void clear() {
    events.clear();
  }

  void dispose() {
    controller.dispose();
    for (final event in events) {
      event.dispose();
    }
    events.clear();
  }
}

class ExpandableList {
  final String heading;
  final CategoryItems items;

  ExpandableList({required this.heading, required this.items});
}