import 'package:flutter/material.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/logger.dart';
import 'package:log_viewer/settings.dart';
import 'package:log_viewer/widgets/advanced_scrollable.dart';
import 'package:log_viewer/widgets/expandable_card.dart';
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
  final _scrollController = ScrollController(debugLabel: 'diagnostics');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Settings.useModManifest.addListener(_onSettingChanged);
  }

  @override
  void dispose() {
    Settings.useModManifest.removeListener(_onSettingChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSettingChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = <ExpandableList>[];
    if (Diagnostics.outdatedMods.isNotEmpty) {
      data.add(ExpandableList(heading: Constants.diagnosticsOutdated, items: Diagnostics.outdatedMods));
    }
    if (Diagnostics.dependencyIssues.isNotEmpty) {
      data.add(ExpandableList(heading: Constants.diagnosticsDependencies, items: Diagnostics.dependencyIssues));
    }
    if (Diagnostics.modsCrashingOnAwake.isNotEmpty) {
      data.add(ExpandableList(heading: Constants.diagnosticsCrashingMods, items: Diagnostics.modsCrashingOnAwake));
    }
    if (Diagnostics.hookFails.isNotEmpty) {
      data.add(ExpandableList(heading: Constants.diagnosticsBadHooks, items: Diagnostics.hookFails));
    }
    if (Diagnostics.stuckLoading.isNotEmpty) {
      data.add(ExpandableList(heading: Constants.diagnosticsStuckLoading, items: Diagnostics.stuckLoading));
    }
    if (Diagnostics.missingMemberExceptions.isNotEmpty) {
      data.add(ExpandableList(heading: Constants.diagnosticsMissingMember, items: Diagnostics.missingMemberExceptions));
    }
    if (Diagnostics.mostCommonRecurrentErrors.isNotEmpty) {
      data.add(ExpandableList(heading: Constants.diagnosticsRepeatErrors, items: Diagnostics.mostCommonRecurrentErrors));
    }
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
}

class ExpandableList {
  final String heading;
  final CategoryItems items;

  ExpandableList({required this.heading, required this.items});
}