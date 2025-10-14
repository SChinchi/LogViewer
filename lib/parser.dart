import 'dart:convert';

import 'package:isolate_manager/isolate_manager.dart';

import 'constants.dart';

// We can't use flutter material since this is compiled to js,
// so we define our own colour constants.
const int _red = 0xFFF44336;
const int _yellow = 0xFFFFEB3B;

final eventPattern = RegExp('(.*)\\[(${Constants.logSeverity.join('|')})\\s*:\\s*(.*?)\\] (.*)');

// This is almost a mirror image of the Event class in log_parser.
// The reason for this is that this class cannot contain a Color reference,
// so this is mainly used for parsing and the other for populating data.
class Event {
  static final _modPattern = RegExp(r'^TS Manifest: (.*)');

  late int severity;
  late String source;
  late String string;
  late String fullString;
  late String fullStringNoPrefix;
  int? color;
  int index = 0;
  late int lineCount;
  int repeat = 0;
  String? modName;

  Event(String text, RegExpMatch match) {
    severity = Constants.logSeverity.indexOf(match.group(2)!);
    source = match.group(3)!;
    string = match.group(4)!;
    fullString = text;
    fullStringNoPrefix = text.substring(match.group(1)!.length);
    if (severity < 2) {
      color = _red;
    }
    else if (severity < 3) {
      color = _yellow;
    }
    lineCount = fullString.split('\n').length;
    final modPattern = _modPattern.firstMatch(match.group(4)!);
    if (modPattern != null) {
      modName = modPattern.group(1);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'severity': severity,
      'source': source,
      'string': string,
      'fullString': fullString,
      'fullStringNoPrefix': fullStringNoPrefix,
      'color': color,
      'index': index,
      'lineCount': lineCount,
      'repeat': repeat,
      'modName': modName,
    };
  }
}

class Parser {
  static final eventPattern = RegExp('(.*)\\[(${Constants.logSeverity.join('|')})\\s*:\\s*(.*?)\\] (.*)');

  final summary = <List<dynamic>>[];
  final mods = <String>[];
  final events = <Event>[];

  void _addEvent(String text) {
    final match = eventPattern.firstMatch(text);
    if (match == null) {
      return;
    }
    // Compress repeated messages for the console
    final sNoPrefix = text.substring(match.group(1)!.length);
    if (events.isNotEmpty && events.last.fullStringNoPrefix == sNoPrefix) {
      events.last.repeat++;
      return;
    }
    final event = Event(text, match);
    event.index = events.length;
    events.add(event);
    if (event.modName != null) {
      mods.add(event.modName!);
    }
  }

  void _createSummary() {
    final bepInExLine = RegExp(r'^BepInEx \d+\.\d+\.\d+.\d+');
    final unityLine = RegExp(r'^Running under Unity');
    final patcherLine = RegExp(r'^Loaded \d+ patcher method from \[.*\]');
    final pluginsLine = RegExp(r'^\d+ plugins to load$');
    final wWiseLine = RegExp(r'^WwiseUnity: Setting Plugin DLL path to');
    for (final event in events) {
      final wWiseMatch = wWiseLine.firstMatch(event.string) != null;
      final isLastSummaryLine = wWiseMatch;
      if (isLastSummaryLine ||
          bepInExLine.firstMatch(event.string) != null ||
          unityLine.firstMatch(event.string) != null ||
          patcherLine.firstMatch(event.string) != null ||
          pluginsLine.firstMatch(event.string) != null) {
        if (!wWiseMatch) {
          summary.add([event.string]);
        }
        // Checking if the installed path is illegitimate to add it to the summary.
        // Epic Games does allow any directory path so some rare false positives are expected.
        else if (!event.string.contains('/steamapps/common/Risk') && !event.string.contains('/Epic Games/Risk')) {
          summary.add([event.string, _yellow]);
        }
      }
      if (isLastSummaryLine) {
        return;
      }
    }
  }

  Map<String, dynamic> parse(List<String> lines, IsolateManagerController<String, String> controller) {
    try {
      var progress = 0;
      var index = 0;
      final total = lines.length;
      final sb = StringBuffer(lines[0]);
      for (final line in lines.sublist(1, lines.length)) {
        final match = eventPattern.firstMatch(line);
        if (match != null) {
          _addEvent(sb.toString().trimRight());
          sb.clear();
        }
        sb.writeln(line);
        index += 1;
        if (index % 5000 == 0) {
          final currentProgress = (index / total * 100).toInt();
          if (currentProgress != progress) {
            progress = currentProgress;
            controller.sendResult(jsonEncode({'progress': progress}));
          }
        }
      }
      if (sb.isNotEmpty) {
        _addEvent(sb.toString().trimRight());
      }

      // Prefix each message with its index; useful for range searching
      final eventNum = events.length;
      final length = eventNum
          .toString()
          .length;
      for (final event in events) {
        event.fullString = '${event.index.toString().padLeft(length, '0')} ${event.fullString}';
      }

      _createSummary();
    }
    on Exception catch (_) {
      return {
        'success': false,
      };
    }

    return {
      'success': true,
      'summary': summary,
      'mods': mods,
      'events': events,
    };
  }
}

@pragma('vm:entry-point')
@isolateManagerCustomWorker
void parserTask(dynamic params) {
  IsolateManagerFunction.customFunction<String, String>(
    params,
    onEvent: (controller, logText) {
      final lines = logText.split('\n');
      return jsonEncode(Parser().parse(lines, controller));
    },
  );
}