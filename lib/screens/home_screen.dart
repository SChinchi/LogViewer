import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import 'package:log_viewer/constants.dart';
import 'package:log_viewer/log_parser.dart';
import 'package:log_viewer/main.dart';
import 'console/console_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (MyApp.args.isNotEmpty && Logger.parseFile(MyApp.args[0]) && Logger.events.isNotEmpty) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ConsoleScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
          title: const Text(Constants.appTitle,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold
              )
          ),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.white10,
      body: Column(
        children: [
          SafeArea(child: Padding(
              padding: const EdgeInsets.all(16.0).copyWith(top: 50),
              child: Container(
                width: min(size.width * .8, 700),
                height: min(size.height * .5, 500),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _DropZone()
              )
          )),
          Center(child: _FilePicker())
        ],
      )
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
      onPressed: () async {
        result = await FilePicker.platform.pickFiles(allowMultiple: true);
        if (context.mounted) {
          if (!Logger.parseFile(result!.files[0].xFile.path) || Logger.events.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Constants.parseError)));
            return;
          }
          if (Platform.isAndroid || Platform.isIOS) {
            FilePicker.platform.clearTemporaryFiles();
          }
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ConsoleScreen()));
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
          )
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
      ));
    });
    return event.session.allowedOperations.firstOrNull ?? DropOperation.none;
  }

  Future<void> _onPerformDrop(PerformDropEvent event) async {
    var reader = event.session.items.first.dataReader!;
    reader.getFile(Formats.plainTextFile, (file) async {
      var stream = await file.getStream().toList();
      var s = utf8.decode(stream[0]);
      Logger.parseLines(s.split('\n'));
      if (Logger.events.isNotEmpty && mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ConsoleScreen()));
      }
    });
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
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      )
    ]
);