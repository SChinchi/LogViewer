import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
  FilePickerResult? result;

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await FilePicker.platform.pickFiles(allowMultiple: true);
                if (context.mounted) {
                  if (!Logger.parseFile(result!.files[0].xFile.path) || Logger.events.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Constants.parseError)));
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ConsoleScreen()));
                }
              },
              child: const Text(Constants.loadButton),
            ),
          ),
        ),
      ),
    );
  }
}