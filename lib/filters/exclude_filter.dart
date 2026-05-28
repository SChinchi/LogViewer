import 'filter.dart';

class ExcludeFilter implements Filter{
  static final pattern = RegExp(r'\s*(?<exclude>exclude:(?<exclude_term>\(.*\)|[^(\s]\S*))\s*', caseSensitive: false);
  var regex = RegExp('', caseSensitive: false);

  @override
  void update(String text) {
    final match = pattern.allMatches(text).lastOrNull;
    if (match != null) {
      try {
        final excludeTerm = match.namedGroup('exclude_term')!;
        if (excludeTerm != regex.pattern) {
          regex = RegExp(excludeTerm, caseSensitive: false);
        }
      } on FormatException {
        // Capturing each keystroke of the search means an incomplete regex is possible. We make no updates.
      }
    } else {
      if (regex.pattern.isNotEmpty) {
        regex = RegExp('', caseSensitive: false);
      }
    }
  }
}