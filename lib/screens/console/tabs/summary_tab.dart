import 'package:flutter/material.dart';

import 'package:log_viewer/log_parser.dart';

class SummaryPage extends StatelessWidget {
  final TabController tabController;

  const SummaryPage({super.key, required this.tabController});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: ListView.builder(
        itemCount: Logger.summary.length,
        itemBuilder: (context, index) {
          return Text(Logger.summary[index], style: const TextStyle(color: Colors.white));
        }
      )
    );
  }
}