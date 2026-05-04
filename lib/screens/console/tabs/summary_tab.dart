import 'package:flutter/material.dart';
import 'package:log_viewer/log_parser.dart';
import 'package:log_viewer/providers/mod_manager.dart';
import 'package:provider/provider.dart';

class SummaryPage extends StatelessWidget {
  final TabController tabController;

  const SummaryPage({super.key, required this.tabController});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Logger.modManager),
      ],
      child: const SummaryPageState(),
    );
  }
}

class SummaryPageState extends StatefulWidget {
  const SummaryPageState({super.key});

  @override
  State<SummaryPageState> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPageState> with AutomaticKeepAliveClientMixin{
  @override
  bool get wantKeepAlive => true;

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
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
      child: ListView.builder(
        itemCount: summary.length,
        itemBuilder: (context, index) => summary[index],
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