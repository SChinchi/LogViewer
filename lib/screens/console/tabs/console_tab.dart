import 'package:flutter/material.dart';

import 'package:log_viewer/constants.dart';
import 'package:log_viewer/logger.dart';
import 'package:log_viewer/themes/themes.dart';
import 'package:log_viewer/widgets/advanced_scrollable.dart';
import 'package:log_viewer/widgets/expandable_card.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class ConsolePage extends StatefulWidget {
  final TabController tabController;
  final FocusNode focusNode;

  const ConsolePage({super.key, required this.tabController, required this.focusNode});

  @override
  State<ConsolePage> createState() => _ConsolePageState();
}

class _ConsolePageState extends State<ConsolePage> with AutomaticKeepAliveClientMixin {
  static _ConsolePageState? _instance;

  var _currentSliderValue = Logger.getSeverity().toDouble();
  var _status = Constants.logSeverity[Logger.getSeverity()];
  var _loggedEvents = Logger.filteredEvents;
  final _textFocusNode = FocusNode(debugLabel: 'console-search');
  final _listController = ListController();
  final _scrollController = ScrollController(debugLabel: 'console');
  final _textController = TextEditingController(text: Logger.getSearchString());

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _instance = this;
  }

  @override
  void dispose() {
    _instance = null;
    _textFocusNode.dispose();
    _listController.dispose();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // If we try to use goto from Diagnostics without ever visiting the
    // Console tab, it will have never had a chance to build the view, so
    // we need to ensure jumping to an index happens after the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Logger.hasValidEventTarget) {
        final index = Logger.eventTarget;
        _listController.jumpToItem(
          index: index,
          scrollController: _scrollController,
          alignment: 0.5,
        );
      }
    });
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
                    setState(() {
                      Logger.setSearchString(text);
                      _loggedEvents = Logger.filteredEvents;
                    });
                  },
                ),
              ),
              SizedBox(
                height: 70,
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Slider(
                      value: _currentSliderValue,
                      min: 0,
                      max: Constants.logSeverity.length.toDouble() - 1,
                      divisions: Constants.logSeverity.length - 1,
                      onChanged: (value) {
                        setState(() {
                          _status = Constants.logSeverity[value.round()];
                          _currentSliderValue = value;
                          Logger.setSeverity(value.round());
                          _loggedEvents = Logger.filteredEvents;
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 0, 0),
                      child: Text(_status),
                    ),
                  ],
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
            child: SuperListView.builder(
              shrinkWrap: true,
              listController: _listController,
              controller: _scrollController,
              itemCount: _loggedEvents.length,
              itemBuilder: (context, index) {
                return ExpandableCard(
                  event: _loggedEvents[index],
                  tabController: widget.tabController,
                  highlight: Logger.eventTarget == _loggedEvents[index].index,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _resetSearchFiltersAndGotoEvent() {
    setState(() {
      _textController.text = Logger.getSearchString();
      _currentSliderValue = Logger.getSeverity().round().toDouble();
      _loggedEvents = Logger.filteredEvents;
    });
  }
}

void jumpToConsoleEvent() {
  if (Logger.hasValidEventTarget) {
    _ConsolePageState._instance?._resetSearchFiltersAndGotoEvent();
  }
}