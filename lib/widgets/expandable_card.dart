import 'dart:io';

import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/models/event.dart';
import 'package:log_viewer/providers/console_manager.dart';
import 'package:log_viewer/settings.dart';
import 'package:log_viewer/themes/themes.dart';
import 'package:log_viewer/utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:path/path.dart' as path;

class ExpandableCard extends StatefulWidget {
  final Event event;
  final TabController tabController;
  final bool highlight;

  const ExpandableCard({
    super.key,
    required this.event,
    required this.tabController,
    this.highlight = false,
  });

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> with SingleTickerProviderStateMixin {
  _ExpandableCardState();

  late final ConsoleManager _consoleManager;

  late final _animationController = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1000),
  )..reverse();
  late final Animation<Decoration> _animationDecoration = _animationController
      .drive(CurveTween(curve: Curves.easeInOut))
      .drive(DecorationTween(begin: const BoxDecoration(), end: BoxDecoration(color: AppTheme.selectedColor))
  );
  var _animationDisposed = false;

  late RenderBox _renderBox;
  var _tapEventOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _consoleManager = context.read<ConsoleManager>();
    Settings.consoleEventMaxLines.addListener(_onSettingChanged);
    _animationDecoration.addStatusListener(_onAnimationDecorationStatusChanged);
  }

  @override
  void dispose() {
    Settings.consoleEventMaxLines.removeListener(_onSettingChanged);
    _animationDecoration.removeStatusListener(_onAnimationDecorationStatusChanged);
    _animationController.dispose();
    _animationDisposed = true;
    super.dispose();
  }

  void _onSettingChanged() => setState(() {});

  void _onAnimationDecorationStatusChanged(AnimationStatus status) async {
    if (status == AnimationStatus.completed) {
      if (!_animationDisposed) {
        await _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shouldHighlight = widget.highlight && _consoleManager.hasValidEventTarget;
    if (shouldHighlight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_animationDisposed) {
          _animationController.reverse();
          _animationController.forward();
        }
        _consoleManager.resetEventTarget();
      });
    }
    final event = widget.event;
    _renderBox = Overlay.of(context).context.findRenderObject() as RenderBox;
    final child = Stack(
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
    if (shouldHighlight) {
      return DecoratedBoxTransition(
        decoration: _animationDecoration,
        child: child,
      );
    }
    return child;
  }

  void _showDialog(BuildContext context, String text) async {
    showMenu(
      context: context,
      position: RelativeRect.fromSize(_tapEventOffset & const Size(40, 40), _renderBox.size),
      shadowColor: AppTheme.primaryColor,
      menuPadding: EdgeInsets.zero,
      items: [
        PopupMenuItem(
          child: const Text(Constants.eventContextMenuCopy),
          onTap: () async {
            final size = Settings.textSizeCopyThreshold.value;
            if (size <= 0 || text.length < size) {
              await Clipboard.setData(ClipboardData(text: text));
              return;
            }
            // TODO: Fix for Android and Web
            if (Environment.isAndroid || Environment.isWeb) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Constants.copyFileError)));
              }
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
        if (widget.event.index >= 0)
          PopupMenuItem(
            child: const Text(Constants.eventContextMenuGoto),
            onTap: () async {
              widget.tabController.index = 2;
              _consoleManager.setEventTarget(widget.event.index);
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
    final maxLines = Settings.consoleEventMaxLines.value;
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