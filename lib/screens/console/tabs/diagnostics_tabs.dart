import 'package:flutter/material.dart';

import 'package:log_viewer/log_parser.dart';

class DiagnosticsPage extends StatefulWidget {
  final TabController tabController;

  const DiagnosticsPage({super.key, required this.tabController});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> with SingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  Widget build(BuildContext context) {
    final data = <ExpandableList>[];
    if (Diagnostics.dependencyIssues.isNotEmpty) {
      data.add(ExpandableList(heading: 'Missing Dependencies & Incompatibilities', items: Diagnostics.dependencyIssues));
    }
    if (Diagnostics.modsCrashingOnAwake.isNotEmpty) {
      data.add(ExpandableList(heading: 'Mods Crashing On Awake', items: Diagnostics.modsCrashingOnAwake));
    }
    if (Diagnostics.stuckLoading.isNotEmpty) {
      data.add(ExpandableList(heading: 'Stuck Loading x%', items: Diagnostics.stuckLoading));
    }
    if (Diagnostics.missingMemberExceptions.isNotEmpty) {
      data.add(ExpandableList(heading: 'Missing Member Exception', items: Diagnostics.missingMemberExceptions));
    }
    if (Diagnostics.mostCommonRecurrentErrors.isNotEmpty) {
      data.add(ExpandableList(heading: 'Most Spammed Errors', items: Diagnostics.mostCommonRecurrentErrors));
    }
    return Scaffold(
      body: ListView.builder(
        itemBuilder: (BuildContext context, int index) {
          return ExpansionTile(
            backgroundColor: Colors.white10,
            title: Text(data[index].heading),
            children: data[index].items.map((item) =>
                ListTile(title: SelectableText(item.text, style: TextStyle(color: item.color)))).toList(),
          );
        },
        itemCount: data.length,
      ),
    );
  }
}

class ExpandableList {
  final String heading;
  final List<ListItem> items;

  ExpandableList({required this.heading, required this.items});
}