import 'dart:convert';

import 'package:isolate_manager/isolate_manager.dart';
import 'package:log_viewer/constants.dart';

// We can't use flutter material since this is compiled to js,
// so we define our own colour constants.
const int _red = 0xFFF44336;
const int _yellow = 0xFFFFEB3B;

// This is almost a mirror image of the Event class in logger.
// The reason for this is that this class cannot contain a Color reference,
// so this is mainly used for parsing and the other for populating data.
class Event {
  static final _tsModPattern = RegExp(r'^TS Manifest: (.*)');
  static final _bepInModPattern = RegExp(r'^Loading \[(.*)\]');

  late int severity;
  late String source;
  late String message;
  late String fullString;
  late String fullStringNoPrefix;
  int? color;
  int index = -1;
  late int lineCount;
  int repeat = 0;
  int? modIndex;

  // These are not serialised directly and used for detecting when a mod loads
  String? tsModName;
  String? bepInModName;

  Event(String prefix, String logLevel, this.source, this.message, this.fullString) {
    severity = Constants.logSeverity.indexOf(logLevel);
    fullStringNoPrefix = fullString.substring(prefix.length);
    if (severity < 2) {
      color = _red;
    } else if (severity < 3) {
      color = _yellow;
    }
    lineCount = fullString.split('\n').length;

    // Check for loading mod pattern
    if (source == 'BepInEx') {
      final tsModPattern = _tsModPattern.firstMatch(message);
      if (tsModPattern != null) {
        tsModName = tsModPattern.group(1)!;
      }
      final bepInModPattern = _bepInModPattern.firstMatch(message);
      if (bepInModPattern != null) {
        bepInModName = bepInModPattern.group(1)!;
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'severity': severity,
      'source': source,
      'message': message,
      'fullString': fullString,
      'fullStringNoPrefix': fullStringNoPrefix,
      'color': color,
      'index': index,
      'lineCount': lineCount,
      'repeat': repeat,
      'modIndex': modIndex,
    };
  }
}

class Parser {
  // The space at the end is intentional.
  static final _eventHeader = RegExp('^(.*)\\[(${Constants.logSeverity.join('|')})\\s*:\\s*(.*?)\\] ', multiLine: true);

  final summary = <List<dynamic>>[];
  final mods = <List<String>>[];
  final events = <Event>[];

  void _addEvent(String prefix, String severity, String source, String message, String fullString) {
    // Compress repeated messages for the console
    final thisEventNoPrefix = fullString.substring(prefix.length);
    if (events.isNotEmpty && events.last.fullStringNoPrefix == thisEventNoPrefix) {
      events.last.repeat++;
      return;
    }
    final previousEvent = events.isNotEmpty ? events.last : null;
    final event = Event(prefix, severity, source, message, fullString);
    event.index = events.length;
    events.add(event);

    // For loading mods the pattern we generally match is:
    //   [Info : BepInEx] TS Manifest: <tsModName>
    //   [Info : BepInEx] Loading [<bepInModName>]
    // However, it is possible for either of these to be missing due to muted logs.
    // The manifest one can also be missing if the mod has been installed manually,
    // so we tag those as unknown accordingly.
    if (previousEvent != null && previousEvent.tsModName != null) {
      previousEvent.modIndex = mods.length;
      if (event.bepInModName != null) {
        event.modIndex = mods.length;
        mods.add([previousEvent.tsModName!, event.bepInModName!]);
      } else {
        mods.add([previousEvent.tsModName!, '']);
      }
    } else if (event.bepInModName != null) {
      event.modIndex = mods.length;
      mods.add([Constants.noManifestModName, event.bepInModName!]);
    }
  }

  void _createSummary() {
    final bepInExLine = RegExp(r'^BepInEx \d+\.\d+\.\d+.\d+');
    final unityLine = RegExp(r'^Running under Unity');
    final patcherLine = RegExp(r'^Loaded \d+ patcher method from \[.*\]');
    final pluginsLine = RegExp(r'^\d+ plugins to load$');
    final wWiseLine = RegExp(r'^WwiseUnity: Setting Plugin DLL path to');
    for (final event in events) {
      final wWiseMatch = wWiseLine.firstMatch(event.message) != null;
      final isLastSummaryLine = wWiseMatch;
      if (isLastSummaryLine ||
          bepInExLine.firstMatch(event.message) != null ||
          unityLine.firstMatch(event.message) != null ||
          patcherLine.firstMatch(event.message) != null ||
          pluginsLine.firstMatch(event.message) != null) {
        if (!wWiseMatch) {
          summary.add([event.message]);
        }
        // Checking if the installed path is illegitimate to add it to the summary.
        // Epic Games does allow any directory path so some rare false positives are expected.
        else if (!event.message.contains('/steamapps/common/Risk') && !event.message.contains('/Epic Games/Risk')) {
          summary.add([event.message, _yellow]);
        }
      }
      if (isLastSummaryLine) {
        return;
      }
    }
  }

  Map<String, dynamic> parse(String text, IsolateManagerController<String, String> controller) {
    final trailingNewLines = RegExp(r'(\r\n|\r|\n)+$');
    try {
      final matches = _eventHeader.allMatches(text).toList();
      final total = matches.length;
      var progress = 0;
      for (var index = 0; index < matches.length; index++) {
        final match = matches[index];
        final headerText = match.group(0)!;
        final prefix = match.group(1)!;
        final logLevel = match.group(2)!;
        final source = match.group(3)!;
        // The full event string is between the current matched header and the next one.
        final start = match.start;
        final end = (index + 1 < matches.length) ? matches[index + 1].start : text.length;
        final fullString = text.substring(start, end).replaceFirst(trailingNewLines, '', headerText.length);
        // The message body is everything but the header.
        final message = fullString.substring(headerText.length);

        _addEvent(prefix, logLevel, source, message, fullString);

        if (index % 500 == 0) {
          final currentProgress = (index / total * 100).toInt();
          if (currentProgress != progress) {
            progress = currentProgress;
            controller.sendResult(jsonEncode({'progress': progress}));
          }
        }
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

      if (events.isNotEmpty) {
        return {
          'success': true,
          'summary': summary,
          'mods': mods,
          'events': events,
        };
      }
      return {
        'success': false,
      };
    }
    on Exception catch (_) {
      return {
        'success': false,
      };
    }
  }
}

@pragma('vm:entry-point')
@isolateManagerCustomWorker
void parserTask(dynamic params) {
  IsolateManagerFunction.customFunction<String, String>(
    params,
    onEvent: (controller, logText) {
      return jsonEncode(Parser().parse(logText, controller));
    },
  );
}