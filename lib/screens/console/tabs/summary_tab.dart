import 'package:flutter/material.dart';
import 'package:log_viewer/providers/console_manager.dart';
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
  late final ModManager _modManager;
  final _scrollController = ScrollController(debugLabel: 'summary');
  final summary = <Widget>[];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _modManager = context.read<ModManager>();
    final consoleManager = context.read<ConsoleManager>();
    for (final line in consoleManager.summary) {
      if (line.length == 1) {
        // No colour information - use default
        summary.add(Text(line[0] as String));
      } else {
        summary.add(Text(line[0] as String, style: TextStyle(color: Color(line[1] as int))));
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    context.select((ModManager manager) => manager.mods.map((m) => m.labels).toList());
    final finalSummary = List.from(summary);
    final modIssues = _collectModIssues();
    if (modIssues != null) {
      finalSummary.add(modIssues);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
      child: AdvancedScrollable(
        controller: _scrollController,
        mainFocusNode: widget.focusNode,
        child: SuperListView.builder(
          controller: _scrollController,
          itemCount: finalSummary.length,
          itemBuilder: (context, index) => finalSummary[index],
        ),
      ),
    );
  }

  Text? _collectModIssues() {
    final mods = _modManager.mods;
    var deprecated = 0,
        old = 0,
        problematic = 0,
        ai = 0;
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
      if (mod.isAi) {
        ai += 1;
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
    if (ai > 0) {
      warnings.add('$ai AI');
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
    } else {
      return Text('Found ${warnings.sublist(0, warnings.length - 1).join(', ')}, and ${_deducePluralText(warnings.last)}',
          style: textStyle);
    }
  }

  String _deducePluralText(String modNumber) {
    return '$modNumber ${modNumber.startsWith('1 ') ? 'mod' : 'mods'}';
  }
}