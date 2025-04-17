import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'settings.dart';
import 'themes/themes.dart';

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
      theme: AppTheme.theme,
      home: const HomeScreen(title: ''),
    );
  }
}