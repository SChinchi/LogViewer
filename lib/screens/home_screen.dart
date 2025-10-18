import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:log_viewer/parser.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/log_parser.dart';
import 'package:log_viewer/main.dart';
import 'package:log_viewer/themes/themes.dart';
import 'package:log_viewer/utils.dart';
import 'package:super_clipboard/super_clipboard.dart' show SimpleFileFormat, DataReaderFile;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import 'console/console_screen.dart';

class HomeScreen extends StatefulWidget {
  final String title;

  const HomeScreen({super.key, required this.title});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (MyApp.args.isNotEmpty) {
        final logText = await _loadFromFile(MyApp.args[0]);
        if (mounted) {
          _tryParseFile(context, logText);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: Scaffold(
        appBar: AppBar(
          title: const Text(Constants.appTitle,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0).copyWith(top: 50),
                child: Container(
                  width: min(size.width * .8, 700),
                  height: min(size.height * .5, 500),
                  decoration: BoxDecoration(
                    color: AppTheme.selectedColor,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _DropZone(),
                ),
              ),
            ),
            Center(child: _FilePicker()),
            Padding(
              padding: EdgeInsets.fromLTRB(0, 30, 0, 0),
              child: ValueListenableBuilder(
                valueListenable: _loadingProgress,
                builder: (context, value, child) => Text(value > 0 ? '${Constants.loadingText}: $value%' : ''),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _loadingProgress = ValueNotifier<int>(0);

class _FilePicker extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _FilePickerState();
}

class _FilePickerState extends State<_FilePicker>{
  FilePickerResult? result;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(shadowColor: Colors.white),
      onPressed: () async {
        if (Logger.isLoading) {
          return;
        }
        result = await FilePicker.platform.pickFiles(allowMultiple: false);
        if (result != null) {
          final logText = Environment.isWeb
            ? _loadFromBytes(result!.files.first.bytes!)
            : await _loadFromFile(result!.files.first.xFile.path);
          if (Environment.isMobile) {
            FilePicker.platform.clearTemporaryFiles();
          }
          if (context.mounted) {
            _tryParseFile(context, logText);
          }
        }
      },
      child: const Text(Constants.loadButton),
    );
  }
}

class _DropZone extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  // Zip files on the web have a different mime type
  static const _zipExtended = SimpleFileFormat(
    uniformTypeIdentifiers: ['public.zip-archive'],
    mimeTypes: ['application/zip', 'application/x-zip-compressed'],
  );

  // .log files on the web are not considered plain text
  static const _webDefault = SimpleFileFormat(
    mimeTypes: ['application/octet-stream']
  );

  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: _onDropOver,
      onPerformDrop: _onPerformDrop,
      onDropLeave: _onDropLeave,
      child: Stack(
        children: [
          Positioned.fill(child: Center(child: _upload)),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _isDragOver ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: _preview,
              ),
            ),
          ),
        ],
      ),
    );
  }

  DropOperation _onDropOver(DropOverEvent event) {
    setState(() {
      _isDragOver = true;
      _preview = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: Colors.black.withValues(alpha: 0.2),
        ),
      );
    });
    return event.session.allowedOperations.firstOrNull ?? DropOperation.none;
  }

  Future<void> _onPerformDrop(PerformDropEvent event) async {
    if (Logger.isLoading) {
      return;
    }
    final reader = event.session.items.first.dataReader!;
    var progress = reader.getFile(Formats.plainTextFile, (file) async {
      final stream = await _readFullStream(file);
      final logText = utf8.decode(stream);
      if (mounted) {
        _tryParseFile(context, logText);
      }
    });
    if (progress != null) {
      return;
    }
    progress = reader.getFile(_zipExtended, (file) async {
      final stream = await _readFullStream(file);
      final logText = _readZip(stream);
      if (mounted) {
        _tryParseFile(context, logText);
      }
    });
    // TODO: Is there anything better for .log files on the web?
    if (Environment.isWeb && progress == null) {
      progress = reader.getFile(_webDefault, (file) async {
        final stream = await _readFullStream(file);
        final logText = utf8.decode(stream, allowMalformed: true);
        if (mounted) {
          _tryParseFile(context, logText);
        }
      });
    }
    if (progress == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Constants.parseError)));
    }
  }

  void _onDropLeave(DropEvent event) {
    setState(() {
      _isDragOver = false;
    });
  }

  Future<List<int>> _readFullStream(DataReaderFile file) async {
    return (await file.getStream().toList()).expand((x) => x).toList();
  }
}

Widget _preview = const SizedBox();

Widget _upload = const Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(Icons.upload_file, size: 48),
    Text(Constants.dropText,
      style: TextStyle(fontSize: 16),
    ),
  ],
);

void _tryParseFile(BuildContext context, String? text) async {
  if (text == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Constants.parseError)));
    return;
  }

  Logger.isLoading = true;
  final isolate = IsolateManager.createCustom(
    parserTask,
    workerName: 'parserTask',
  );
  final data = await isolate.compute(
    text,
    callback: (dynamic value) {
      try {
        final data = jsonDecode(value as String);
        if (data.containsKey('progress')) {
          _loadingProgress.value = data['progress'] as int;
          return false; // Indicates this is a progress update, not the final result
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error decoding task message: $e');
        }
        return true; // Stop listening
      }
      return true; // Default to stop if format is unexpected
    },
  );
  await isolate.stop();
  _loadingProgress.value = 0;
  Logger.populateData(jsonDecode(data));
  Diagnostics.analyse();
  Logger.isLoading = false;

  if (context.mounted) {
    if (Logger.events.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ConsoleScreen()));
    }
    else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Constants.parseError)));
    }
  }
}

Future<String?> _loadFromFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  final bytes = await file.readAsBytes();
  return _loadFromBytes(bytes.toList());
}

String? _loadFromBytes(List<int> bytes) {
  try {
    final header = bytes.getRange(0, 4).toList();
    if (listEquals(header, Constants.zipHeader)) {
      return _readZip(bytes);
    }
    return utf8.decode(bytes);
  }
  on Exception catch (_) {
    return null;
  }
}

String? _readZip(List<int> bytes) {
  final zip = ZipDecoder().decodeBytes(bytes);
  return zip.isNotEmpty ? utf8.decode(zip.first.content) : null;
}