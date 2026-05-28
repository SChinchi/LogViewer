import 'filter.dart';

class RepeatFilter implements Filter {
  static final pattern = RegExp(r'\s*(?<repeat>repeat:(?<repeat_num>\d+))\s*', caseSensitive: false);
  var value = 0;

  @override
  void update(String text) {
    final match = pattern.allMatches(text).lastOrNull;
    value = match != null ? int.parse(match.namedGroup('repeat_num')!) : 0;
  }
}