import 'package:flutter/material.dart';
import 'package:log_viewer/settings.dart';

import 'screens/home_screen.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  Settings.init();
  runApp(MyApp(args: args));
}

class MyApp extends StatelessWidget {
  static late List<String> args;

  MyApp({super.key, args}) {
    MyApp.args = args;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const HomeScreen(title: ''),
    );
  }
}