import 'dart:io';

import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:path/path.dart' as path;

import '../constants.dart';
import '../log_parser.dart';
import '../settings.dart';
import '../themes/themes.dart';
import '../utils.dart';

class ExpandableCard extends StatefulWidget {
  final Event event;

  const ExpandableCard({super.key, required this.event});

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> {
  _ExpandableCardState();

  late RenderBox _renderBox;
  var _tapEventOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    _renderBox = Overlay.of(context).context.findRenderObject() as RenderBox;
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
              if (Environment.isMobile) {
                _showDialog(context, event.fullString);
              }
            },
            onSecondaryTap: () {
              if (!Environment.isMobile) {
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
            // TODO: Fix for Android
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
      controller: event.controller,
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