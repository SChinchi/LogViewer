import 'dart:io' show File, FileMode, Platform;

import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'package:log_viewer/constants.dart';
import 'package:log_viewer/log_parser.dart';
import 'package:log_viewer/settings.dart';
import 'package:log_viewer/themes/themes.dart';

import 'package:path_provider/path_provider.dart';
import 'package:super_clipboard/super_clipboard.dart';

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
          child: RawScrollbar(
            controller: _scrollController,
            thickness: 12,
            thumbColor: Colors.grey,
            thumbVisibility: true,
            radius: const Radius.circular(10),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ListView.builder(
                shrinkWrap: true,
                controller: _scrollController,
                itemCount: _loggedEvents.length,
                itemBuilder: (context, index) {
                  final event = _loggedEvents[index];
                  return Stack(
                    children: [
                      Card(
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
                          },
                        ),
                      ),
                      if (event.repeat > 0)
                        Positioned(
                          bottom: 5,
                          right: 30,
                          child: Text(
                            event.repeat.toString(),
                            style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _isMobile() {
    return Platform.isAndroid || Platform.isIOS;
  }

  void _showDialog(BuildContext context, String text) async {
    showMenu(
      context: context,
      position: RelativeRect.fromSize(_tapEventOffset & const Size(40, 40), _renderBox.size),
      shadowColor: AppTheme.primaryColor,
      menuPadding: EdgeInsets.zero,
      items: [
        PopupMenuItem(
          child: const Text("Copy"),
          onTap: () async {
            final size = Settings.getTextSizeCopyThreshold();
            if (size <= 0 || text.length < size) {
              await Clipboard.setData(ClipboardData(text: text));
              return;
            }
            final clipboard = SystemClipboard.instance;
            if (clipboard == null) {
              return;
            }
            final tempDir = await getTemporaryDirectory();
            final file = File(path.join(tempDir.path, Constants.tempCopyFilename));
            await file.writeAsString(text, mode: FileMode.writeOnly);
            final item = DataWriterItem();
            item.add(Formats.fileUri(file.uri));
            await clipboard.write([item]);
          },
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
                  maxLines: maxLines > 0 ? maxLines : null,
                  overflow: TextOverflow.fade,
                ),
                expanded: Text(
                  event.fullString,
                  style: TextStyle(color: event.color),
                ),
                builder: (_, collapsed, expanded) {
                  return Padding(
                    padding: EdgeInsets.zero,
                    child: Expandable(
                      collapsed: collapsed,
                      expanded: expanded,
                      theme: const ExpandableThemeData(crossFadePoint: 0),
                    ),
                  );
                },
              ),
            ),
            if (maxLines > 0 && event.lineCount > maxLines)
              Positioned(
                top: -10,
                right: 5,
                child: ExpandableIcon(theme: const ExpandableThemeData(iconColor: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}