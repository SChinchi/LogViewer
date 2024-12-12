import 'package:flutter/material.dart';

import 'package:log_viewer/constants.dart';
import 'package:log_viewer/log_parser.dart';

class ConsolePage extends StatelessWidget {
  final TabController tabController;

  const ConsolePage({super.key, required this.tabController});

  @override
  Widget build(BuildContext context) {
    return const SliderExample();
  }
}

class SliderExample extends StatefulWidget {
  const SliderExample({super.key});

  @override
  State<SliderExample> createState() => _SliderExampleState();
}

class _SliderExampleState extends State<SliderExample> {
  double _currentSliderValue = Constants.logSeverity.length - 1;
  var _status = Constants.logSeverity.last;
  var _loggedEvents = Logger.filteredEvents;
  final ScrollController myScrollController = ScrollController();

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
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(
                              labelText: 'Search',
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
            controller: myScrollController,
            thickness: 12,
            thumbColor: Colors.grey,
            thumbVisibility: true,
            radius: const Radius.circular(10),
            child: ListView.builder(
              shrinkWrap: true,
              controller: myScrollController,
              itemCount: _loggedEvents.length,
              itemBuilder: (context, index) =>
              /*
                  Card(
                    color: Colors.black,
                    child: Text(
                      _loggedEvents[index].fullString,
                      textAlign: TextAlign.left,
                      style: TextStyle(color: _loggedEvents[index].color),
                    ),
                  ),
               */
              Stack(
                  children: [
                    Card(
                      color: Colors.black,
                      child: Text(
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