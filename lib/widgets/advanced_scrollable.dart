import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils.dart';

//region Intents
class ScrollByIntent extends Intent {
  final double offset;
  const ScrollByIntent(this.offset);
}

class ScrollToEdgeIntent extends Intent {
  final bool toStart;
  const ScrollToEdgeIntent(this.toStart);
}
//endregion

//region Actions
class ScrollByAction extends Action<ScrollByIntent> {
  final ScrollController controller;

  ScrollByAction(this.controller);

  @override
  Object? invoke(covariant ScrollByIntent intent) {
    if (controller.hasClients) {
      final pos = controller.position;
      final target = (pos.pixels + intent.offset).clamp(pos.minScrollExtent, pos.maxScrollExtent);
      controller.jumpTo(target);
    }
    return null;
  }
}

class ScrollToEdgeAction extends Action<ScrollToEdgeIntent> {
  final ScrollController controller;

  ScrollToEdgeAction(this.controller);

  @override
  Object? invoke(covariant ScrollToEdgeIntent intent) {
    if (controller.hasClients) {
      final target = intent.toStart ? controller.position.minScrollExtent : controller.position.maxScrollExtent;
      controller.jumpTo(target);
    }
    return null;
  }
}
//endregion

class AdvancedScrollable extends StatefulWidget {
  final Widget child;
  final ScrollController controller;
  final FocusNode mainFocusNode;
  final List<FocusNode>? otherFocusNodes;

  const AdvancedScrollable({
    super.key,
    required this.child,
    required this.controller,
    required this.mainFocusNode,
    this.otherFocusNodes,
  });

  @override
  State<AdvancedScrollable> createState() => _AdvancedScrollableState();
}

class _AdvancedScrollableState extends State<AdvancedScrollable> {
  late final FocusScopeNode _scopeNode;

  @override
  void initState() {
    super.initState();
    _scopeNode = FocusScopeNode(debugLabel: '${widget.mainFocusNode.debugLabel}-scope');
    if (widget.otherFocusNodes != null) {
      for (final node in widget.otherFocusNodes!) {
        node.addListener(_onFocusChanged);
      }
    }
  }

  @override
  void dispose() {
    _scopeNode.dispose();
    if (widget.otherFocusNodes != null) {
      for (final node in widget.otherFocusNodes!) {
        node.removeListener(_onFocusChanged);
      }
    }
    super.dispose();
  }

  void _onFocusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only focus back on the scrollable if no other widget has claimed focus.
      if (widget.otherFocusNodes != null) {
        for (final node in widget.otherFocusNodes!) {
          if (node.hasFocus) {
            return;
          }
        }
      }
      widget.mainFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lineStep = 100.0;
    final pageStep = MediaQuery
        .sizeOf(context)
        .height * 0.7;

    final shortcuts = <ShortcutActivator, Intent>{
      LogicalKeySet(LogicalKeyboardKey.arrowUp): ScrollByIntent(-lineStep),
      LogicalKeySet(LogicalKeyboardKey.arrowDown): ScrollByIntent(lineStep),
      LogicalKeySet(LogicalKeyboardKey.pageUp): ScrollByIntent(-pageStep),
      LogicalKeySet(LogicalKeyboardKey.pageDown): ScrollByIntent(pageStep),
      LogicalKeySet(LogicalKeyboardKey.home): const ScrollToEdgeIntent(true),
      LogicalKeySet(LogicalKeyboardKey.end): const ScrollToEdgeIntent(false),
    };
    final actions = <Type, Action<Intent>>{
      ScrollByIntent: ScrollByAction(widget.controller),
      ScrollToEdgeIntent: ScrollToEdgeAction(widget.controller),
    };

    return FocusScope(
      node: _scopeNode,
      autofocus: true,
      canRequestFocus: true,
      child: Shortcuts(
        shortcuts: shortcuts,
        child: Actions(
          actions: actions,
          child: Focus(
            focusNode: widget.mainFocusNode,
            child: addMiddleScrollFunctionality(
              Scrollbar(
                controller: widget.controller,
                thumbVisibility: true,
                interactive: true,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: widget.child,
                ),
              ),
              widget.controller,
            ),
          ),
        ),
      ),
    );
  }
}