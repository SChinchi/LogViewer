import 'package:flutter/material.dart';

import 'package:log_viewer/constants.dart';
import 'package:log_viewer/log_parser.dart';
import 'package:log_viewer/themes/themes.dart';
import 'package:log_viewer/utils.dart';
import 'package:log_viewer/widgets/expandable_card.dart';

class ConsolePage extends StatelessWidget {
  final TabController tabController;

  const ConsolePage({super.key, required this.tabController});

  @override
  Widget build(BuildContext context) {
    return const ConsolePageState();
  }
}

class ConsolePageState extends StatefulWidget {
  const ConsolePageState({super.key});

  @override
  State<ConsolePageState> createState() => _ConsolePageState();
}

class _ConsolePageState extends State<ConsolePageState> with AutomaticKeepAliveClientMixin {
  var _currentSliderValue = Logger.getSeverity().toDouble();
  var _status = Constants.logSeverity[Logger.getSeverity()];
  var _loggedEvents = Logger.filteredEvents;
  final _scrollController = ScrollController();
  final _textController = TextEditingController(text: Logger.getSearchString());

  @override
  bool get wantKeepAlive => true;

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
          child: addMiddleScrollFunctionality(
            Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              interactive: true,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: ListView.builder(
                  shrinkWrap: true,
                  controller: _scrollController,
                  itemCount: _loggedEvents.length,
                  itemBuilder: (context, index) => ExpandableCard(event: _loggedEvents[index]),
                ),
              ),
            ),
            _scrollController,
          ),
        ),
      ],
    );
  }
}