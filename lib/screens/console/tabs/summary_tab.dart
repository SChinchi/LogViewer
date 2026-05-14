import 'package:flutter/material.dart';
import 'package:log_viewer/logger.dart';
import 'package:log_viewer/providers/mod_manager.dart';
import 'package:log_viewer/widgets/advanced_scrollable.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class SummaryPage extends StatefulWidget {
  final TabController tabController;
  final FocusNode focusNode;

  const SummaryPage({super.key, required this.tabController, required this.focusNode});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController(debugLabel: 'summary');

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mods = context
        .watch<ModManager>()
        .mods;
    final summary = List.from(Logger.summary);
    final modIssues = _collectModIssues(mods);
    if (modIssues != null) {
      summary.add(modIssues);
    }
    return Provider(
      create: (_) => Logger.modManager,
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
        child: AdvancedScrollable(
          controller: _scrollController,
          mainFocusNode: widget.focusNode,
          child: SuperListView.builder(
            controller: _scrollController,
            itemCount: summary.length,
            itemBuilder: (context, index) => summary[index],
          ),
        ),
      ),
    );
  }

  Text? _collectModIssues(List<Mod> mods) {
    var deprecated = 0,
        old = 0,
        problematic = 0;
    for (final mod in mods) {
      if (mod.isDeprecated) {
        deprecated += 1;
      }
      if (mod.isOld) {
        old += 1;
      }
      if (mod.isProblematic) {
        problematic += 1;
      }
    }
    final warnings = <String>[];
    if (deprecated > 0) {
      warnings.add('$deprecated deprecated');
    }
    if (old > 0) {
      warnings.add("$old old");
    }
    if (problematic > 0) {
      warnings.add('$problematic problematic');
    }

    if (warnings.isEmpty) {
      return null;
    }
    const textStyle = TextStyle(color: Colors.yellow);
    if (warnings.length == 1) {
      return Text('Found ${_deducePluralText(warnings[0])}',
          style: textStyle);
    }
    if (warnings.length == 2) {
      return Text('Found ${warnings[0]} and ${_deducePluralText(warnings[1])}',
          style: textStyle);
    }
    else {
      return Text('Found ${warnings.sublist(0, warnings.length - 1).join(', ')}, and ${_deducePluralText(warnings.last)}',
          style: textStyle);
    }
  }

  String _deducePluralText(String modNumber) {
    return '$modNumber ${modNumber.startsWith('1 ') ? 'mod' : 'mods'}';
  }
}