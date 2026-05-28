import 'dart:math';

import 'filter.dart';

class RangeFilter implements Filter {
  RangeFilter(this.startIndex, this.endIndex) {
    eventStart = startIndex;
    eventEnd = endIndex;
  }

  static final pattern = RegExp(r'\s*(?<range>range:(?<r0>-?\d*)\.\.(?<r1>-?\d*))\s*', caseSensitive: false);
  static const intMin = ~(-1 >>> 1);
  final int startIndex;
  final int endIndex;
  late int length;
  var eventStart = 0;
  var eventEnd = 0;

  @override
  void update(String text) {
    final match = pattern.allMatches(text).lastOrNull;
    if (match != null) {
      final r0 = match.namedGroup('r0');
      final r1 = match.namedGroup('r1');
      final start = r0 != null ? int.tryParse(r0) ?? startIndex : startIndex;
      eventStart = start >= 0 ? min(start, length) : max(startIndex, length+start);
      final end = r1 != null ? int.tryParse(r1) ?? intMin : intMin;
      eventEnd = end > 0 ? max(end-length, -length) : end == intMin ? startIndex : max(-length, end);
    } else {
      eventStart = startIndex;
      eventEnd = endIndex;
    }
  }
}