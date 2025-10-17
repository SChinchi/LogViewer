import 'package:flutter/material.dart';
import 'package:log_viewer/log_parser.dart';

class SummaryPage extends StatefulWidget {
  final TabController tabController;

  const SummaryPage({super.key, required this.tabController});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> with AutomaticKeepAliveClientMixin{
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
      child: ListView.builder(
        itemCount: Logger.summary.length,
        itemBuilder: (context, index) => Logger.summary[index],
      ),
    );
  }
}