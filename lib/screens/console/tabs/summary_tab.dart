import 'package:flutter/material.dart';

import 'package:log_viewer/log_parser.dart';

class SummaryPage extends StatelessWidget {
  final TabController tabController;

  const SummaryPage({super.key, required this.tabController});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: Logger.summary.length,
      itemBuilder: (context, index) => Logger.summary[index],
    );
  }
}