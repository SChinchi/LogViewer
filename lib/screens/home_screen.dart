import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:log_viewer/constants.dart';
import 'package:log_viewer/main.dart';
import 'package:log_viewer/providers/console_manager.dart';
import 'package:log_viewer/providers/loading_provider.dart';
import 'package:log_viewer/providers/mod_manager.dart';
import 'package:log_viewer/screens/console/console_screen.dart';
import 'package:log_viewer/themes/themes.dart';
import 'package:log_viewer/utils.dart';
import 'package:provider/provider.dart';
import 'package:super_clipboard/super_clipboard.dart' show SimpleFileFormat;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final LoadingProvider _loadingProvider;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _loadingProvider = context.read<LoadingProvider>();
    _loadingProvider.addListener(_handleSelectedFile);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (MyApp.args.isNotEmpty) {
        _loadingProvider.loadFromFile(MyApp.args[0]);
      }
    });
  }

  @override
  void dispose() {
    _loadingProvider.removeListener(_handleSelectedFile);
    super.dispose();
  }

  void _handleSelectedFile() {
    if (context.mounted) {
      if (_loadingProvider.hasData) {
        Navigator.push(context, MaterialPageRoute(builder: (context) {
          final data = _loadingProvider.data;
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ModManager(data)),
              ChangeNotifierProvider(create: (context) => ConsoleManager(data, context.read<ModManager>().mods)),
            ],
            child: const ConsoleScreen(),
          );
        }));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadingProvider.data.clear();
        });
      } else if (_loadingProvider.errorMessage.isNotEmpty) {
        _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(_loadingProvider.errorMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
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
                valueListenable: _loadingProvider.progressText,
                builder: (context, value, child) => Text(_loadingProvider.progressText.value),
              ),
            ),
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
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(shadowColor: Colors.white),
      onPressed: () async {
        final loadingProvider = context.read<LoadingProvider>();
        if (loadingProvider.isLoading) {
          return;
        }
        final result = await FilePicker.pickFiles(allowMultiple: false, withData: true);
        if (result != null) {
          if (Environment.isWeb) {
            loadingProvider.loadFromBytes(result.files.first.bytes!);
          } else {
            loadingProvider.loadFromFile(result.files.first.xFile.path);
          }
          if (Environment.isMobile) {
            FilePicker.clearTemporaryFiles();
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
    final loadingProvider = context.read<LoadingProvider>();
    if (loadingProvider.isLoading) {
      return;
    }
    final reader = event.session.items.first.dataReader!;
    var progress = reader.getFile(Formats.plainTextFile, (file) async {
      loadingProvider.loadFromDroppedFile(file, DataReaderFileType.text);
    });
    if (progress != null) {
      return;
    }
    progress = reader.getFile(_zipExtended, (file) async {
      loadingProvider.loadFromDroppedFile(file, DataReaderFileType.zip);
    });
    // TODO: Is there anything better for .log files on these platforms?
    if ((Environment.isWeb || Environment.isAndroid) && progress == null) {
      progress = reader.getFile(_webDefault, (file) async {
        loadingProvider.loadFromDroppedFile(file, DataReaderFileType.webText);
      });
    }
    // No valid file found, let the provider handle the error message.
    if (progress == null) {
      loadingProvider.parseText(null);
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