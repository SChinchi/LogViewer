import 'dart:ui';

import 'package:expandable/expandable.dart';
import 'package:log_viewer/parser.dart' as parser;
import 'package:log_viewer/themes/themes.dart';

class Event {
  late int severity;
  late String source;
  late String message;
  late String fullString;
  late String fullStringNoPrefix;
  late Color color;
  late int index;
  late int lineCount;
  int repeat = 0;
  int? modIndex;
  final controller = ExpandableController();

  Event(String prefix, String logLevel, source, String message, String fullString) {
    final data = parser.Event(prefix, logLevel, source, message, fullString);
    severity = data.severity;
    this.source = data.source;
    this.message = data.message;
    this.fullString = data.fullString;
    fullStringNoPrefix = data.fullStringNoPrefix;
    color = (data.color == null) ? AppTheme.primaryColor : Color(data.color!);
    index = data.index;
    lineCount = data.lineCount;
    repeat = data.repeat;
    modIndex = data.modIndex;
  }

  Event.clone(Event event) {
    severity = event.severity;
    source = event.source;
    message = event.message;
    fullString = event.fullString;
    fullStringNoPrefix = event.fullStringNoPrefix;
    color = event.color;
    index = event.index;
    lineCount = event.lineCount;
    repeat = event.repeat;
    modIndex = event.modIndex;
  }

  Event.fromJson(Map<String, dynamic> data) {
    severity = data['severity'] as int;
    source = data['source'];
    message = data['message'];
    fullString = data['fullString'];
    fullStringNoPrefix = data['fullStringNoPrefix'];
    final colorValue = data['color'] as int?;
    color = (colorValue == null) ? AppTheme.primaryColor : Color(colorValue);
    index = data['index'] as int;
    lineCount = data['lineCount'] as int;
    repeat = data['repeat'] as int;
    modIndex = data['modIndex'] as int?;
  }

  void dispose() {
    controller.dispose();
  }
}