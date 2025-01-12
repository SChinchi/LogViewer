import 'package:flutter/material.dart';

import 'package:log_viewer/constants.dart';
import 'package:log_viewer/log_parser.dart';

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

class _ConsolePageState extends State<ConsolePageState> {
  var _currentSliderValue = Logger.getSeverity().toDouble();
  var _status = Constants.logSeverity.last;
  var _loggedEvents = Logger.filteredEvents;
  final _scrollController = ScrollController();
  final _textController = TextEditingController(text: Logger.getSearchString());

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.black,
        child: Column(
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
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(
                              labelText: Constants.searchText,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (text) {
                              setState(() {
                                Logger.setSearchString(text);
                                _loggedEvents = Logger.filteredEvents;
                            });
                          }
                        )
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
                                  child: Text(_status, style: const TextStyle(color: Colors.white))
                              ),
                            ]
                        )
                    )
                  ]
              )
          ),
          Expanded(child: RawScrollbar(
            controller: _scrollController,
            thickness: 12,
            thumbColor: Colors.grey,
            thumbVisibility: true,
            radius: const Radius.circular(10),
            child: ListView.builder(
              shrinkWrap: true,
              controller: _scrollController,
              itemCount: _loggedEvents.length,
              itemBuilder: (context, index) =>
              Stack(
                  children: [
                    Card(
                      color: Colors.black,
                      child: SelectableText(
                        _loggedEvents[index].fullString,
                        textAlign: TextAlign.left,
                        style: TextStyle(color: _loggedEvents[index].color),
                      ),
                    ),
                    if (_loggedEvents[index].repeat > 0)
                      Positioned(
                        bottom: 5,
                        right: 30,
                        child: Container(
                            color: Colors.black,
                            child: Text(
                                _loggedEvents[index].repeat.toString(),
                                style: TextStyle(fontSize: 12, color: Colors.orange[800])
                            )
                        ),
                      )
                  ]
              )
            ),
          ))
        ])
    );
  }
}