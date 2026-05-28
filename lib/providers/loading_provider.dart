import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/parser.dart' as parser;
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
      loadFromBytes(bytes.toList());
    }
  }

  Future<void> loadFromDroppedFile(DataReaderFile file, DataReaderFileType type) async {
    _startLoading();
    final bytes = (await file.getStream().toList()).expand((x) => x).toList();
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

  bool get hasData => data['success'] == true;

  bool get isLoading => progressText.value.isNotEmpty;
}