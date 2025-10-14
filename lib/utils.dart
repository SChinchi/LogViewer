import 'dart:io';

import 'package:auto_scrolling/auto_scrolling.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Widget addMiddleScrollFunctionality(Scrollbar scrollbar, ScrollController controller) {
  if (Environment.isMobile) {
    return scrollbar;
  }
  return AutoScroll(
    anchorBuilder: (context) =>
    const SingleDirectionAnchor(
      direction: Axis.vertical,
    ),
    controller: controller,
    child: scrollbar,
  );
}

class Environment {
  static bool get isWeb => kIsWeb;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isMobile => Environment.isAndroid || Environment.isIOS;
}