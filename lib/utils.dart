import 'dart:io';

import 'package:auto_scrolling/auto_scrolling.dart';
import 'package:flutter/material.dart';

Widget addMiddleScrollFunctionality(Scrollbar scrollbar, ScrollController controller) {
  if (Platform.isAndroid || Platform.isIOS) {
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