import 'package:flutter/material.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/models/event.dart';
import 'package:log_viewer/providers/console_manager.dart';
import 'package:log_viewer/themes/themes.dart';
import 'package:log_viewer/widgets/advanced_scrollable.dart';
import 'package:log_viewer/widgets/expandable_card.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class ConsolePage extends StatefulWidget {
  final TabController tabController;
  final FocusNode focusNode;

  const ConsolePage({super.key, required this.tabController, required this.focusNode});

  @override
  State<ConsolePage> createState() => _ConsolePageState();
}

class _ConsolePageState extends State<ConsolePage> with AutomaticKeepAliveClientMixin {
  late final ConsoleManager _consoleManager;
  final _textFocusNode = FocusNode(debugLabel: 'console-search');
  final _listController = ListController();
  final _scrollController = ScrollController(debugLabel: 'console');
  final _textController = TextEditingController(text: '');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _consoleManager = context.read<ConsoleManager>();
  }

  @override
  void dispose() {
    _textFocusNode.dispose();
    _listController.dispose();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Container(
          alignment: Alignment.topLeft,
          height: 70,
          width: 400,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                height: 70,
                width: 200,
                child: TextField(
                  focusNode: _textFocusNode,
                  controller: _textController,
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: Constants.searchText,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (text) {
                    _consoleManager.setSearchString(text);
                  },
                ),
              ),
              SizedBox(
                height: 70,
                width: 200,
                child: Selector<ConsoleManager, int>(
                  selector: (context, consoleManager) => consoleManager.getSeverity(),
                  builder: (context, severity, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Slider(
                          value: severity.toDouble(),
                          min: 0,
                          max: Constants.logSeverity.length.toDouble() - 1,
                          divisions: Constants.logSeverity.length - 1,
                          onChanged: (value) {
                            _consoleManager.setSeverity(value.round());
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 0, 0),
                          child: Text(Constants.logSeverity[severity]),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AdvancedScrollable(
            controller: _scrollController,
            mainFocusNode: widget.focusNode,
            otherFocusNodes: [_textFocusNode],
            child: Selector<ConsoleManager, int>(
              selector: (context, consoleManager) => consoleManager.eventTargetRevision,
              builder: (context, counter, _) {
                return Selector<ConsoleManager, List<Event>>(
                  selector: (context, consoleManager) => consoleManager.filteredEvents.toList(),
                  builder: (context, filteredEvents, _) {
                    // If we try to use goto from Diagnostics without ever visiting the
                    // Console tab, it will have never had a chance to build the list, so
                    // we need to ensure jumping to an index happens after the first build.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final consoleManager = context.read<ConsoleManager>();
                      if (consoleManager.hasValidEventTarget) {
                        _textController.text = '';
                        final index = consoleManager.eventTarget;
                        _listController.jumpToItem(
                          index: index,
                          scrollController: _scrollController,
                          alignment: 0.5,
                        );
                      }
                    });
                    return SuperListView.builder(
                      shrinkWrap: true,
                      listController: _listController,
                      controller: _scrollController,
                      itemCount: filteredEvents.length,
                      itemBuilder: (context, index) {
                        return ExpandableCard(
                          event: filteredEvents[index],
                          tabController: widget.tabController,
                          highlight: _consoleManager.eventTarget == filteredEvents[index].index,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}