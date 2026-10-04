import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/parser.dart' as parser;
import 'package:log_viewer/settings.dart';
import 'package:super_clipboard/super_clipboard.dart';

enum DataReaderFileType {
  text,
  zip,
  webText,
}

class LoadingProvider extends ChangeNotifier {
  final progressText = ValueNotifier<String>('');
  var errorMessage = '';
  var data = <String, dynamic>{};

  void _startLoading() {
    progressText.value = Constants.loadingFileText;
  }

  void _updateProgress(int value) {
    progressText.value = '${Constants.loadingProgressText} $value%';
  }

  void _finishLoading() {
    progressText.value = '';
  }

  Future<void> loadFromFile(String path) async {
    _startLoading();
    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      loadFromBytes(bytes);
    }
  }

  Future<void> loadFromDroppedFile(DataReaderFile file, DataReaderFileType type) async {
    _startLoading();
    final builder = BytesBuilder();
    await file.getStream().forEach((chunk) => builder.add(chunk));
    final bytes = builder.toBytes();
    switch (type) {
      case DataReaderFileType.text:
        parseText(utf8.decode(bytes));
        break;
      case DataReaderFileType.zip:
        loadFromZip(bytes);
        break;
      case DataReaderFileType.webText:
        parseText(utf8.decode(bytes, allowMalformed: true));
        break;
    }
  }

  void loadFromBytes(List<int> bytes) {
    _startLoading();
    if (bytes.length >= Constants.zipHeader.length && listEquals(bytes.getRange(0, 4).toList(), Constants.zipHeader)) {
      loadFromZip(bytes);
    } else {
      try {
        parseText(utf8.decode(bytes));
      } on FormatException {
        parseText(null);
      }
    }
  }

  void loadFromZip(List<int> bytes) {
    _startLoading();
    final zip = ZipDecoder().decodeBytes(bytes);
    String? text;
    if (zip.isNotEmpty) {
      try {
        text = utf8.decode(zip.first.content);
      } on FormatException {
        text = null;
      }
    }
    parseText(text);
  }

  void parseText(String? text) async {
    errorMessage = '';
    data.clear();

    if (text == null) {
      _finishLoading();
      errorMessage = Constants.parseError;
      notifyListeners();
      return;
    }

    text = _trimTextIfTooLong(text);

    final isolate = IsolateManager.createCustom(
      parser.parserTask,
      workerName: 'parserTask',
    );
    final output = await isolate.compute(
      text,
      callback: (dynamic value) {
        final data = jsonDecode(value as String);
        if (data.containsKey('progress')) {
          _updateProgress(data['progress'] as int);
          return false; // Indicates this is a progress update, not the final result
        }
        return true;
      },
    );
    await isolate.stop();
    _finishLoading();
    data = jsonDecode(output);

    if (data['success'] != true) {
      errorMessage = data['error'] ?? Constants.parseError;
      data.clear();
    }
    notifyListeners();
  }

  String _trimTextIfTooLong(String text) {
    final megabyte = 1024 * 1024;
    final headLength = Settings.logHeadLength.value * megabyte;
    final tailLength = Settings.logTailLength.value * megabyte;
    final totalTrimLength = headLength + tailLength;
    // If the trim length is 0, it means both values are unset and we don't want to trim anything.
    if (totalTrimLength > 0 && text.length > totalTrimLength) {
      var head = text.substring(0, headLength);
      try {
        final lastHeadMatch = parser.Parser.eventHeader.allMatches(head).last;
        head = head.substring(0, lastHeadMatch.start);
      } on StateError {
        // Nothing found, so set this to empty; no need for it to be parsed again later.
        head = '';
      }
      var tail = text.substring(text.length - tailLength);
      final firstTailMatch = parser.Parser.eventHeader.firstMatch(tail);
      if (firstTailMatch != null) {
        tail = tail.substring(firstTailMatch.start);
      }
      final trimmedLength = (text.length - (head.length + tail.length)) / megabyte;
      text = '$head[Warning: LogViewer] Trimmed ${trimmedLength.toStringAsFixed(2)} MB from this log...\n$tail';
    }
    return text;
  }

  bool get hasData => data['success'] == true;

  bool get isLoading => progressText.value.isNotEmpty;
}