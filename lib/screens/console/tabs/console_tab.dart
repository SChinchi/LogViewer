import 'dart:io' show Platform;

import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:log_viewer/constants.dart';
import 'package:log_viewer/log_parser.dart';
import 'package:log_viewer/settings.dart';

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
  var _tapEventOffset = Offset.zero;
  late RenderBox _renderBox;

  @override
  Widget build(BuildContext context) {
    _renderBox = Overlay.of(context).context.findRenderObject() as RenderBox;
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
                  itemBuilder: (context, index) {
                    final event = _loggedEvents[index];
                    return Stack(
                        children: [
                          Card(
                              color: Colors.black,
                              child: GestureDetector(
                                  child: _ExpandableContainer(event: event),
                                  onLongPressDown: (detail) {
                                    _tapEventOffset = detail.globalPosition;
                                  },
                                  onSecondaryTapDown: (detail) {
                                    _tapEventOffset = detail.globalPosition;
                                  },
                                  onLongPress: () {
                                    if (_isMobile()) {
                                      _showDialog(context, event.fullString);
                                    }
                                  },
                                  onSecondaryTap: () {
                                    if (!_isMobile()) {
                                      _showDialog(context, event.fullString);
                                    }
                                  }
                              )
                          ),
                          if (event.repeat > 0)
                            Positioned(
                              bottom: 5,
                              right: 5,
                              child: Container(
                                  color: Colors.black,
                                  child: Text(
                                      event.repeat.toString(),
                                      style: TextStyle(fontSize: 12, color: Colors.orange[800])
                                  )
                              ),
                            )
                        ]
                    );
                  },
                ),
              ))
            ]
        )
    );
  }

  bool _isMobile() {
    return Platform.isAndroid || Platform.isIOS;
  }

  void _showDialog(BuildContext context, String text) async {
    showMenu(
      context: context,
      position: RelativeRect.fromSize(_tapEventOffset & const Size(40, 40), _renderBox.size),
      items: [
        PopupMenuItem(
            child: const Text("Copy"),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: text));
            }
        ),
      ],
    );
  }
}

class _ExpandableContainer extends StatelessWidget {
  final Event event;

  const _ExpandableContainer({required this.event});

  @override
  Widget build(BuildContext context) {
    final maxLines = Settings.getConsoleEventMaxLines();
    return ExpandableNotifier(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
        child: Stack(
            children: [
              ScrollOnExpand(
                scrollOnExpand: false,
                scrollOnCollapse: true,
                child: ExpandablePanel(
                  theme: const ExpandableThemeData(
                    tapBodyToCollapse: true,
                    tapBodyToExpand: true,
                  ),
                  collapsed: Text(
                    event.fullString,
                    style: TextStyle(color: event.color),
                    maxLines: maxLines,
                    overflow: TextOverflow.fade,
                  ),
                  expanded: Text(
                    event.fullString,
                    style: TextStyle(color: event.color),
                  ),
                  builder: (_, collapsed, expanded) {
                    return Padding(
                      padding: EdgeInsets.zero, //const EdgeInsets.o,
                      child: Expandable(
                        collapsed: collapsed,
                        expanded: expanded,
                        theme: const ExpandableThemeData(crossFadePoint: 0),
                      ),
                    );
                  },
                ),
              ),
              if (event.lineCount > maxLines)
                Positioned(
                  top: -10,
                  right: 5,
                  child: ExpandableIcon(theme: const ExpandableThemeData(iconColor: Colors.grey)),
                ),
            ]
        ),
      ),
    );
  }
}