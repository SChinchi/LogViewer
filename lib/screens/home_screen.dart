import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import 'package:log_viewer/constants.dart';
import 'package:log_viewer/log_parser.dart';
import 'package:log_viewer/main.dart';
import 'package:log_viewer/themes/themes.dart';
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
        final fileLines = await _loadFromFile(MyApp.args[0]);
        if (mounted) {
          _tryNavigate(context, fileLines);
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
          ],
        ),
      ),
    );
  }
}

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
        result = await FilePicker.platform.pickFiles(allowMultiple: false);
        if (result != null) {
          final fileLines = await _loadFromFile(result!.files[0].xFile.path);
          if (Platform.isAndroid || Platform.isIOS) {
            FilePicker.platform.clearTemporaryFiles();
          }
          if (context.mounted) {
            _tryNavigate(context, fileLines);
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
    final reader = event.session.items.first.dataReader!;
    var progress = reader.getFile(Formats.plainTextFile, (file) async {
      final stream = await file.getStream().toList();
      final fileLines = utf8.decode(stream[0]).split('\n');
      if (mounted) {
        _tryNavigate(context, fileLines);
      }
    });
    if (progress != null) {
      return;
    }
    progress = reader.getFile(Formats.zip, (file) async {
      final stream = await file.getStream().toList();
      final fileLines = _readZip(stream[0]);
      if (mounted) {
        _tryNavigate(context, fileLines);
      }
    });
    if (progress == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Constants.parseError)));
    }
  }

  void _onDropLeave(DropEvent event) {
    setState(() {
      _isDragOver = false;
    });
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

void _tryNavigate(BuildContext context, List<String>? fileLines) {
  if (fileLines == null || !Logger.parseLines(fileLines) || Logger.events.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Constants.parseError)));
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: (context) => const ConsoleScreen()));
}

Future<List<String>?> _loadFromFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  try {
    final header = await file.openRead(0, 4).toList();
    if (listEquals(header[0], Constants.zipHeader)) {
      return _readZip(file.readAsBytesSync());
    }
    return file.readAsLinesSync();
  }
  on Exception catch (_) {
    return null;
  }
}

List<String>? _readZip(List<int> bytes) {
  final zip = ZipDecoder().decodeBytes(bytes);
  return zip.isNotEmpty ? utf8.decode(zip.first.content).split('\n') : null;
}