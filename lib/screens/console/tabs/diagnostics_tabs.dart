import 'package:flutter/material.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/log_parser.dart';
import 'package:log_viewer/widgets/expandable_card.dart';

class DiagnosticsPage extends StatefulWidget {
  final TabController tabController;

  const DiagnosticsPage({super.key, required this.tabController});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController tabController;

  @override
  bool get wantKeepAlive => true;

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
    return ListView.builder(
      itemBuilder: (BuildContext context, int index) {
        return ExpansionTile(
          backgroundColor: Colors.white10,
          title: Text(data[index].heading),
          controller: data[index].items.controller,
          children: data[index].items.events.map((item) =>
              ListTile(
                title: ExpandableCard(event: item),
                minVerticalPadding: 2,
              )).toList(),
        );
      },
      itemCount: data.length,
    );
  }
}

class ExpandableList {
  final String heading;
  final CategoryItems items;

  ExpandableList({required this.heading, required this.items});
}